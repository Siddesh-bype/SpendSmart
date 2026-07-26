import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/services/sms_parser.dart';

void main() {
  test('parses debit SMS with rupee symbol', () {
    final expense = SMSParser.parseSMS(
      '₹450 paid to Swiggy on UPI ref 123',
      DateTime(2026, 7, 9),
    );

    expect(expense, isNotNull);
    expect(expense!.amount, 450);
    expect(expense.title, 'Swiggy');
  });

  test('ignores OTP and credit messages', () {
    expect(
      SMSParser.parseSMS(
        'Your OTP is 123456. Do not share it.',
        DateTime(2026),
      ),
      isNull,
    );
    expect(
      SMSParser.parseSMS('Rs. 250 credited to your account.', DateTime(2026)),
      isNull,
    );
  });

  test('parses payment words without matching ignore substrings', () {
    final expense = SMSParser.parseSMS(
      'INR 250 paid to Shopping Mart on UPI',
      DateTime(2026, 7, 10),
    );

    expect(expense, isNotNull);
    expect(expense!.title, 'Shopping Mart');
    expect(expense.amount, 250);
  });

  test('rejects refunds failures balances and unsafe amounts', () {
    final date = DateTime(2026, 7, 10);

    expect(SMSParser.parseSMS('INR 500 refund received', date), isNull);
    expect(SMSParser.parseSMS('INR 500 payment failed', date), isNull);
    expect(SMSParser.parseSMS('Available balance INR 5000', date), isNull);
    expect(SMSParser.parseSMS('INR nope paid to Shop', date), isNull);
    expect(SMSParser.parseSMS('INR 10000000.01 paid to Shop', date), isNull);
  });

  test('accepts maximum amount and permits unknown merchant for review', () {
    final expense = SMSParser.parseSMS(
      'INR 10000000 debited from your account',
      DateTime(2026, 7, 10),
    );

    expect(expense, isNotNull);
    expect(expense!.amount, 10000000);
    expect(expense.title, 'Unknown');
  });

  test('uses the amount nearest the debit marker instead of the balance', () {
    final expense = SMSParser.parseSMS(
      'Available balance INR 5000. INR 250 debited at Coffee House.',
      DateTime(2026, 7, 10),
    );

    expect(expense, isNotNull);
    expect(expense!.amount, 250);
    expect(expense.title, 'Coffee House');
  });
}
