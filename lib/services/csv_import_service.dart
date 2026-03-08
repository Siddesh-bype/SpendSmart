import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/category.dart';

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
  static final _dateFormats = [
    DateFormat('yyyy-MM-dd HH:mm:ss'), // SpendSmart export format
    DateFormat('yyyy-MM-dd'),
    DateFormat('dd/MM/yyyy'),
    DateFormat('MM/dd/yyyy'),
    DateFormat('dd-MM-yyyy'),
  ];

  /// Opens a file picker for .csv files and parses the result.
  /// Returns null if user cancelled.
  static Future<CsvImportResult?> pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    String csvString;

    if (file.bytes != null) {
      csvString = String.fromCharCodes(file.bytes!);
    } else if (file.path != null) {
      csvString = await File(file.path!).readAsString();
    } else {
      return const CsvImportResult(
        imported: [],
        skipped: 0,
        errors: ['Could not read the selected file.'],
      );
    }

    return _parse(csvString);
  }

  static CsvImportResult _parse(String csvString) {
    final List<List<dynamic>> rows;
    try {
      rows = const CsvDecoder(skipEmptyLines: true).convert(csvString);
    } catch (_) {
      return const CsvImportResult(
        imported: [],
        skipped: 0,
        errors: ['File is not valid CSV.'],
      );
    }

    if (rows.length < 2) {
      return const CsvImportResult(
        imported: [],
        skipped: 0,
        errors: ['CSV file has no data rows.'],
      );
    }

    // Build column index map from header row (case-insensitive)
    final headers = rows.first.map((h) => h.toString().toLowerCase().trim()).toList();

    int col(String name) => headers.indexWhere((h) => h.contains(name));

    final idIdx     = col('id');
    final dateIdx   = col('date');
    final titleIdx  = col('title').let((v) => v < 0 ? col('merchant') : v);
    final amountIdx = col('amount');
    final catIdx    = col('category');
    final srcIdx    = col('source');
    final manIdx    = col('manual');
    final noteIdx   = col('note');

    if (dateIdx < 0 || titleIdx < 0 || amountIdx < 0) {
      return const CsvImportResult(
        imported: [],
        skipped: 0,
        errors: [
          'Missing required columns. Expected at least: Date, Title (or Merchant), Amount.'
        ],
      );
    }

    final imported = <Expense>[];
    final errors = <String>[];
    int skipped = 0;

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((c) => c.toString().trim().isEmpty)) continue;

      try {
        // Amount
        final rawAmount = row[amountIdx].toString().replaceAll(RegExp(r'[^\d.]'), '');
        final amount = double.tryParse(rawAmount);
        if (amount == null || amount <= 0) {
          skipped++;
          errors.add('Row ${i + 1}: invalid amount "${row[amountIdx]}"');
          continue;
        }

        // Title
        final title = row[titleIdx].toString().trim();
        if (title.isEmpty) {
          skipped++;
          errors.add('Row ${i + 1}: empty title');
          continue;
        }

        // Date
        DateTime? date;
        final rawDate = row[dateIdx].toString().trim();
        for (final fmt in _dateFormats) {
          try {
            date = fmt.parseStrict(rawDate);
            break;
          } catch (_) {}
        }
        if (date == null) {
          skipped++;
          errors.add('Row ${i + 1}: unrecognised date "$rawDate"');
          continue;
        }

        // Category (default to other if unknown)
        Category category = Category.other;
        if (catIdx >= 0) {
          category = _parseCategory(row[catIdx].toString());
        }

        // Optional fields
        final id    = (idIdx >= 0 && row[idIdx].toString().trim().isNotEmpty)
            ? row[idIdx].toString().trim()
            : const Uuid().v4();
        final source = srcIdx >= 0 ? row[srcIdx].toString().trim() : 'csv';
        final isManual = manIdx >= 0
            ? row[manIdx].toString().toLowerCase() == 'true'
            : true;
        final note  = noteIdx >= 0 ? row[noteIdx].toString().trim() : '';

        imported.add(Expense(
          id: id,
          title: title,
          amount: amount,
          category: category,
          date: date,
          note: note,
          isManual: isManual,
          isUncategorized: false,
          source: source.isEmpty ? 'csv' : source,
        ));
      } catch (e) {
        skipped++;
        errors.add('Row ${i + 1}: $e');
      }
    }

    return CsvImportResult(imported: imported, skipped: skipped, errors: errors);
  }

  static Category _parseCategory(String raw) {
    final lower = raw.toLowerCase().trim();
    for (final cat in Category.values) {
      if (cat.name.toLowerCase() == lower) return cat;
    }
    // Fuzzy fallbacks
    if (lower.contains('food') || lower.contains('dining') || lower.contains('eat')) {
      return Category.food;
    }
    if (lower.contains('transport') || lower.contains('travel') || lower.contains('fuel') || lower.contains('petrol')) {
      return Category.transport;
    }
    if (lower.contains('shop') || lower.contains('grocery') || lower.contains('retail')) {
      return Category.shopping;
    }
    if (lower.contains('health') || lower.contains('medical') || lower.contains('pharma')) {
      return Category.health;
    }
    if (lower.contains('entertain') || lower.contains('movie') || lower.contains('game')) {
      return Category.entertainment;
    }
    if (lower.contains('bill') || lower.contains('util') || lower.contains('electric') || lower.contains('rent')) {
      return Category.bills;
    }
    return Category.other;
  }
}

// Helper extension to avoid a temp variable for col() inline
extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
