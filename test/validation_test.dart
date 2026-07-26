import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/utils/validation.dart';

void main() {
  test('parsePositiveAmount accepts valid money and rejects unsafe values', () {
    expect(parsePositiveAmount('1,250.50'), 1250.50);
    expect(parsePositiveAmount('0'), isNull);
    expect(parsePositiveAmount('-1'), isNull);
    expect(parsePositiveAmount('NaN'), isNull);
    expect(parsePositiveAmount('Infinity'), isNull);
    expect(parsePositiveAmount('10000000.01'), isNull);
  });
}
