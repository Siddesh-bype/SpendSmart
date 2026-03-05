import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/category.dart';

class PdfImportService {
  static const _uuid = Uuid();

  /// Extracts all text from the PDF file
  static Future<String> extractText(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();
    return text;
  }

  /// Parses a bank statement PDF and returns a list of expenses
  static Future<List<Expense>> parseBankStatement(File file) async {
    final text = await extractText(file);
    final lines = text.split('\n');
    final expenses = <Expense>[];

    // Patterns for common Indian bank statements (HDFC, SBI, ICICI, Axis, Kotak)
    final patterns = [
      // HDFC: "01/09/2024  UPI-Swiggy  -350.00"
      RegExp(r'(\d{2}[/-]\d{2}[/-]\d{2,4})\s+(.+?)\s+[-](\d+(?:[,.]\d+)?)\s*(?:Dr)?', caseSensitive: false),
      // SBI: "01 Sep 2024  By Transfer to Swiggy  350.00 Dr"
      RegExp(r'(\d{1,2}\s+\w{3}\s+\d{4})\s+(.+?)\s+(\d+(?:[,.]\d+)?)\s+Dr', caseSensitive: false),
      // Amount with debit marker
      RegExp(r'(\d{2}[/-]\d{2}[/-]\d{2,4})\s+(.+?)\s+(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)\s+(?:D|Dr|Debit|DR)', caseSensitive: false),
      // Generic: date + description + amount
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\s+(.{5,50}?)\s+(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\b'),
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
            final amount = double.tryParse(amountStr);

            if (amount == null || amount <= 0 || amount > 10000000) continue;
            if (description.length < 3) continue;

            final date = _parseDate(dateStr);
            if (date == null) continue;

            // Skip credits/salary credits
            if (_isCredit(trimmed, description)) continue;

            final category = _guessCategory(description);

            expenses.add(Expense(
              id: _uuid.v4(),
              title: _cleanDescription(description),
              amount: amount,
              date: date,
              category: category,
              isUncategorized: category == Category.other,
              isManual: false,
              source: 'PDF Import',
              note: 'Imported from bank statement PDF',
            ));
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
      final key = '${e.title}-${e.amount}-${e.date.day}-${e.date.month}';
      return seen.add(key);
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  static bool _isHeaderLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('date') && lower.contains('description') ||
        lower.contains('opening balance') ||
        lower.contains('closing balance') ||
        lower.contains('statement') && lower.contains('account') ||
        lower.contains('page ') ||
        lower.length < 10;
  }

  static bool _isCredit(String line, String desc) {
    final lower = line.toLowerCase();
    final descLower = desc.toLowerCase();
    return lower.contains(' cr') || lower.contains('credit') ||
        descLower.contains('salary') || descLower.contains('interest credit') ||
        descLower.contains('refund') || lower.endsWith(' cr');
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
        if (day > 31) { final tmp = day; day = month; month = tmp; } // swap if needed
        return DateTime(year, month, day);
      }
    } catch (_) {}
    try {
      // Try "01 Sep 2024"
      const months = {'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
                      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12};
      final parts2 = dateStr.split(' ');
      if (parts2.length == 3) {
        final day = int.parse(parts2[0]);
        final month = months[parts2[1].toLowerCase().substring(0, 3)];
        final year = int.parse(parts2[2]);
        if (month != null) return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  static Category _guessCategory(String description) {
    final d = description.toLowerCase();
    if (d.contains('swiggy') || d.contains('zomato') || d.contains('food') ||
        d.contains('restaurant') || d.contains('cafe') || d.contains('starbucks') ||
        d.contains('pizza') || d.contains('burger') || d.contains('hotel')) {
      return Category.food;
    }
    if (d.contains('ola') || d.contains('uber') || d.contains('petrol') ||
        d.contains('metro') || d.contains('bus') || d.contains('auto') ||
        d.contains('fuel') || d.contains('irctc') || d.contains('train')) {
      return Category.transport;
    }
    if (d.contains('amazon') || d.contains('flipkart') || d.contains('myntra') ||
        d.contains('ajio') || d.contains('meesho') || d.contains('shopping') ||
        d.contains('nykaa') || d.contains('blinkit') || d.contains('zepto')) {
      return Category.shopping;
    }
    if (d.contains('electricity') || d.contains('gas') || d.contains('water') ||
        d.contains('broadband') || d.contains('internet') || d.contains('airtel') ||
        d.contains('jio') || d.contains('vodafone') || d.contains('vi ')) {
      return Category.bills;
    }
    if (d.contains('hospital') || d.contains('pharmacy') || d.contains('medical') ||
        d.contains('doctor') || d.contains('clinic') || d.contains('apollo') ||
        d.contains('health') || d.contains('medicine')) {
      return Category.health;
    }
    if (d.contains('netflix') || d.contains('spotify') || d.contains('hotstar') ||
        d.contains('prime') || d.contains('youtube') || d.contains('game') ||
        d.contains('movie') || d.contains('pvr') || d.contains('inox')) {
      return Category.entertainment;
    }
    if (d.contains('school') || d.contains('college') || d.contains('course') ||
        d.contains('udemy') || d.contains('books') || d.contains('education') ||
        d.contains('fee') || d.contains('tuition')) {
      return Category.other;
    }
    return Category.other;
  }

  static String _cleanDescription(String raw) {
    return raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[/\\|]'), '-')
        .trim()
        .split('-').first
        .trim();
  }
}
