import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import 'category_classifier.dart';

class SMSParser {
  static const _uuid = Uuid();
  static final _debitMarker = RegExp(
    r'\b(?:debited|spent|paid)\b',
    caseSensitive: false,
  );

  static final _ignoreKeywords = [
    'otp',
    'pin',
    'code',
    'verification',
    'password',
    'credited',
    'refund',
    'reversal',
    'failed',
    'declined',
    'unsuccessful',
  ];

  static bool isDebit(String message) {
    final lowerMsg = message.toLowerCase();
    for (final keyword in _ignoreKeywords) {
      if (RegExp('\\b${RegExp.escape(keyword)}\\b').hasMatch(lowerMsg)) {
        return false;
      }
    }

    return _debitMarker.hasMatch(lowerMsg);
  }

  static Expense? parseSMS(
    String message,
    DateTime date, {
    MerchantCategoryLookup? memoryLookup,
  }) {
    if (!isDebit(message)) return null;

    final amountRegex = RegExp(
      r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final marker = _debitMarker.firstMatch(message);
    if (marker == null) return null;
    Match? amountMatch;
    var nearestDistance = 49;
    for (final match in amountRegex.allMatches(message)) {
      final distance = match.end <= marker.start
          ? marker.start - match.end
          : marker.end <= match.start
          ? match.start - marker.end
          : 0;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        amountMatch = match;
      }
    }
    if (amountMatch == null) return null;

    final amountStr = amountMatch.group(1)?.replaceAll(',', '');
    final amount = double.tryParse(amountStr ?? '');
    if (amount == null || amount <= 0 || amount > 10000000) return null;

    var merchant = 'Unknown';
    final paidToRegex = RegExp(
      r"paid\s+(?:via\s+\w+\s+)?to\s+([A-Za-z0-9\s@.&'-]+?)(?=\s+(?:on|ref|upi|via)\b|[,.]|$)",
      caseSensitive: false,
    );
    final atRegex = RegExp(
      r"at\s+([A-Za-z0-9\s@.&'-]+?)(?=\s+(?:on|ref|upi|via)\b|[,.]|$)",
      caseSensitive: false,
    );
    final toRegex = RegExp(
      r"to\s+([A-Za-z0-9\s@.&'-]+?)(?=\s+(?:on|ref|upi|via)\b|[,.]|$)",
      caseSensitive: false,
    );

    if (paidToRegex.hasMatch(message)) {
      merchant = paidToRegex.firstMatch(message)?.group(1)?.trim() ?? 'Unknown';
    } else if (atRegex.hasMatch(message)) {
      merchant = atRegex.firstMatch(message)?.group(1)?.trim() ?? 'Unknown';
    } else if (toRegex.hasMatch(message)) {
      merchant = toRegex.firstMatch(message)?.group(1)?.trim() ?? 'Unknown';
    }

    merchant = merchant.trim();
    if (merchant.isEmpty) merchant = 'Unknown';

    final (category, isUncategorized) = resolveImportedCategory(
      merchant,
      memoryLookup,
    );

    return Expense(
      id: _uuid.v4(),
      title: merchant,
      amount: amount,
      category: category,
      date: date,
      isManual: false,
      isUncategorized: isUncategorized,
      source: 'sms',
    );
  }
}
