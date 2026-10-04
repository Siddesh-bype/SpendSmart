import 'dart:math';

import '../models/expense.dart';
import '../utils/financial_period.dart';
import 'category_classifier.dart';

/// A recurring commitment detected from consecutive stable history.
///
/// [expectedAmount] is the mean monthly total over the stable trailing run.
class FixedObligation {
  const FixedObligation({
    required this.merchantKey,
    required this.displayName,
    required this.expectedAmount,
  });

  /// Normalized key from [CategoryClassifier.normalizeMerchant].
  final String merchantKey;

  /// Most recent raw title behind [merchantKey] in the examined history.
  final String displayName;

  final double expectedAmount;
}

/// Fixed-commitment detection, on device.
///
/// A normalized merchant present in >= 2 consecutive completed
/// [FinancialPeriod]s whose monthly totals vary by less than
/// [varianceTolerance] (relative spread `(max - min) / mean`) counts as a
/// fixed commitment. The run is anchored at the most recent history period:
/// an older stable streak that has since changed does not qualify, and a gap
/// month breaks consecutiveness. Pure Dart: no Hive, no Riverpod, no widgets.
class FixedObligationService {
  const FixedObligationService._();

  static const defaultHistoryMonths = 3;
  static const defaultVarianceTolerance = 0.15;

  static List<FixedObligation> detect({
    required Iterable<Expense> expenses,
    required int startingDayOfMonth,
    DateTime? now,
    int historyMonths = defaultHistoryMonths,
    double varianceTolerance = defaultVarianceTolerance,
  }) {
    final date = now ?? DateTime.now();
    final period = FinancialPeriod.containing(date, startingDayOfMonth);
    final historyPeriods = List.generate(
      historyMonths,
      (index) => period.shifted(index - historyMonths),
    );
    final totalsPerPeriod = <_MonthTotals>[
      for (final historyPeriod in historyPeriods)
        _monthTotals(expenses, historyPeriod),
    ];

    final keys = <String>{
      for (final totals in totalsPerPeriod) ...totals.amounts.keys,
    };
    final obligations = <FixedObligation>[];
    for (final key in keys) {
      // Trailing run: consecutive non-zero months ending at the newest
      // history period. A gap breaks the run, so only the newest streak can
      // qualify.
      final run = <double>[];
      for (var index = totalsPerPeriod.length - 1; index >= 0; index--) {
        final amount = totalsPerPeriod[index].amounts[key] ?? 0;
        if (amount <= 0) break;
        run.add(amount);
      }
      // Shrink from the oldest end until the run is stable; a merchant whose
      // spend changed and then re-stabilized commits at the new level.
      while (run.length >= 2 && !_isStable(run, varianceTolerance)) {
        run.removeLast();
      }
      if (run.length < 2) continue;
      final mean = run.reduce((a, b) => a + b) / run.length;
      obligations.add(
        FixedObligation(
          merchantKey: key,
          displayName: _latestTitle(totalsPerPeriod, key) ?? key,
          expectedAmount: _round(mean),
        ),
      );
    }
    return obligations;
  }

  /// Whether [currentAmount] is the expected payment rather than a spike:
  /// within [tolerance] of [expectedAmount] by relative difference against
  /// their mean. Used by spike detection so a fixed bill paid in full early
  /// in the month (which looks multi-x against its pro-rated pace) is not
  /// flagged, while a genuine overage still is.
  static bool isWithinCommitment({
    required double currentAmount,
    required double expectedAmount,
    double tolerance = defaultVarianceTolerance,
  }) {
    if (currentAmount <= 0 || expectedAmount <= 0) return false;
    final mean = (currentAmount + expectedAmount) / 2;
    return ((currentAmount - expectedAmount).abs() / mean) < tolerance;
  }

  static bool _isStable(List<double> amounts, double tolerance) {
    final maxAmount = amounts.reduce(max);
    final minAmount = amounts.reduce(min);
    final mean = amounts.reduce((a, b) => a + b) / amounts.length;
    if (mean <= 0) return false;
    return (maxAmount - minAmount) / mean < tolerance;
  }

  /// Merchant totals for one period, excluding uncategorized expenses.
  static _MonthTotals _monthTotals(
    Iterable<Expense> expenses,
    FinancialPeriod period,
  ) {
    final amounts = <String, double>{};
    final titles = <String, String>{};
    final titleDates = <String, DateTime>{};
    for (final expense in expenses) {
      if (expense.isUncategorized ||
          !expense.amount.isFinite ||
          expense.amount <= 0 ||
          !period.contains(expense.date)) {
        continue;
      }
      final key = CategoryClassifier.normalizeMerchant(expense.title);
      if (key.isEmpty) continue;
      amounts[key] = (amounts[key] ?? 0) + expense.amount;
      final latest = titleDates[key];
      if (latest == null || !expense.date.isBefore(latest)) {
        titleDates[key] = expense.date;
        titles[key] = expense.title.trim();
      }
    }
    return _MonthTotals(amounts, titles);
  }

  static String? _latestTitle(
    List<_MonthTotals> totalsPerPeriod,
    String key,
  ) {
    for (var index = totalsPerPeriod.length - 1; index >= 0; index--) {
      final title = totalsPerPeriod[index].titles[key];
      if (title != null && title.isNotEmpty) return title;
    }
    return null;
  }

  static double _round(double value) => (value * 100).roundToDouble() / 100;
}

class _MonthTotals {
  const _MonthTotals(this.amounts, this.titles);

  final Map<String, double> amounts;
  final Map<String, String> titles;
}
