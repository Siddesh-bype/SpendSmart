import 'dart:math';

import '../models/expense.dart';
import '../utils/financial_period.dart';
import 'category_classifier.dart';
import 'fixed_obligation_service.dart';

class MerchantAnomaly {
  const MerchantAnomaly({
    required this.merchantKey,
    required this.displayName,
    required this.currentAmount,
    required this.baselineAmount,
    required this.severity,
  });

  /// Normalized key from [CategoryClassifier.normalizeMerchant], e.g. `swiggy`.
  final String merchantKey;

  /// Most recent raw title behind [merchantKey] this period — never show the key.
  final String displayName;

  final double currentAmount;

  /// Pro-rated expectation for [daysElapsed], not the full-month average.
  final double baselineAmount;

  final String severity; // 'warning' | 'critical'

  double get excess => currentAmount - baselineAmount;
}

/// Merchant-level anomaly detection, on device.
///
/// Flags merchants whose recent spend exceeds their own 3-month baseline,
/// one level finer than category-level spikes, so it needs no network call.
/// Pure Dart: no Hive, no Riverpod, no widgets.
class MerchantAnomalyService {
  static const _historyMonths = 3;
  static const _spikeRatio = 1.5;
  static const _criticalRatio = 2.0;
  static const _budgetImpactShare = 0.05;
  static const _maxResults = 5;

  /// Impact floor when no budget is set. Without a floor, rupee-level noise
  /// would flag here, because a merchant baseline is far smaller than a
  /// category one.
  static const _noBudgetMinimumImpact = 500.0;

  static List<MerchantAnomaly> detect({
    required Iterable<Expense> expenses,
    required double monthlyBudget,
    required int startingDayOfMonth,
    DateTime? now,
  }) {
    final date = now ?? DateTime.now();
    final period = FinancialPeriod.containing(date, startingDayOfMonth);
    final totalDays = period.totalDays;
    final daysElapsed = period.daysElapsed(date);
    if (totalDays <= 0 || daysElapsed <= 0) return const [];

    final current = _monthTotals(expenses, period);
    if (current.amounts.isEmpty) return const [];

    final history = List.generate(
      _historyMonths,
      (index) => _monthTotals(expenses, period.shifted(-index - 1)),
    );
    // Relaxed guard: at least 2 of the 3 history months must carry data.
    // One silent month (new user, missing import) no longer suppresses
    // everything; two silent months still mean there is no baseline to judge.
    // The baseline divides by the months that actually carry data, so one
    // silent month does not drag the average down by a phantom zero.
    final monthsWithData = history.where((month) => month.total > 0).length;
    if (monthsWithData < 2) {
      return const [];
    }

    final minimumImpact = monthlyBudget > 0
        ? max(1.0, monthlyBudget * _budgetImpactShare)
        : _noBudgetMinimumImpact;

    // Fixed commitments carry their full-month expectation, not the
    // pro-rated pace: a bill paid in full on day 2 looks multi-x against its
    // pace but is the expected payment, not an anomaly.
    final fixedExpected = <String, double>{
      for (final obligation in FixedObligationService.detect(
        expenses: expenses,
        startingDayOfMonth: startingDayOfMonth,
        now: date,
      ))
        obligation.merchantKey: obligation.expectedAmount,
    };

    final anomalies = <MerchantAnomaly>[];
    current.amounts.forEach((key, currentAmount) {
      final committed = fixedExpected[key];
      if (committed != null &&
          FixedObligationService.isWithinCommitment(
            currentAmount: currentAmount,
            expectedAmount: committed,
          )) {
        return;
      }
      final baseline =
          history.fold<double>(
            0,
            (total, month) => total + (month.amounts[key] ?? 0),
          ) /
          monthsWithData;
      final expectedByNow = baseline * daysElapsed / totalDays;
      final excess = currentAmount - expectedByNow;
      if (expectedByNow <= 0 ||
          currentAmount < expectedByNow * _spikeRatio ||
          excess < minimumImpact) {
        return;
      }
      final title = current.titles[key];
      anomalies.add(
        MerchantAnomaly(
          merchantKey: key,
          displayName: title == null || title.isEmpty ? key : title,
          currentAmount: _round(currentAmount),
          baselineAmount: _round(expectedByNow),
          severity: currentAmount >= expectedByNow * _criticalRatio
              ? 'critical'
              : 'warning',
        ),
      );
    });

    anomalies.sort((a, b) => b.excess.compareTo(a.excess));
    return anomalies.take(_maxResults).toList(growable: false);
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

  static double _round(double value) => (value * 100).roundToDouble() / 100;
}

class _MonthTotals {
  const _MonthTotals(this.amounts, this.titles);

  final Map<String, double> amounts;
  final Map<String, String> titles;

  double get total => amounts.values.fold(0, (sum, amount) => sum + amount);
}
