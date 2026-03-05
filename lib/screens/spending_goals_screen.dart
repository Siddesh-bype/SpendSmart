import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/spending_goal_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/category.dart';
import '../utils/constants.dart';
import '../utils/date_extension.dart';

class SpendingGoalsScreen extends ConsumerStatefulWidget {
  const SpendingGoalsScreen({super.key});

  @override
  ConsumerState<SpendingGoalsScreen> createState() => _SpendingGoalsScreenState();
}

class _SpendingGoalsScreenState extends ConsumerState<SpendingGoalsScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(spendingGoalProvider);
    final settings = ref.watch(appSettingsProvider);
    final expenses = ref.watch(expenseProvider).where((e) => !e.isUncategorized).toList();
    final now = DateTime.now();
    final monthlyExpenses = expenses.where(
      (e) => e.date.isTargetCustomMonth(now.month, now.year, settings.startingDayOfMonth),
    ).toList();
    final totalSpent = monthlyExpenses.fold(0.0, (a, b) => a + b.amount);

    // Category sub-goals
    final catSums = <Category, double>{};
    for (final e in monthlyExpenses) {
      catSums[e.category] = (catSums[e.category] ?? 0) + e.amount;
    }

    final pct = goal.enabled && goal.monthlyLimit > 0
        ? (totalSpent / goal.monthlyLimit).clamp(0.0, 1.0)
        : 0.0;
    final isOver = goal.enabled && totalSpent > goal.monthlyLimit && goal.monthlyLimit > 0;
    final remaining = goal.enabled ? (goal.monthlyLimit - totalSpent) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Goals', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (goal.enabled)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showSetGoalDialog(context, goal.monthlyLimit),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Main goal card
          if (!goal.enabled)
            _buildSetGoalCard(context, settings.currency)
          else ...[
            _buildGoalCard(totalSpent, goal.monthlyLimit, remaining, pct, isOver, settings.currency),
            const SizedBox(height: 20),
          ],

          // Daily budget hint
          if (goal.enabled && !isOver && goal.monthlyLimit > 0) ...[
            _buildHintCard(context, remaining, now, settings.currency),
            const SizedBox(height: 20),
          ],

          // Category breakdown vs goal
          if (catSums.isNotEmpty) ...[
            const Text('Spending by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...catSums.entries.map((e) => _buildCategoryRow(e.key, e.value, goal.monthlyLimit, settings.currency)),
          ],

          if (goal.enabled) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: Icon(Icons.cancel_outlined, color: Colors.red),
              label: const Text('Disable Goal', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(spendingGoalProvider.notifier).disableGoal();
              },
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildSetGoalCard(BuildContext context, String currency) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        const Icon(Icons.track_changes_rounded, size: 56, color: Colors.white),
        const SizedBox(height: 12),
        const Text('Set a Monthly Goal', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Track your overall spending against a budget goal', style: TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          onPressed: () => _showSetGoalDialog(context, 0),
          child: const Text('Set Goal', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _buildGoalCard(double spent, double limit, double remaining, double pct, bool isOver, String currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOver
              ? [Colors.red.shade600, Colors.red.shade400]
              : [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOver ? Colors.red : AppColors.primary).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Monthly Goal', style: TextStyle(color: Colors.white70, fontSize: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
            child: Text(
              isOver ? '🚨 Over Goal' : '${(pct * 100).toStringAsFixed(0)}% used',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$currency${NumberFormat('#,##0').format(spent)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 8),
            child: Text('of $currency${NumberFormat('#,##0').format(limit)}',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white24,
            color: isOver ? Colors.orange.shade300 : Colors.white,
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isOver
              ? '$currency${NumberFormat('#,##0').format(spent - limit)} over your goal'
              : '$currency${NumberFormat('#,##0').format(remaining)} remaining',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ]),
    );
  }

  Widget _buildHintCard(BuildContext context, double remaining, DateTime now, String currency) {
    final daysLeft = DateUtils.getDaysInMonth(now.year, now.month) - now.day + 1;
    final dailyBudget = daysLeft > 0 ? remaining / daysLeft : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Daily Budget', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          Text(
            '$currency${NumberFormat('#,##0').format(dailyBudget)}/day for the next $daysLeft days',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ])),
      ]),
    );
  }

  Widget _buildCategoryRow(Category cat, double spent, double goalLimit, String currency) {
    final portion = goalLimit > 0 ? (spent / goalLimit).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(cat.icon, color: cat.color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text('$currency${NumberFormat('#,##0').format(spent)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: portion,
              backgroundColor: Colors.grey.shade200,
              color: cat.color,
              minHeight: 6,
            ),
          ),
        ])),
      ]),
    );
  }

  void _showSetGoalDialog(BuildContext context, double current) {
    _ctrl.text = current > 0 ? current.toStringAsFixed(0) : '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set Monthly Spending Goal'),
        content: TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Monthly limit',
            prefixText: '₹ ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              final val = double.tryParse(_ctrl.text) ?? 0;
              if (val > 0) {
                HapticFeedback.mediumImpact();
                ref.read(spendingGoalProvider.notifier).setGoal(val);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
