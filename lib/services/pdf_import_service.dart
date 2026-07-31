import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../utils/validation.dart';
import 'category_classifier.dart';

/// Isolate entry point: must stay top-level and take sendable args only.
String _extractTextFromBytes(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    return PdfTextExtractor(document).extractText();
  } finally {
    document.dispose();
  }
}

class PdfImportService {
  static const _uuid = Uuid();
  static const maxPdfBytes = 10 * 1024 * 1024;

  /// Extracts all text from the PDF file. The decode runs in an isolate — a
  /// multi-page statement blocks the UI thread for seconds otherwise.
  static Future<String> extractText(File file) async {
    if (await file.length() > maxPdfBytes) {
      throw const FormatException('PDF file is too large.');
    }
    final bytes = await file.readAsBytes();
    return compute(_extractTextFromBytes, bytes);
  }

  /// Parses a bank statement PDF and returns a list of expenses.
  ///
  /// [memoryLookup] is consulted before the keyword rules so a merchant the
  /// user has already corrected keeps that category. Omit it (the default) for
  /// keyword-only categorization.
  static Future<List<Expense>> parseBankStatement(
    File file, {
    MerchantCategoryLookup? memoryLookup,
  }) async {
    final text = await extractText(file);
    final lines = text.split('\n');
    final expenses = <Expense>[];

    // Patterns for common Indian bank statements (HDFC, SBI, ICICI, Axis, Kotak)
    final patterns = [
      // HDFC: "01/09/2024  UPI-Swiggy  -350.00"
      RegExp(
        r'(\d{2}[/-]\d{2}[/-]\d{2,4})\s+(.+?)\s+[-](\d+(?:[,.]\d+)?)\s*(?:Dr)?',
        caseSensitive: false,
      ),
      // SBI: "01 Sep 2024  By Transfer to Swiggy  350.00 Dr"
      RegExp(
        r'(\d{1,2}\s+\w{3}\s+\d{4})\s+(.+?)\s+(\d+(?:[,.]\d+)?)\s+Dr',
        caseSensitive: false,
      ),
      // Amount with debit marker
      RegExp(
        r'(\d{2}[/-]\d{2}[/-]\d{2,4})\s+(.+?)\s+(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)\s+(?:D|Dr|Debit|DR)',
        caseSensitive: false,
      ),
    ];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Skip header/footer lines
      if (_isHeaderLine(trimmed)) continue;

      for (final pattern in patterns) {
        final match = pattern.firstMatch(trimmed);
        if (match != null) {
          try {
            final dateStr = match.group(1)!.trim();
            final description = match.group(2)!.trim();
            final amountStr = match.group(3)!.replaceAll(',', '').trim();
            final amount = parsePositiveAmount(amountStr);

            if (amount == null) continue;
            if (description.length < 3) continue;

            final date = _parseDate(dateStr);
            if (date == null) continue;

            // Skip credits/salary credits
            if (_isCredit(trimmed, description)) continue;

            final title = _cleanDescription(description);
            final (category, isUncategorized) = resolveImportedCategory(
              title,
              memoryLookup,
            );

            expenses.add(
              Expense(
                id: _uuid.v4(),
                title: title,
                amount: amount,
                date: date,
                category: category,
                isUncategorized: isUncategorized,
                isManual: false,
                source: 'PDF Import',
                note: 'Imported from bank statement PDF',
              ),
            );
            break; // Matched, skip other patterns
          } catch (_) {
            continue;
          }
        }
      }
    }

    // Remove duplicates
    final seen = <String>{};
    return expenses.where((e) {
      final key =
          '${e.title.toLowerCase()}|${e.amount.toStringAsFixed(2)}|'
          '${e.date.year}-${e.date.month}-${e.date.day}';
      return seen.add(key);
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  static bool _isHeaderLine(String line) {
    final lower = line.toLowerCase();
    return (lower.contains('date') && lower.contains('description')) ||
        lower.contains('opening balance') ||
        lower.contains('closing balance') ||
        (lower.contains('statement') && lower.contains('account')) ||
        lower.startsWith('page ');
  }

  static bool _isCredit(String line, String desc) {
    final lower = line.toLowerCase();
    final descLower = desc.toLowerCase();
    return lower.contains(' cr') ||
        lower.contains('credit') ||
        descLower.contains('salary') ||
        descLower.contains('interest credit') ||
        descLower.contains('refund') ||
        lower.endsWith(' cr');
  }

  static DateTime? _parseDate(String dateStr) {
    try {
      // Try dd/MM/yyyy
      final parts1 = dateStr.split(RegExp(r'[/-]'));
      if (parts1.length == 3) {
        int day = int.parse(parts1[0]);
        int month = int.parse(parts1[1]);
        int year = int.parse(parts1[2]);
        if (year < 100) year += 2000;
        return _strictDate(year, month, day);
      }
    } catch (_) {}
    try {
      // Try "01 Sep 2024"
      const months = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      final parts2 = dateStr.split(' ');
      if (parts2.length == 3) {
        final day = int.parse(parts2[0]);
        final month = months[parts2[1].toLowerCase().substring(0, 3)];
        final year = int.parse(parts2[2]);
        if (month != null) return _strictDate(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  static DateTime? _strictDate(int year, int month, int day) {
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  /// Tidies a statement descriptor for display, keeping the whole merchant.
  ///
  /// This used to keep only the text before the first `-`, so `UPI-Swiggy`
  /// became `UPI` and the merchant was gone before anything could categorize
  /// it. Rail prefixes and trailing reference numbers are stripped by
  /// `CategoryClassifier.normalizeMerchant` for matching purposes only; the
  /// stored title stays as the bank printed it.
  static String _cleanDescription(String raw) {
    return raw
        .replaceAll(RegExp(r'[/\\|]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
