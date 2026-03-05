import '../models/expense.dart';
import '../models/category.dart';
import 'package:uuid/uuid.dart';

class SMSParser {
  static const _uuid = Uuid();

  // Common keywords to ignore
  static final _ignoreKeywords = [
    'otp', 'pin', 'code', 'verification', 'password', 'credited', 'refund',
    'reversal', 'failed', 'declined', 'unsuccessful'
  ];

  static bool isDebit(String message) {
    final lowerMsg = message.toLowerCase();
    
    // Check for ignore keywords first
    for (var keyword in _ignoreKeywords) {
      if (lowerMsg.contains(keyword)) return false;
    }

    // Must contain debit-related words
    return lowerMsg.contains('debited') || 
           lowerMsg.contains('spent') || 
           lowerMsg.contains('paid');
  }

  static Expense? parseSMS(String message, DateTime date) {
    if (!isDebit(message)) return null;
    
    // Amount matching Rs. X, INR X, Rs X, ₹ X
    final amountRegex = RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
    final amountMatch = amountRegex.firstMatch(message);
    
    if (amountMatch == null) return null;
    
    final amountStr = amountMatch.group(1)?.replaceAll(',', '');
    final amount = double.tryParse(amountStr ?? '');
    
    if (amount == null) return null;

    // Merchant matching
    String merchant = 'Unknown';
    
    // Pattern 1: paid to [merchant]
    final paidToRegex = RegExp(r'paid\s+(?:via\s+\w+\s+)?to\s+([A-Za-z0-9\s@.&]+?)(?:\s+(?:on|ref|upi|via|$))', caseSensitive: false);
    
    // Pattern 2: at [merchant]
    final atRegex = RegExp(r'at\s+([A-Za-z0-9\s@.&]+?)(?:\s+(?:on|ref|upi|via|$))', caseSensitive: false);
    
    // Pattern 3: to [merchant] (for UPI)
    final toRegex = RegExp(r'to\s+([A-Za-z0-9\s@.&]+?)(?:\s+(?:on|ref|upi|via|$))', caseSensitive: false);

    if (paidToRegex.hasMatch(message)) {
      merchant = paidToRegex.firstMatch(message)?.group(1)?.trim() ?? 'Unknown';
    } else if (atRegex.hasMatch(message)) {
      merchant = atRegex.firstMatch(message)?.group(1)?.trim() ?? 'Unknown';
    } else if (toRegex.hasMatch(message)) {
      merchant = toRegex.firstMatch(message)?.group(1)?.trim() ?? 'Unknown';
    }

    // Clean up merchant name
    if (merchant.toLowerCase().endsWith(' on')) merchant = merchant.substring(0, merchant.length - 3);
    merchant = merchant.trim();
    if (merchant.isEmpty) merchant = 'Unknown';

    return Expense(
      id: _uuid.v4(),
      title: merchant,
      amount: amount,
      category: Category.other,
      date: date,
      isManual: false,
      isUncategorized: true,
      source: 'sms',
    );
  }
}
