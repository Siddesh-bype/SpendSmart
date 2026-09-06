import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/models/category.dart';
import 'package:spendsmart/models/expense.dart';
import 'package:spendsmart/widgets/spending_pulse_card.dart';

void main() {
  Expense expense(double amount, DateTime date) => Expense(
    id: 'e-${date.toIso8601String()}-$amount',
    title: 'test',
    amount: amount,
    category: Category.food,
    date: date,
    isManual: true,
    isUncategorized: false,
    source: 'manual',
  );

  group('SpendingPulseCard.projectMonthEnd', () {
    // Period March 2026 (31 days), starting day 1. Day 5 => elapsed 5.
    final now = DateTime(2026, 3, 5);

    test('returns null with no monthly expenses', () {
      expect(
        SpendingPulseCard.projectMonthEnd(
          monthlyExpenses: const [],
          startingDayOfMonth: 1,
          now: now,
        ),
        isNull,
      );
    });

    test('returns null before 3 days of data', () {
      expect(
        SpendingPulseCard.projectMonthEnd(
          monthlyExpenses: [expense(10, DateTime(2026, 3, 1))],
          startingDayOfMonth: 1,
          now: DateTime(2026, 3, 2),
        ),
        isNull,
      );
    });

    test('pro-rates spend so far across the whole period', () {
      // 100 over 5 elapsed days in a 31-day period => 620.
      final projection = SpendingPulseCard.projectMonthEnd(
        monthlyExpenses: [
          expense(40, DateTime(2026, 3, 1)),
          expense(60, DateTime(2026, 3, 4)),
        ],
        startingDayOfMonth: 1,
        now: now,
      );
      expect(projection, closeTo(620, 0.001));
    });

    test('ignores future-dated expenses in the spend sum', () {
      final projection = SpendingPulseCard.projectMonthEnd(
        monthlyExpenses: [
          expense(40, DateTime(2026, 3, 1)),
          expense(1000, DateTime(2026, 3, 20)),
        ],
        startingDayOfMonth: 1,
        now: now,
      );
      expect(projection, closeTo(248, 0.001));
    });

    test('projects against the custom cycle length, not the calendar month',
        () {
      // Cycle runs Feb 15 -> Mar 15 (28 days). Now Mar 5 => elapsed 19.
      // 190 / 19 * 28 = 280.
      final projection = SpendingPulseCard.projectMonthEnd(
        monthlyExpenses: [expense(190, DateTime(2026, 2, 16))],
        startingDayOfMonth: 15,
        now: now,
      );
      expect(projection, closeTo(280, 0.001));
    });

    test('returns null when spend is not positive', () {
      expect(
        SpendingPulseCard.projectMonthEnd(
          monthlyExpenses: [
            expense(-10, DateTime(2026, 3, 1)),
          ],
          startingDayOfMonth: 1,
          now: now,
        ),
        isNull,
      );
    });
  });
}
