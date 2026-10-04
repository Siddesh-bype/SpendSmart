import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../utils/validation.dart';
import 'category_classifier.dart';

/// Isolate entry point: must stay top-level and take sendable args only.
List<List<dynamic>> _decodeCsv(String csvString) =>
    const CsvDecoder(skipEmptyLines: true).convert(csvString);

class CsvImportResult {
  final List<Expense> imported;
  final int skipped;
  final List<String> errors;

  const CsvImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
  });
}

class CsvImportService {
  static const _maxCsvBytes = 5 * 1024 * 1024;

  static final _dateFormats = [
    DateFormat('yyyy-MM-dd HH:mm:ss'),
    DateFormat('yyyy-MM-dd'),
    DateFormat('dd/MM/yyyy'),
    DateFormat('MM/dd/yyyy'),
    DateFormat('dd-MM-yyyy'),
  ];

  /// [memoryLookup] is consulted before the keyword rules; see [parse].
  static Future<CsvImportResult?> pickAndParse({
    MerchantCategoryLookup? memoryLookup,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    if (file.size > _maxCsvBytes) {
      return const CsvImportResult(
        imported: [],
        skipped: 0,
        errors: ['CSV file is too large. Choose a file under 5 MB.'],
      );
    }

    String? csvString;
    try {
      csvString = await _readSelectedFile(file);
    } on FormatException {
      return const CsvImportResult(
        imported: [],
        skipped: 0,
        errors: ['CSV file must use valid UTF-8 text.'],
      );
    } on FileSystemException {
      csvString = null;
    }
    if (csvString == null) {
      return const CsvImportResult(
        imported: [],
        skipped: 0,
        errors: ['Could not read the selected file.'],
      );
    }

    return parseInBackground(csvString, memoryLookup: memoryLookup);
  }

  static Future<String?> _readSelectedFile(PlatformFile file) async {
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    return File(path).readAsString();
  }

  /// Same as [parse], but the CSV tokenizer — the expensive part on a large
  /// file — runs in an isolate. Categorization stays on the main thread because
  /// [memoryLookup] closes over Hive state and cannot cross the boundary.
  static Future<CsvImportResult> parseInBackground(
    String csvString, {
    MerchantCategoryLookup? memoryLookup,
  }) async {
    final List<List<dynamic>> rows;
    try {
      rows = await compute(_decodeCsv, csvString);
    } catch (_) {
      return const CsvImportResult(
        imported: [],
        skipped: 0,
        errors: ['File is not valid CSV.'],
      );
    }
    return _parseRows(rows, memoryLookup: memoryLookup);
  }

  /// Parses [csvString] into expenses.
  ///
  /// Category resolution per row, first hit wins:
  /// 1. an explicit `category` column holding an exact category name — the
  ///    user typed it, so it beats every guess;
  /// 2. [memoryLookup], the categories the user has already taught the app;
  /// 3. the keyword rules, run over the category column when it holds
  ///    free text ("Groceries"), then over the title;
  /// 4. `Category.other`, flagged `isUncategorized` for the pending queue.
  static CsvImportResult parse(
    String csvString, {
    MerchantCategoryLookup? memoryLookup,
  }) {
    final List<List<dynamic>> rows;
    try {
      rows = _decodeCsv(csvString);
    } catch (_) {
      return const CsvImportResult(
        imported: [],
        skipped: 0,
        errors: ['File is not valid CSV.'],
      );
    }
    return _parseRows(rows, memoryLookup: memoryLookup);
  }

  static CsvImportResult _parseRows(
    List<List<dynamic>> rows, {
    MerchantCategoryLookup? memoryLookup,
  }) {    if (rows.length < 2) {
      return const CsvImportResult(
        imported: [],
        skipped: 0,
        errors: ['CSV file has no data rows.'],
      );
    }

    final headers = rows.first
        .map((h) => h.toString().toLowerCase().trim())
        .toList();

    int col(Set<String> names) => headers.indexWhere(names.contains);

    final idIdx = col({'id', 'transaction id', 'reference id'});
    final dateIdx = col({'date', 'transaction date', 'txn date'});
    final titleIdx = col({'title', 'merchant', 'description', 'narration'});
    final amountIdx = col({
      'amount',
      'debit',
      'debit amount',
      'withdrawal',
      'withdrawal amount',
    });
    final catIdx = col({'category'});
    final srcIdx = col({'source'});
    final manIdx = col({'manual', 'is manual'});
    final noteIdx = col({'note', 'notes'});

    if (dateIdx < 0 || titleIdx < 0 || amountIdx < 0) {
      return const CsvImportResult(
        imported: [],
        skipped: 0,
        errors: [
          'Missing required columns. Expected Date, Title or Merchant, and Amount.',
        ],
      );
    }

    final imported = <Expense>[];
    final errors = <String>[];
    var skipped = 0;

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((c) => c.toString().trim().isEmpty)) continue;

      try {
        final requiredLastIndex = [
          dateIdx,
          titleIdx,
          amountIdx,
        ].reduce((a, b) => a > b ? a : b);
        if (row.length <= requiredLastIndex) {
          skipped++;
          errors.add('Row ${i + 1}: missing required values');
          continue;
        }

        final rawAmount = row[amountIdx].toString().trim().replaceFirst(
          RegExp(r'^(?:rs\.?|inr|₹|\$|€|£|¥)\s*', caseSensitive: false),
          '',
        );
        final amount = parsePositiveAmount(rawAmount);
        if (amount == null) {
          skipped++;
          errors.add('Row ${i + 1}: invalid amount');
          continue;
        }

        final title = _unescapeCell(row[titleIdx].toString().trim());
        if (title.isEmpty) {
          skipped++;
          errors.add('Row ${i + 1}: empty title');
          continue;
        }

        DateTime? date;
        final rawDate = row[dateIdx].toString().trim();
        for (final format in _dateFormats) {
          try {
            date = format.parseStrict(rawDate);
            break;
          } catch (_) {}
        }
        if (date == null) {
          skipped++;
          errors.add('Row ${i + 1}: unrecognised date');
          continue;
        }

        final rawCategory = catIdx >= 0 && catIdx < row.length
            ? row[catIdx].toString()
            : '';
        final (category, isUncategorized) = _resolveCategory(
          rawCategory: rawCategory,
          title: title,
          memoryLookup: memoryLookup,
        );

        final id =
            (idIdx >= 0 &&
                idIdx < row.length &&
                row[idIdx].toString().trim().isNotEmpty)
            ? row[idIdx].toString().trim()
            : const Uuid().v4();
        final source = srcIdx >= 0 && srcIdx < row.length
            ? row[srcIdx].toString().trim()
            : 'csv';
        final isManual = manIdx >= 0 && manIdx < row.length
            ? row[manIdx].toString().toLowerCase() == 'true'
            : true;
        final note = noteIdx >= 0 && noteIdx < row.length
            ? _unescapeCell(row[noteIdx].toString().trim())
            : '';

        imported.add(
          Expense(
            id: id,
            title: title,
            amount: amount,
            category: category,
            date: date,
            note: note,
            isManual: isManual,
            isUncategorized: isUncategorized,
            source: source.isEmpty ? 'csv' : source,
          ),
        );
      } catch (_) {
        skipped++;
        errors.add('Row ${i + 1}: could not be imported');
      }
    }

    return CsvImportResult(
      imported: imported,
      skipped: skipped,
      errors: errors,
    );
  }

  /// Undoes [ExportService.sanitizeCell] so a round-trip through our own
  /// export does not accumulate apostrophes on every pass.
  static String _unescapeCell(String value) =>
      value.length > 1 &&
          value.startsWith("'") &&
          _formulaStart.hasMatch(value.substring(1))
      ? value.substring(1)
      : value;

  static final _formulaStart = RegExp(r'^[=+\-@\t\r]');

  /// See [parse] for the resolution order. Returns the category and the
  /// `isUncategorized` flag: only a step-4 fallback leaves a row for the user.
  static (Category, bool) _resolveCategory({
    required String rawCategory,
    required String title,
    required MerchantCategoryLookup? memoryLookup,
  }) {
    final explicit = CategoryClassifier.exactCategory(rawCategory);
    if (explicit != null) return (explicit, false);

    final remembered = memoryLookup?.call(title);
    if (remembered != null) return (remembered, false);

    if (rawCategory.trim().isNotEmpty) {
      final labelled = CategoryClassifier.classify(rawCategory);
      if (labelled.isConfident) return (labelled.category, false);
    }

    return resolveImportedCategory(title, memoryLookup);
  }
}
