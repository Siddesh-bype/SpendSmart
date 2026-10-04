import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/spending_goal_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/category.dart';
import '../utils/design.dart';
import '../utils/theme.dart';
import '../utils/financial_period.dart';
import '../utils/validation.dart';

class SpendingGoalsScreen extends ConsumerStatefulWidget {
  const SpendingGoalsScreen({super.key});

  @override
  ConsumerState<SpendingGoalsScreen> createState() =>
      _SpendingGoalsScreenState();
}

class _SpendingGoalsScreenState extends ConsumerState<SpendingGoalsScreen> {
  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(spendingGoalProvider);
    final settings = ref.watch(appSettingsProvider);
    final expenses = ref
        .watch(expenseProvider)
        .where((e) => !e.isUncategorized)
        .toList();
    final now = DateTime.now();
    final period = FinancialPeriod.containing(now, settings.startingDayOfMonth);
    final monthlyExpenses = expenses
        .where((e) => period.contains(e.date))
        .toList();
    final totalSpent = monthlyExpenses.fold(0.0, (a, b) => a + b.amount);

    // Category sub-goals
    final catSums = <Category, double>{};
    for (final e in monthlyExpenses) {
      catSums[e.category] = (catSums[e.category] ?? 0) + e.amount;
    }

    final pct = goal.enabled && goal.monthlyLimit > 0
        ? (totalSpent / goal.monthlyLimit).clamp(0.0, 1.0)
        : 0.0;
    final isOver =
        goal.enabled && totalSpent > goal.monthlyLimit && goal.monthlyLimit > 0;
    final remaining = goal.enabled ? (goal.monthlyLimit - totalSpent) : 0.0;
    final scheme = SchemeTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Spending Goals',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (goal.enabled)
            IconButton(
              tooltip: 'Edit monthly goal',
              constraints:
                  const BoxConstraints.tightFor(width: 44, height: 44),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showGoalSheet(goal.monthlyLimit),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main goal card
            if (!goal.enabled)
              _buildSetGoalCard(context)
            else ...[
              _buildGoalCard(
                context,
                totalSpent,
                goal.monthlyLimit,
                remaining,
                pct,
                isOver,
                settings.currency,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // Daily budget hint
            if (goal.enabled && !isOver && goal.monthlyLimit > 0) ...[
              _buildHintCard(context, remaining, now, settings.currency),
              const SizedBox(height: AppSpacing.xl),
            ],

            // Category breakdown vs goal
            if (catSums.isNotEmpty) ...[
              const Text(
                'Spending by Category',
                style: TextStyle(fontSize: AppType.headline, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.md),
              ...catSums.entries.map(
                (e) => _buildCategoryRow(
                  context,
                  e.key,
                  e.value,
                  goal.monthlyLimit,
                  settings.currency,
                ),
              ),
            ],

            if (goal.enabled) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: Icon(
                    Icons.cancel_outlined,
                    color: scheme.error,
                  ),
                  label: Text(
                    'Disable Goal',
                    style: TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: scheme.error.withValues(alpha: 0.5),
                    ),
                    backgroundColor:
                        scheme.error.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(spendingGoalProvider.notifier).disableGoal();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSetGoalCard(BuildContext context) {
    final scheme = SchemeTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.track_changes_rounded,
              size: 40,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Set a Monthly Goal',
            style: TextStyle(
              fontSize: AppType.title,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Track your overall spending against a monthly budget goal',
            style: TextStyle(
              color: scheme.muted,
              fontSize: AppType.label,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.ctaFill,
                foregroundColor: scheme.ctaText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: () => _showGoalSheet(0),
              child: Text(
                'Set Monthly Goal',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scheme.ctaText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(
    BuildContext context,
    double spent,
    double limit,
    double remaining,
    double pct,
    bool isOver,
    String currency,
  ) {
    final scheme = SchemeTheme.of(context);
    final statusColor = isOver ? scheme.error : scheme.primary;
    final money = NumberFormat('#,##0');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Goal',
                style: TextStyle(
                  color: scheme.muted,
                  fontSize: AppType.label,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOver)
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 12,
                        color: statusColor,
                      ),
                    if (isOver) const SizedBox(width: 4),
                    Text(
                      isOver
                          ? 'Over goal'
                          : '${(pct * 100).toStringAsFixed(0)}% used',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: AppType.caption,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  '$currency${money.format(spent)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.ink,
                    fontSize: AppType.display,
                    fontWeight: FontWeight.bold,
                    fontFeatures: AppType.tabular,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 8),
                child: Text(
                  'of $currency${money.format(limit)}',
                  style: TextStyle(
                    color: scheme.muted,
                    fontSize: AppType.body,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadius.smAll,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: pct),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, val, _) => LinearProgressIndicator(
                value: val,
                backgroundColor: scheme.tint,
                color: isOver ? scheme.error : scheme.primary,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (isOver)
                Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: scheme.error,
                ),
              if (isOver) const SizedBox(width: 4),
              Expanded(
                child: Text(
                  isOver
                      ? '$currency${money.format(spent - limit)} over your goal'
                      : '$currency${money.format(remaining)} remaining',
                  style: TextStyle(
                    color: isOver ? scheme.error : scheme.muted,
                    fontSize: AppType.caption,
                    fontFeatures: AppType.tabular,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHintCard(
    BuildContext context,
    double remaining,
    DateTime now,
    String currency,
  ) {
    final scheme = SchemeTheme.of(context);
    final daysLeft =
        DateUtils.getDaysInMonth(now.year, now.month) - now.day + 1;
    final dailyBudget = daysLeft > 0 ? remaining / daysLeft : 0.0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: scheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Budget',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.ink,
                  ),
                ),
                Text(
                  '$currency${NumberFormat('#,##0').format(dailyBudget)}/day for the next $daysLeft days',
                  style: TextStyle(
                    fontSize: AppType.caption,
                    color: scheme.muted,
                    fontFeatures: AppType.tabular,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(
    BuildContext context,
    Category cat,
    double spent,
    double goalLimit,
    String currency,
  ) {
    final scheme = SchemeTheme.of(context);
    final catColor = scheme.categoryColors[cat.index];
    final portion = goalLimit > 0 ? (spent / goalLimit).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(cat.icon, color: catColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        cat.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: AppType.label,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '$currency${NumberFormat('#,##0').format(spent)}',
                      style: TextStyle(
                        fontSize: AppType.caption,
                        fontWeight: FontWeight.w600,
                        fontFeatures: AppType.tabular,
                        color: scheme.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: portion),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, _) => LinearProgressIndicator(
                      value: val,
                      backgroundColor: scheme.tint,
                      color: catColor,
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGoalSheet(double current) {
    final ctrl = TextEditingController(
      text: current > 0 ? current.toStringAsFixed(0) : '',
    );
    final amountError = ValueNotifier<String?>(null);
    final currency = ref.read(appSettingsProvider).currency;
    final isEdit = current > 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final scheme = SchemeTheme.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Edit Monthly Goal' : 'Set Monthly Goal',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ValueListenableBuilder<String?>(
                valueListenable: amountError,
                builder: (ctx, error, _) => TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    if (v.trim().isEmpty) {
                      amountError.value = null;
                    } else {
                      amountError.value = parsePositiveAmount(v) == null
                          ? 'Enter a valid monthly limit'
                          : null;
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Monthly limit ($currency)',
                    prefixText: '$currency ',
                    errorText: error,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.ctaFill,
                    foregroundColor: scheme.ctaText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final val = parsePositiveAmount(ctrl.text);
                    if (val != null) {
                      HapticFeedback.mediumImpact();
                      await ref
                          .read(spendingGoalProvider.notifier)
                          .setGoal(val);
                      if (mounted) Navigator.pop(context);
                    } else {
                      amountError.value = 'Enter a valid monthly limit';
                    }
                  },
                  child: Text(
                    'Save Goal',
                    style: TextStyle(
                      color: scheme.ctaText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    ).whenComplete(() {
      ctrl.dispose();
      amountError.dispose();
    });
  }
}
