import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/expense.dart';
import '../services/merchant_anomaly_service.dart';
import '../utils/constants.dart';
import '../utils/design.dart';
import '../utils/financial_period.dart';
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
    final scheme = theme.colorScheme;

    final projection = _projectMonthEnd();
    final anomalies = MerchantAnomalyService.detect(
      expenses: allExpenses,
      monthlyBudget: monthlyBudget,
      startingDayOfMonth: startingDayOfMonth,
    );
    final topSpike = anomalies.isEmpty ? null : anomalies.first;

    final rows = <Widget>[
      if (projection != null) _projectionRow(theme, scheme, projection),
      if (topSpike != null) _spikeRow(theme, topSpike),
      if (pendingCount > 0) _pendingRow(theme, scheme),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    size: 18,
                    color: scheme.secondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Spending pulse', style: theme.textTheme.titleSmall),
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
      ),
    );
  }

  Widget _projectionRow(
    ThemeData theme,
    ColorScheme scheme,
    _Projection projection,
  ) {
    final overBudget = monthlyBudget > 0 && projection.amount > monthlyBudget;
    final color = overBudget ? AppColors.error : AppColors.success;
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
              if (monthlyBudget > 0 && !overBudget) ...[
                const SizedBox(height: 2),
                Text(
                  'Recommended daily ceiling: $currency${((monthlyBudget - (projection.amount * (DateTime.now().day / 30))) / (30 - DateTime.now().day)).clamp(0, monthlyBudget).toStringAsFixed(0)}/day',
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.success),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _spikeRow(ThemeData theme, MerchantAnomaly spike) {
    final color = spike.severity == 'critical'
        ? AppColors.error
        : AppColors.warning;
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

  Widget _pendingRow(ThemeData theme, ColorScheme scheme) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onReviewPending();
      },
      borderRadius: AppRadius.smAll,
      child: Row(
        children: [
          Icon(Icons.label_outline_rounded, size: 18, color: scheme.secondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$pendingCount transaction${pendingCount == 1 ? '' : 's'} '
              'need${pendingCount == 1 ? 's' : ''} a category',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
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
  @visibleForTesting
  static double? projectMonthEnd({
    required List<Expense> monthlyExpenses,
    required int startingDayOfMonth,
    DateTime? now,
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
    return spent / elapsed * period.totalDays;
  }

  _Projection? _projectMonthEnd() {
    final amount = projectMonthEnd(
      monthlyExpenses: monthlyExpenses,
      startingDayOfMonth: startingDayOfMonth,
    );
    return amount == null ? null : _Projection(amount);
  }
}

class _Projection {
  const _Projection(this.amount);
  final double amount;
}
