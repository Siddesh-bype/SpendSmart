import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/utils/financial_period.dart';

void main() {
  group('FinancialPeriod.containing', () {
    test('a calendar-aligned period is the calendar month', () {
      final period = FinancialPeriod.containing(DateTime(2026, 8, 4), 1);

      expect(period.start, DateTime(2026, 8, 1));
      expect(period.endExclusive, DateTime(2026, 9, 1));
    });

    // The regression this class exists for: on the 4th with a starting day of
    // 10 the live cycle began the *previous* month. Screens used to ask for the
    // period starting August 10, which had not begun, so totals read zero.
    test('before the starting day the period began last month', () {
      final period = FinancialPeriod.containing(DateTime(2026, 8, 4), 10);

      expect(period.start, DateTime(2026, 7, 10));
      expect(period.endExclusive, DateTime(2026, 8, 10));
      expect(period.contains(DateTime(2026, 8, 4)), isTrue);
    });

    test('on the starting day a new period begins', () {
      final period = FinancialPeriod.containing(DateTime(2026, 8, 10), 10);

      expect(period.start, DateTime(2026, 8, 10));
      expect(period.endExclusive, DateTime(2026, 9, 10));
    });

    test('after the starting day the period began this month', () {
      final period = FinancialPeriod.containing(DateTime(2026, 8, 11), 10);

      expect(period.start, DateTime(2026, 8, 10));
    });

    test('January before the starting day rolls back into December', () {
      final period = FinancialPeriod.containing(DateTime(2026, 1, 5), 15);

      expect(period.start, DateTime(2025, 12, 15));
      expect(period.endExclusive, DateTime(2026, 1, 15));
    });

    test('December rolls forward into January', () {
      final period = FinancialPeriod.containing(DateTime(2026, 12, 20), 15);

      expect(period.start, DateTime(2026, 12, 15));
      expect(period.endExclusive, DateTime(2027, 1, 15));
    });

    // A starting day of 31 would name a date February does not have, and
    // DateTime rolls that into March, shifting the whole cycle.
    test('a starting day past the shortest month is clamped', () {
      final period = FinancialPeriod.containing(DateTime(2026, 2, 15), 31);

      expect(period.start, DateTime(2026, 1, 28));
      expect(period.endExclusive, DateTime(2026, 2, 28));
      expect(period.contains(DateTime(2026, 2, 15)), isTrue);
    });

    test('every day of a year lands in exactly one period', () {
      for (final startingDay in const [1, 5, 15, 28]) {
        for (var i = 0; i < 365; i++) {
          final day = DateTime(2026, 1, 1).add(Duration(days: i));
          final period = FinancialPeriod.containing(day, startingDay);

          expect(
            period.contains(day),
            isTrue,
            reason: '$day was not in its own period (start $startingDay)',
          );
          expect(period.previous.contains(day), isFalse);
          expect(period.next.contains(day), isFalse);
        }
      }
    });
  });

  group('boundaries', () {
    test('the last instant before the next start still belongs here', () {
      final period = FinancialPeriod.startingIn(2026, 3, 1);

      expect(
        period.contains(DateTime(2026, 3, 31, 23, 59, 59, 999)),
        isTrue,
      );
      expect(period.contains(DateTime(2026, 4, 1)), isFalse);
    });

    test('adjacent periods meet without a gap or an overlap', () {
      final period = FinancialPeriod.startingIn(2026, 3, 10);

      expect(period.next.start, period.endExclusive);
      expect(period.previous.endExclusive, period.start);
    });
  });

  group('day arithmetic', () {
    test('totalDays follows the real month length', () {
      expect(FinancialPeriod.startingIn(2026, 2, 1).totalDays, 28);
      expect(FinancialPeriod.startingIn(2024, 2, 1).totalDays, 29);
      expect(FinancialPeriod.startingIn(2026, 3, 1).totalDays, 31);
    });

    test('elapsed and remaining split the period', () {
      final period = FinancialPeriod.startingIn(2026, 3, 1);
      final moment = DateTime(2026, 3, 11);

      expect(period.daysElapsed(moment), 11);
      expect(period.daysRemaining(moment), 21);
    });

    // Projections divide by daysElapsed, so a zero would produce infinity.
    test('elapsed is never zero on the first day', () {
      final period = FinancialPeriod.startingIn(2026, 3, 10);

      expect(period.daysElapsed(DateTime(2026, 3, 10)), 1);
      expect(period.daysElapsed(DateTime(2026, 3, 10, 0, 0, 1)), 1);
    });

    test('a moment past the end reports the whole period', () {
      final period = FinancialPeriod.startingIn(2026, 3, 1);

      expect(period.daysElapsed(DateTime(2026, 5, 1)), 31);
      expect(period.daysRemaining(DateTime(2026, 5, 1)), 1);
    });

    test('a custom period spanning two months counts across the boundary', () {
      final period = FinancialPeriod.startingIn(2026, 7, 10);

      expect(period.totalDays, 31);
      expect(period.daysElapsed(DateTime(2026, 8, 4)), 26);
      expect(period.daysRemaining(DateTime(2026, 8, 4)), 6);
    });
  });

  test('a period spanning two months is named after the one it starts in', () {
    expect(FinancialPeriod.startingIn(2026, 7, 10).label, 'July 2026');
  });

  test('shifted moves whole periods', () {
    final period = FinancialPeriod.startingIn(2026, 3, 10);

    expect(period.shifted(-1), period.previous);
    expect(period.shifted(1), period.next);
    expect(period.shifted(-3).start, DateTime(2025, 12, 10));
  });
}
