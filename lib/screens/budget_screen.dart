import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../utils/constants.dart';
import '../utils/date_extension.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetProvider);
    final expenses = ref.watch(expenseProvider).where((e) => !e.isUncategorized).toList();
    final settings = ref.watch(appSettingsProvider);
    final now = DateTime.now();
    final monthlyExpenses = expenses.where((e) => e.date.isTargetCustomMonth(now.month, now.year, settings.startingDayOfMonth)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Budget', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddBudget(context, ref),
            tooltip: 'Add Budget',
          ),
        ],
      ),
      body: Column(children: [
        _buildSummaryCard(budgets, monthlyExpenses, settings.currency, settings.monthlyBudget),
        Expanded(
          child: Category.values.isEmpty
              ? const Center(child: Text('No categories', style: TextStyle(color: Colors.grey)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: Category.values.map((cat) {
                    final budget = budgets.firstWhere((b) => b.category == cat, orElse: () => Budget(category: cat, monthlyLimit: 0));
                    final spent = monthlyExpenses.where((e) => e.category == cat).fold(0.0, (a, b) => a + b.amount);
                    return _buildBudgetCard(context, ref, cat, budget, spent, settings.currency);
                  }).toList(),
                ),
        ),
      ]),
    );
  }

  Widget _buildSummaryCard(List<Budget> budgets, List expenses, String currency, double globalMonthlyBudget) {
    final categoryTotal = budgets.fold(0.0, (a, b) => a + b.monthlyLimit);
    // Prefer the global monthly budget (set in Settings); fall back to the
    // sum of per-category limits if no global budget is configured.
    final totalBudget = globalMonthlyBudget > 0 ? globalMonthlyBudget : categoryTotal;
    final totalSpent = expenses.fold(0.0, (a, b) => a + b.amount);
    final pct = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Overall Budget', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$currency${NumberFormat('#,##0').format(totalSpent)}',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          Text('of $currency${NumberFormat('#,##0').format(totalBudget)}',
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: pct),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, val, _) => LinearProgressIndicator(value: val, backgroundColor: Colors.white24, color: Colors.white, minHeight: 8),
          ),
        ),
        const SizedBox(height: 6),
        Text('${(pct * 100).toStringAsFixed(0)}% used',
          style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }

  Widget _buildBudgetCard(BuildContext context, WidgetRef ref, Category cat, Budget budget, double spent, String currency) {
    final hasLimit = budget.monthlyLimit > 0;
    final pct = hasLimit ? (spent / budget.monthlyLimit).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = hasLimit && spent > budget.monthlyLimit;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(cat.icon, color: cat.color, size: 20)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (isOverBudget)
                  const Text('Over budget!', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ]),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showAddBudget(context, ref, existing: budget),
            ),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Spent: $currency${NumberFormat('#,##0').format(spent)}',
              style: TextStyle(fontWeight: FontWeight.w600, color: isOverBudget ? Colors.red : null)),
            Text(hasLimit ? 'Limit: $currency${NumberFormat('#,##0').format(budget.monthlyLimit)}' : 'No limit set',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ]),
          if (hasLimit) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: pct),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, val, _) => LinearProgressIndicator(
                  value: val,
                  backgroundColor: Colors.grey.shade200,
                  color: isOverBudget ? Colors.red : (pct > 0.8 ? Colors.orange : cat.color),
                  minHeight: 8,
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  void _showAddBudget(BuildContext context, WidgetRef ref, {Budget? existing}) {
    final catController = ValueNotifier<Category>(existing?.category ?? Category.food);
    final amountController = TextEditingController(text: existing?.monthlyLimit.toStringAsFixed(0) ?? '');
    final currency = ref.read(appSettingsProvider).currency;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(existing != null ? 'Edit Budget' : 'Set Budget',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ValueListenableBuilder<Category>(
            valueListenable: catController,
            builder: (ctx, cat, child) => DropdownButtonFormField<Category>(
              initialValue: cat,
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: Category.values.map((c) => DropdownMenuItem(
                value: c,
                child: Row(children: [Icon(c.icon, color: c.color, size: 18), const SizedBox(width: 8), Text(c.name)]),
              )).toList(),
              onChanged: (v) => catController.value = v!,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Monthly Limit ($currency)',
              prefixText: '$currency ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                ref.read(budgetProvider.notifier).setBudget(Budget(
                  category: catController.value,
                  monthlyLimit: amount,
                ));
              }
              Navigator.pop(context);
            },
            child: const Text('Save Budget', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    ).whenComplete(() {
      amountController.dispose();
      catController.dispose();
    });
  }
}
