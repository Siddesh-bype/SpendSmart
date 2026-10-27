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

  test('parseSignedAmount reads the sign conventions bank exports use', () {
    expect(parseSignedAmount('-350.00'), -350.00);
    expect(parseSignedAmount('(350.00)'), -350.00);
    expect(parseSignedAmount('+350.00'), 350.00);
    expect(parseSignedAmount('350.00'), 350.00);
    expect(parseSignedAmount('₹-350.00'), -350.00);
    expect(parseSignedAmount('-₹350'), -350.0);
    expect(parseSignedAmount('1,250.50'), 1250.50);
    expect(parseSignedAmount('0'), isNull);
    expect(parseSignedAmount('-0.00'), isNull);
    expect(parseSignedAmount('abc'), isNull);
    expect(parseSignedAmount(''), isNull);
  });

  test('splitEvenly hands out the rounding remainder in whole cents', () {
    // The regression: 100 across 7 rounded per-share drifts to 100.03 and
    // fails the sheet's own 0.02 tolerance.
    final shares = splitEvenly(100, 7);
    expect(shares, hasLength(7));
    expect(shares.fold(0.0, (s, v) => s + v), closeTo(100, 0.0001));
    expect(shares.every((v) => (v * 100).round() == v * 100), isTrue);

    expect(splitEvenly(1000, 3).fold(0.0, (s, v) => s + v), closeTo(1000, 0.0001));
    expect(splitEvenly(0.02, 3).fold(0.0, (s, v) => s + v), closeTo(0.02, 0.0001));
    expect(splitEvenly(100, 1), [100.0]);
    expect(splitEvenly(100, 0), isEmpty);
    expect(splitEvenly(100, -1), isEmpty);
  });
}
