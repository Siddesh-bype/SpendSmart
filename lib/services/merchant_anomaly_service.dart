import 'dart:math';

import '../models/expense.dart';
import '../utils/date_extension.dart';
import 'category_classifier.dart';

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
/// Same math as the Worker's `calculateAnomalies` (see
/// `cloudflare/ai-analysis-worker/src/index.ts`) one level finer: merchants
/// instead of categories, so it needs no network call. Pure Dart: no Hive, no
/// Riverpod, no widgets.
class MerchantAnomalyService {
  static const _historyMonths = 3;
  static const _spikeRatio = 1.5;
  static const _criticalRatio = 2.0;
  static const _budgetImpactShare = 0.05;
  static const _maxResults = 5;

  /// Impact floor when no budget is set. The Worker's `max(1, ...)` would flag
  /// rupee-level noise here, because a merchant baseline is far smaller than a
  /// category one.
  static const _noBudgetMinimumImpact = 500.0;

  static List<MerchantAnomaly> detect({
    required Iterable<Expense> expenses,
    required double monthlyBudget,
    required int startingDayOfMonth,
    DateTime? now,
  }) {
    final date = now ?? DateTime.now();
    final periodStart = _periodStart(date, startingDayOfMonth);
    final periodEnd = DateTime(
      periodStart.year,
      periodStart.month + 1,
      startingDayOfMonth,
    ).subtract(const Duration(days: 1));
    final today = DateTime(date.year, date.month, date.day);
    final totalDays = periodEnd.difference(periodStart).inDays + 1;
    final daysElapsed = today.difference(periodStart).inDays + 1;
    if (totalDays <= 0 || daysElapsed <= 0) return const [];

    final current = _monthTotals(expenses, periodStart, startingDayOfMonth);
    if (current.amounts.isEmpty) return const [];

    final history = List.generate(
      _historyMonths,
      (index) => _monthTotals(
        expenses,
        DateTime(periodStart.year, periodStart.month - index - 1),
        startingDayOfMonth,
      ),
    );
    if (history.any((month) => month.total <= 0)) return const [];

    final minimumImpact = monthlyBudget > 0
        ? max(1.0, monthlyBudget * _budgetImpactShare)
        : _noBudgetMinimumImpact;

    final anomalies = <MerchantAnomaly>[];
    current.amounts.forEach((key, currentAmount) {
      final baseline =
          history.fold<double>(
            0,
            (total, month) => total + (month.amounts[key] ?? 0),
          ) /
          _historyMonths;
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

  static DateTime _periodStart(DateTime date, int startingDayOfMonth) {
    return date.day >= startingDayOfMonth
        ? DateTime(date.year, date.month, startingDayOfMonth)
        : DateTime(date.year, date.month - 1, startingDayOfMonth);
  }

  /// Merchant totals for one custom month, excluding uncategorized expenses the
  /// way `AiSpendingAnalysisService._monthSummary` does.
  static _MonthTotals _monthTotals(
    Iterable<Expense> expenses,
    DateTime month,
    int startingDayOfMonth,
  ) {
    final amounts = <String, double>{};
    final titles = <String, String>{};
    final titleDates = <String, DateTime>{};
    for (final expense in expenses) {
      if (expense.isUncategorized ||
          !expense.amount.isFinite ||
          expense.amount <= 0 ||
          !expense.date.isTargetCustomMonth(
            month.month,
            month.year,
            startingDayOfMonth,
          )) {
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
