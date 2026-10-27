import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/models/category.dart';
import 'package:spendsmart/models/recurring_expense.dart';

RecurringExpense rule(String frequency, DateTime startDate) =>
    RecurringExpense(
      id: 'rule',
      title: 'Rule',
      amount: 100,
      category: Category.bills,
      frequency: frequency,
      startDate: startDate,
      nextDue: startDate,
    );

void main() {
  group('monthly recurrence anchors to the start day', () {
    // The regression: the cursor's day was used as the anchor, so Jan 31
    // became Feb 28 and then stayed on the 28th forever.
    test('Jan 31 goes Feb 28, then back to Mar 31', () {
      final r = rule('monthly', DateTime(2026, 1, 31));
      final feb = r.computeNextDue(DateTime(2026, 1, 31));
      expect(feb, DateTime(2026, 2, 28));
      expect(r.computeNextDue(feb), DateTime(2026, 3, 31));
    });

    test('a mid-month day is unaffected', () {
      final r = rule('monthly', DateTime(2026, 1, 15));
      expect(r.computeNextDue(DateTime(2026, 1, 15)), DateTime(2026, 2, 15));
    });

    test('December wraps into January of the next year', () {
      final r = rule('monthly', DateTime(2026, 12, 5));
      expect(r.computeNextDue(DateTime(2026, 12, 5)), DateTime(2027, 1, 5));
    });

    test('a drifted cursor self-heals back to the anchor day', () {
      // Data written by the old drifting logic sits on the 28th; the next
      // step must return to the anchored 31st, not advance from 28.
      final r = rule('monthly', DateTime(2026, 1, 31));
      expect(r.computeNextDue(DateTime(2026, 3, 28)), DateTime(2026, 4, 30));
    });
  });

  group('yearly recurrence anchors to the start month and day', () {
    test('Feb 29 stays in February (clamped in common years)', () {
      final r = rule('yearly', DateTime(2024, 2, 29));
      expect(r.computeNextDue(DateTime(2024, 2, 29)), DateTime(2025, 2, 28));
      expect(r.computeNextDue(DateTime(2025, 2, 28)), DateTime(2026, 2, 28));
    });

    test('a normal date is unchanged', () {
      final r = rule('yearly', DateTime(2026, 12, 25));
      expect(r.computeNextDue(DateTime(2026, 12, 25)), DateTime(2027, 12, 25));
    });
  });

  test('daily and weekly advance by fixed durations', () {
    final r = rule('daily', DateTime(2026, 10, 28));
    expect(r.computeNextDue(DateTime(2026, 10, 28)), DateTime(2026, 10, 29));
    final w = rule('weekly', DateTime(2026, 10, 28));
    expect(w.computeNextDue(DateTime(2026, 10, 28)), DateTime(2026, 11, 4));
  });
}
