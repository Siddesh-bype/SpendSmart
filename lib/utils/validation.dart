const maxMoneyAmount = 10000000.0;

double? parsePositiveAmount(String input) {
  final value = double.tryParse(input.replaceAll(',', '').trim());
  if (value == null ||
      !value.isFinite ||
      value <= 0 ||
      value > maxMoneyAmount) {
    return null;
  }
  return value;
}

/// Parses an amount that may carry a sign or accounting parentheses
/// ("-350.00", "(350.00)"), as bank CSV exports commonly mark debits.
/// Currency symbols and thousands separators are ignored. Returns the signed
/// value, or null when the text is not a valid amount.
double? parseSignedAmount(String input) {
  var text = input
      .replaceAll(RegExp(r'(?:rs\.?|inr|[₹$€£¥])', caseSensitive: false), '')
      .replaceAll(',', '')
      .trim();
  var negative = false;
  if (text.startsWith('(') && text.endsWith(')')) {
    negative = true;
    text = text.substring(1, text.length - 1).trim();
  }
  if (text.startsWith('-')) {
    negative = true;
    text = text.substring(1).trim();
  } else if (text.startsWith('+')) {
    text = text.substring(1).trim();
  }
  final value = double.tryParse(text);
  if (value == null ||
      !value.isFinite ||
      value <= 0 ||
      value > maxMoneyAmount) {
    return null;
  }
  return negative ? -value : value;
}

/// Splits [amount] into [count] whole-cent shares that always sum back to the
/// amount, handing the rounding remainder out one cent at a time. Rounding
/// each share independently can drift past a small tolerance check
/// (e.g. 100 across 7 people => 14.29 x 7 = 100.03).
List<double> splitEvenly(double amount, int count) {
  if (count <= 0) return const [];
  final totalCents = (amount * 100).round();
  final base = totalCents ~/ count;
  var remainder = totalCents - base * count;
  final shares = <double>[];
  for (var i = 0; i < count; i++) {
    var cents = base;
    if (remainder > 0) {
      cents++;
      remainder--;
    }
    shares.add(cents / 100);
  }
  return shares;
}
