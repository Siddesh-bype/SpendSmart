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
