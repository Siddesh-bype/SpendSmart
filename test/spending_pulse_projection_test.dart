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

  group('fixed-vs-variable forecast split', () {
    Expense titled(String title, double amount, DateTime date) => Expense(
      id: 'e-$title-${date.toIso8601String()}-$amount',
      title: title,
      amount: amount,
      category: Category.food,
      date: date,
      isManual: true,
      isUncategorized: false,
      source: 'manual',
    );

    // July 2026 (31 days). Rent 10000 lands Apr/May/Jun 15 -> fixed at 10000.
    List<Expense> history() => [
      for (final month in [4, 5, 6])
        titled('Rent', 10000, DateTime(2026, month, 15)),
    ];

    test('fixed commitments go 1:1 while only the variable remainder paces',
        () {
      // Now Jul 10 (elapsed 10): rent 10000 already paid + food 1000.
      // Fixed 10000 + variable pace 1000 / 10 * 31 = 3100 -> 13100.
      // The old pace-only formula would say 11000 / 10 * 31 = 34100.
      final current = [
        titled('Rent', 10000, DateTime(2026, 7, 1)),
        titled('Food', 1000, DateTime(2026, 7, 2)),
      ];
      final detailed = SpendingPulseCard.projectMonthEndDetailed(
        monthlyExpenses: current,
        startingDayOfMonth: 1,
        now: DateTime(2026, 7, 10),
        allExpenses: [...history(), ...current],
      )!;

      expect(detailed.amount, closeTo(13100, 0.001));
      expect(detailed.fixedTotal, 10000);
      expect(detailed.isEarlyEstimate, isFalse);
      expect(
        SpendingPulseCard.projectMonthEnd(
          monthlyExpenses: current,
          startingDayOfMonth: 1,
          now: DateTime(2026, 7, 10),
          allExpenses: [...history(), ...current],
        ),
        closeTo(13100, 0.001),
      );
    });

    test('a fixed bill not yet paid is still committed 1:1', () {
      // Only food 1000 spent by Jul 10; rent 10000 still lands this month.
      final current = [titled('Food', 1000, DateTime(2026, 7, 2))];
      final detailed = SpendingPulseCard.projectMonthEndDetailed(
        monthlyExpenses: current,
        startingDayOfMonth: 1,
        now: DateTime(2026, 7, 10),
        allExpenses: [...history(), ...current],
      )!;

      expect(detailed.amount, closeTo(13100, 0.001));
      expect(detailed.fixedTotal, 10000);
    });

    test('history without stable merchants matches the old pace formula', () {
      // 1000 / 1500 / 800 never stabilizes, so nothing is fixed.
      final all = [
        titled('Food', 1000, DateTime(2026, 4, 15)),
        titled('Food', 1500, DateTime(2026, 5, 15)),
        titled('Food', 800, DateTime(2026, 6, 15)),
        titled('Food', 1000, DateTime(2026, 7, 2)),
      ];
      final detailed = SpendingPulseCard.projectMonthEndDetailed(
        monthlyExpenses: [titled('Food', 1000, DateTime(2026, 7, 2))],
        startingDayOfMonth: 1,
        now: DateTime(2026, 7, 10),
        allExpenses: all,
      )!;

      expect(detailed.fixedTotal, 0);
      expect(detailed.amount, closeTo(1000 / 10 * 31, 0.001));
      expect(detailed.isEarlyEstimate, isFalse);
    });
  });

  group('cold start', () {
    // March 2026 (31 days). Day 5 => elapsed 5.
    final coldNow = DateTime(2026, 3, 5);

    test('fewer than 2 history months marks the projection an early estimate',
        () {
      final current = [expense(100, DateTime(2026, 3, 1))];
      final detailed = SpendingPulseCard.projectMonthEndDetailed(
        monthlyExpenses: current,
        startingDayOfMonth: 1,
        now: coldNow,
        allExpenses: current,
      )!;

      expect(detailed.amount, closeTo(100 / 5 * 31, 0.001));
      expect(detailed.isEarlyEstimate, isTrue);
    });

    test('omitting history degrades to the old formula as an early estimate',
        () {
      final current = [expense(100, DateTime(2026, 3, 1))];
      final detailed = SpendingPulseCard.projectMonthEndDetailed(
        monthlyExpenses: current,
        startingDayOfMonth: 1,
        now: coldNow,
      )!;

      expect(detailed.amount, closeTo(100 / 5 * 31, 0.001));
      expect(detailed.isEarlyEstimate, isTrue);
    });
  });
}
