import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/models/category.dart';
import 'package:spendsmart/models/expense.dart';
import 'package:spendsmart/services/category_classifier.dart';
import 'package:spendsmart/services/merchant_anomaly_service.dart';

/// Last day of the July 2026 custom month, so `daysElapsed == totalDays` and
/// the pro-rated expectation equals the raw baseline. The pro-rating group uses
/// a mid-month date instead.
final _endOfJuly = DateTime(2026, 7, 31);

Expense _expense(
  String title,
  double amount,
  DateTime date, {
  bool isUncategorized = false,
}) => Expense(
  id: '$title-$date-$amount',
  title: title,
  amount: amount,
  category: Category.food,
  date: date,
  isManual: true,
  isUncategorized: isUncategorized,
  source: 'test',
);

/// [amount] on the same merchant in each of the three months before July 2026.
List<Expense> _history(
  String title,
  double amount, {
  bool isUncategorized = false,
}) => [
  for (final month in [4, 5, 6])
    _expense(
      title,
      amount,
      DateTime(2026, month, 15),
      isUncategorized: isUncategorized,
    ),
];

List<MerchantAnomaly> _detect(
  List<Expense> expenses, {
  double monthlyBudget = 20000,
  int startingDayOfMonth = 1,
  DateTime? now,
}) => MerchantAnomalyService.detect(
  expenses: expenses,
  monthlyBudget: monthlyBudget,
  startingDayOfMonth: startingDayOfMonth,
  now: now ?? _endOfJuly,
);

void main() {
  group('severity', () {
    test('a 3x merchant spike is critical', () {
      final result = _detect([
        ..._history('Swiggy', 3000),
        _expense('Swiggy', 9000, DateTime(2026, 7, 20)),
      ]);

      expect(result, hasLength(1));
      expect(result.single.merchantKey, 'swiggy');
      expect(result.single.displayName, 'Swiggy');
      expect(result.single.currentAmount, 9000);
      expect(result.single.baselineAmount, 3000);
      expect(result.single.excess, 6000);
      expect(result.single.severity, 'critical');
    });

    test('a 1.6x spike is a warning', () {
      final result = _detect([
        ..._history('Zomato', 5000),
        _expense('Zomato', 8000, DateTime(2026, 7, 20)),
      ]);

      expect(result, hasLength(1));
      expect(result.single.merchantKey, 'zomato');
      expect(result.single.baselineAmount, 5000);
      expect(result.single.currentAmount, 8000);
      expect(result.single.severity, 'warning');
    });

    test('a merchant spending its baseline is not flagged', () {
      final result = _detect([
        ..._history('Netflix', 2000),
        _expense('Netflix', 2000, DateTime(2026, 7, 20)),
      ]);

      expect(result, isEmpty);
    });

    test('a first-ever merchant is not flagged', () {
      final result = _detect([
        ..._history('Swiggy', 3000),
        _expense('Swiggy', 3000, DateTime(2026, 7, 20)),
        _expense('AMAZON', 9000, DateTime(2026, 7, 20)),
      ]);

      expect(result, isEmpty);
    });
  });

  group('minimum impact', () {
    final expenses = [
      ..._history('Swiggy', 3000),
      _expense('Swiggy', 3000, DateTime(2026, 7, 20)),
      ..._history('Chai Point', 500),
      _expense('Chai Point', 1400, DateTime(2026, 7, 20)),
    ];

    test('a 2.8x spike worth 900 is suppressed at a 20000 budget', () {
      expect(_detect(expenses), isEmpty);
    });

    test('the same spike clears the bar at a 10000 budget', () {
      final result = _detect(expenses, monthlyBudget: 10000);

      expect(result, hasLength(1));
      expect(result.single.merchantKey, 'chai point');
      expect(result.single.excess, 900);
    });

    test('no budget falls back to an absolute floor, not 1', () {
      final result = _detect([
        ..._history('Swiggy', 3000),
        _expense('Swiggy', 9000, DateTime(2026, 7, 20)),
        ..._history('Chai Point', 600),
        _expense('Chai Point', 1000, DateTime(2026, 7, 20)),
      ], monthlyBudget: 0);

      expect(result, hasLength(1));
      expect(result.single.merchantKey, 'swiggy');
    });
  });

  group('pro-rating', () {
    final midJuly = DateTime(2026, 7, 11); // day 11 of 31

    test('on-pace mid-month spending is not flagged', () {
      final result = _detect([
        ..._history('Swiggy', 6200),
        _expense('Swiggy', 2200, DateTime(2026, 7, 5)),
      ], now: midJuly);

      expect(result, isEmpty);
    });

    test('an early spike is caught below the full-month baseline', () {
      final result = _detect([
        ..._history('Swiggy', 6200),
        _expense('Swiggy', 5000, DateTime(2026, 7, 5)),
      ], now: midJuly);

      expect(result, hasLength(1));
      expect(result.single.baselineAmount, 2200); // 6200 * 11 / 31
      expect(result.single.currentAmount, 5000);
      expect(result.single.severity, 'critical');
    });
  });

  group('merchant grouping', () {
    test('rail, handle and reference variants collapse into one merchant', () {
      final result = _detect([
        ..._history('Swiggy', 3000),
        _expense('UPI-SWIGGY-123', 3000, DateTime(2026, 7, 2)),
        _expense('swiggy@ybl', 3000, DateTime(2026, 7, 10)),
        _expense('Swiggy', 3000, DateTime(2026, 7, 20)),
      ]);

      expect(result, hasLength(1));
      expect(result.single.merchantKey, 'swiggy');
      expect(result.single.currentAmount, 9000);
      expect(result.single.displayName, 'Swiggy'); // most recent raw title
    });

    test('a corporate suffix collapses into the base merchant', () {
      expect(CategoryClassifier.normalizeMerchant('SWIGGY LTD'), 'swiggy');

      final result = _detect([
        ..._history('Swiggy', 3000),
        _expense('Swiggy', 3000, DateTime(2026, 7, 20)),
        _expense('SWIGGY LTD', 9000, DateTime(2026, 7, 20)),
      ]);

      // Shares `swiggy`'s baseline instead of getting its own absent one.
      expect(result, hasLength(1));
      expect(result.single.merchantKey, 'swiggy');
      expect(result.single.currentAmount, 12000);
      expect(result.single.baselineAmount, 3000);
      expect(result.single.severity, 'critical');
    });
  });

  group('baselines', () {
    test('uncategorized history does not build a baseline', () {
      final result = _detect([
        ..._history('Swiggy', 3000),
        _expense('Swiggy', 3000, DateTime(2026, 7, 20)),
        ..._history('AMAZON', 4000, isUncategorized: true),
        _expense('AMAZON', 12000, DateTime(2026, 7, 20)),
      ]);

      expect(result, isEmpty);
    });

    test('the same categorized history does flag the spike', () {
      final result = _detect([
        ..._history('Swiggy', 3000),
        _expense('Swiggy', 3000, DateTime(2026, 7, 20)),
        ..._history('AMAZON', 4000),
        _expense('AMAZON', 12000, DateTime(2026, 7, 20)),
      ]);

      expect(result, hasLength(1));
      expect(result.single.merchantKey, 'amazon');
      expect(result.single.baselineAmount, 4000);
    });

    test('spending before the custom month start counts to the last period', () {
      final result = _detect(
        [
          ..._history('Swiggy', 6200),
          _expense('Swiggy', 5000, DateTime(2026, 7, 5)),
          _expense('Swiggy', 5000, DateTime(2026, 7, 15)),
        ],
        startingDayOfMonth: 10,
        now: DateTime(2026, 7, 20),
      );

      expect(result, hasLength(1));
      expect(result.single.currentAmount, 5000);
      expect(result.single.baselineAmount, closeTo(2791.4, 0.01));
      expect(result.single.severity, 'warning');
    });
  });

  group('degenerate input', () {
    test('no expenses returns no anomalies', () {
      expect(_detect(const []), isEmpty);
    });

    test('a user with no history returns no anomalies', () {
      final result = _detect([
        _expense('Swiggy', 9000, DateTime(2026, 7, 20)),
        _expense('AMAZON', 12000, DateTime(2026, 7, 20)),
      ]);

      expect(result, isEmpty);
    });

    test('one silent month in the history blocks detection', () {
      final result = _detect([
        _expense('Swiggy', 3000, DateTime(2026, 5, 15)),
        _expense('Swiggy', 3000, DateTime(2026, 6, 15)),
        _expense('Swiggy', 9000, DateTime(2026, 7, 20)),
      ]);

      expect(result, isEmpty);
    });
  });

  test('anomalies sort by excess and cap at five', () {
    const excesses = [7000.0, 6000.0, 5000.0, 4000.0, 3000.0, 2000.0, 1500.0];
    final titles = ['A', 'B', 'C', 'D', 'E', 'F', 'G']
        .map((letter) => 'Merchant $letter')
        .toList();

    final expenses = <Expense>[];
    for (var index = 0; index < titles.length; index++) {
      expenses
        ..addAll(_history(titles[index], 1000))
        ..add(
          _expense(
            titles[index],
            1000 + excesses[index],
            DateTime(2026, 7, 20),
          ),
        );
    }

    final result = _detect(expenses..shuffle(Random(7)));

    expect(
      result.map((anomaly) => anomaly.merchantKey),
      ['merchant a', 'merchant b', 'merchant c', 'merchant d', 'merchant e'],
    );
    expect(result.map((anomaly) => anomaly.excess), excesses.take(5));
  });
}
