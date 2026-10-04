import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../services/category_classifier.dart';
import '../services/fixed_obligation_service.dart';
import '../services/merchant_anomaly_service.dart';
import '../utils/design.dart';
import '../utils/financial_period.dart';
import '../utils/theme.dart';
import 'glass_container.dart';
import 'money_text.dart';

/// Compact insight card for the home screen.
///
/// Every signal here is computed on-device, so it costs nothing, works in
/// airplane mode, and needs no consent prompt.
///
/// Renders nothing when there is nothing worth saying.
class SpendingPulseCard extends StatelessWidget {
  const SpendingPulseCard({
    super.key,
    required this.monthlyExpenses,
    required this.allExpenses,
    required this.currency,
    required this.monthlyBudget,
    required this.startingDayOfMonth,
    required this.pendingCount,
    required this.onReviewPending,
  });

  final List<Expense> monthlyExpenses;
  final List<Expense> allExpenses;
  final String currency;
  final double monthlyBudget;
  final int startingDayOfMonth;
  final int pendingCount;
  final VoidCallback onReviewPending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = SchemeTheme.of(context);

    final projection = _projectMonthEnd();
    final anomalies = MerchantAnomalyService.detect(
      expenses: allExpenses,
      monthlyBudget: monthlyBudget,
      startingDayOfMonth: startingDayOfMonth,
    );
    final topSpike = anomalies.isEmpty ? null : anomalies.first;

    // One warning family: the >80%-of-budget alert lives here, not as its own
    // banner elsewhere on the page.
    final totalSpent = monthlyExpenses.fold(0.0, (s, e) => s + e.amount);
    final showBudgetAlert =
        monthlyBudget > 0 && totalSpent > monthlyBudget * 0.8;

    final rows = <Widget>[
      if (projection != null) _projectionRow(context, projection),
      if (topSpike != null) _spikeRow(context, topSpike),
      if (pendingCount > 0) _pendingRow(context),
      if (showBudgetAlert) _budgetAlertRow(context, totalSpent),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: GlassContainer(
        borderRadius: AppRadius.glass,
        backgroundColor: scheme.surface,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Spending pulse',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _projectionRow(BuildContext context, _Projection projection) {
    final theme = Theme.of(context);
    final scheme = SchemeTheme.of(context);
    final overBudget = monthlyBudget > 0 && projection.amount > monthlyBudget;
    final color = overBudget ? scheme.error : scheme.success;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.trending_up_rounded, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'On track for ',
                    style: theme.textTheme.bodyMedium,
                  ),
                  MoneyText(
                    projection.amount,
                    currency: currency,
                    size: AppType.body,
                    weight: FontWeight.w700,
                    color: color,
                  ),
                ],
              ),
              Text(
                overBudget
                    ? 'by month end — above your budget'
                    : 'by month end at this pace',
                style: theme.textTheme.labelMedium,
              ),
              if (projection.isEarlyEstimate) ...[
                const SizedBox(height: 2),
                Text(
                  'Early estimate — based on limited history',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.muted,
                  ),
                ),
              ],
              if (monthlyBudget > 0 && !overBudget) ...[
                const SizedBox(height: 2),
                Text(
                  'Recommended daily ceiling: $currency${((monthlyBudget - (projection.amount * (DateTime.now().day / 30))) / (30 - DateTime.now().day)).clamp(0, monthlyBudget).toStringAsFixed(0)}/day',
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.success),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _spikeRow(BuildContext context, MerchantAnomaly spike) {
    final theme = Theme.of(context);
    final scheme = SchemeTheme.of(context);
    final color = spike.severity == 'critical'
        ? scheme.error
        : scheme.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                spike.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                'Running ahead of its usual pace this month',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pendingRow(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = SchemeTheme.of(context);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onReviewPending();
      },
      borderRadius: AppRadius.smAll,
      child: Row(
        children: [
          Icon(Icons.label_outline_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$pendingCount transaction${pendingCount == 1 ? '' : 's'} '
              'need${pendingCount == 1 ? 's' : ''} a category',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: scheme.muted),
        ],
      ),
    );
  }

  /// The merged >80%-of-budget alert (same warning family as the spike row).
  Widget _budgetAlertRow(BuildContext context, double totalSpent) {
    final theme = Theme.of(context);
    final scheme = SchemeTheme.of(context);
    final isOver = totalSpent >= monthlyBudget;
    final pct = (totalSpent / monthlyBudget * 100).toStringAsFixed(0);
    final color = isOver ? scheme.error : scheme.warning;
    final message = isOver
        ? '$currency${NumberFormat('#,##0').format(totalSpent - monthlyBudget)} over your monthly budget'
        : 'You\'ve used $pct% of your monthly budget';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isOver ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOver ? 'Over budget' : 'Approaching budget limit',
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
              Text(message, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
      ],
    );
  }

  /// Rule-based projection of month-end spend.
  ///
  /// Pro-rates spend so far across the whole period: `spent / elapsedDays *
  /// totalDays`. Needs 3 days of data before it says anything -- one big
  /// Monday would otherwise project an alarming month.
  ///
  /// Future-dated expenses are excluded: a planned entry is not yet spent, and
  /// counting it against a small elapsed day count would over-inflate the
  /// projection. Both the elapsed and total day counts come from the period,
  /// so a custom cycle projects against its own length rather than a
  /// calendar-month denominator.
  ///
  /// When [allExpenses] carries history, fixed commitments are taken 1:1 for
  /// the month and only the variable remainder is paced:
  /// `fixedTotal + variableSpentSoFar / elapsed * totalDays`. Without history
  /// there is nothing to split on, so this is exactly the old pace formula.
  @visibleForTesting
  static double? projectMonthEnd({
    required List<Expense> monthlyExpenses,
    required int startingDayOfMonth,
    DateTime? now,
    List<Expense>? allExpenses,
  }) {
    return projectMonthEndDetailed(
      monthlyExpenses: monthlyExpenses,
      startingDayOfMonth: startingDayOfMonth,
      now: now,
      allExpenses: allExpenses,
    )?.amount;
  }

  /// Rich projection behind [projectMonthEnd].
  ///
  /// [fixedTotal] is the sum of detected fixed-commitment expectations for
  /// the current period; [isEarlyEstimate] is true when fewer than 2 history
  /// months carry data, so the UI can mark the number as provisional.
  /// Follow-up (out of scope here): per-category baselines for the variable
  /// leg instead of one global burn rate.
  @visibleForTesting
  static MonthEndProjection? projectMonthEndDetailed({
    required List<Expense> monthlyExpenses,
    required int startingDayOfMonth,
    DateTime? now,
    List<Expense>? allExpenses,
  }) {
    if (monthlyExpenses.isEmpty) return null;
    final date = now ?? DateTime.now();
    final period = FinancialPeriod.containing(date, startingDayOfMonth);
    final elapsed = period.daysElapsed(date);
    if (elapsed < 3) return null;

    var spent = 0.0;
    for (final e in monthlyExpenses) {
      if (e.date.isAfter(date)) continue;
      spent += e.amount;
    }
    if (spent <= 0) return null;

    final all = allExpenses ?? monthlyExpenses;
    final fixed = FixedObligationService.detect(
      expenses: all,
      startingDayOfMonth: startingDayOfMonth,
      now: date,
    );
    final fixedTotal = fixed.fold(0.0, (sum, f) => sum + f.expectedAmount);

    var fixedPaidSoFar = 0.0;
    if (fixed.isNotEmpty) {
      final fixedKeys = {for (final f in fixed) f.merchantKey};
      for (final e in monthlyExpenses) {
        if (e.date.isAfter(date)) continue;
        if (fixedKeys.contains(CategoryClassifier.normalizeMerchant(e.title))) {
          fixedPaidSoFar += e.amount;
        }
      }
      fixedPaidSoFar = fixedPaidSoFar.clamp(0, spent).toDouble();
    }

    final variableSpent = spent - fixedPaidSoFar;
    final forecast = fixedTotal + variableSpent / elapsed * period.totalDays;

    var monthsWithData = 0;
    for (var index = 1; index <= 3; index++) {
      final historyPeriod = period.shifted(-index);
      if (all.any(
        (e) => e.amount > 0 && historyPeriod.contains(e.date),
      )) {
        monthsWithData++;
      }
    }

    return MonthEndProjection(
      amount: forecast,
      fixedTotal: fixedTotal,
      isEarlyEstimate: monthsWithData < 2,
    );
  }

  _Projection? _projectMonthEnd() {
    final projection = projectMonthEndDetailed(
      monthlyExpenses: monthlyExpenses,
      startingDayOfMonth: startingDayOfMonth,
      allExpenses: allExpenses,
    );
    return projection == null
        ? null
        : _Projection(
            projection.amount,
            isEarlyEstimate: projection.isEarlyEstimate,
          );
  }
}

/// Month-end forecast with its fixed leg and confidence.
///
/// [isEarlyEstimate] is data only: fewer than 2 history months, so the
/// number is provisional. The projection row renders it as a muted
/// "Early estimate" note under the figure.
class MonthEndProjection {
  const MonthEndProjection({
    required this.amount,
    required this.fixedTotal,
    required this.isEarlyEstimate,
  });

  final double amount;
  final double fixedTotal;
  final bool isEarlyEstimate;
}

class _Projection {
  const _Projection(this.amount, {this.isEarlyEstimate = false});
  final double amount;
  final bool isEarlyEstimate;
}
