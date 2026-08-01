import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../providers/daily_goal_provider.dart';
import '../utils/constants.dart';
import '../utils/design.dart';
import '../utils/validation.dart';
import 'money_text.dart';

/// What happened on one day, and the limit set for it.
///
/// Opened from the calendar. Keeps the day's transactions and its goal in one
/// place, so setting a limit does not mean leaving the screen to find out what
/// was already spent.
class DayDetailSheet extends ConsumerStatefulWidget {
  const DayDetailSheet({
    super.key,
    required this.day,
    required this.expenses,
    required this.currency,
  });

  final DateTime day;

  /// Expenses for [day] only; the caller filters.
  final List<Expense> expenses;
  final String currency;

  @override
  ConsumerState<DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends ConsumerState<DayDetailSheet> {
  Future<void> _editGoal(double? current) async {
    final controller = TextEditingController(
      text: current == null ? '' : current.toStringAsFixed(0),
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<double?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Goal for ${DateFormat('d MMM').format(widget.day)}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Daily limit',
              prefixText: '${widget.currency} ',
            ),
            validator: (value) => parsePositiveAmount(value ?? '') == null
                ? 'Enter an amount above zero'
                : null,
          ),
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 0.0),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(
                dialogContext,
                parsePositiveAmount(controller.text),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (saved == null || !mounted) return;
    await ref
        .read(dailyGoalProvider.notifier)
        .setGoal(widget.day, saved);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final goals = ref.watch(dailyGoalProvider);
    final goal = goals[DailyGoalNotifier.keyFor(widget.day)];

    final spent = widget.expenses.fold(0.0, (sum, e) => sum + e.amount);
    final overGoal = goal != null && spent > goal;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              DateFormat('EEEE, d MMMM').format(widget.day),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                MoneyText(
                  spent,
                  currency: widget.currency,
                  size: AppType.title,
                  weight: FontWeight.w700,
                  color: overGoal ? AppColors.error : scheme.onSurface,
                ),
                if (goal != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'of ${widget.currency}${goal.toStringAsFixed(0)}',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ],
            ),
            if (goal != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (spent / goal).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: overGoal ? AppColors.error : AppColors.success,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                overGoal
                    ? '${widget.currency}${(spent - goal).toStringAsFixed(0)} over the goal'
                    : '${widget.currency}${(goal - spent).toStringAsFixed(0)} left',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: overGoal ? AppColors.error : AppColors.success,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _editGoal(goal);
                },
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: Text(goal == null ? 'Set a goal' : 'Edit goal'),
              ),
            ),
            const Divider(height: AppSpacing.xl),
            if (widget.expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'Nothing spent on this day.',
                  style: theme.textTheme.labelMedium,
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.expenses.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final expense = widget.expenses[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        expense.category.icon,
                        color: expense.category.color,
                        size: 20,
                      ),
                      title: Text(
                        expense.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      trailing: MoneyText(
                        expense.amount,
                        currency: widget.currency,
                        decimals: true,
                        size: AppType.body,
                        weight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
