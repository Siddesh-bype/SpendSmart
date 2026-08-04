import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../widgets/money_text.dart';
import '../utils/constants.dart';
import '../utils/design.dart';
import '../utils/financial_period.dart';
import '../utils/validation.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetProvider);
    final expenses = ref
        .watch(expenseProvider)
        .where((e) => !e.isUncategorized)
        .toList();
    final settings = ref.watch(appSettingsProvider);
    final period = FinancialPeriod.containing(
      DateTime.now(),
      settings.startingDayOfMonth,
    );
    final monthlyExpenses = expenses
        .where((e) => period.contains(e.date))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Budget'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddBudget(context, ref),
            tooltip: 'Add Budget',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(
            budgets,
            monthlyExpenses,
            settings.currency,
            settings.monthlyBudget,
          ),
          Expanded(
            child: Category.values.isEmpty
                ? Center(
                    child: Text(
                      'No categories',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: Category.values.map((cat) {
                      final budget = budgets.firstWhere(
                        (b) => b.category == cat,
                        orElse: () => Budget(category: cat, monthlyLimit: 0),
                      );
                      final spent = monthlyExpenses
                          .where((e) => e.category == cat)
                          .fold(0.0, (a, b) => a + b.amount);
                      return _buildBudgetCard(
                        context,
                        ref,
                        cat,
                        budget,
                        spent,
                        settings.currency,
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    List<Budget> budgets,
    List expenses,
    String currency,
    double globalMonthlyBudget,
  ) {
    final categoryTotal = budgets.fold(0.0, (a, b) => a + b.monthlyLimit);
    // Prefer the global monthly budget (set in Settings); fall back to the
    // sum of per-category limits if no global budget is configured.
    final totalBudget = globalMonthlyBudget > 0
        ? globalMonthlyBudget
        : categoryTotal;
    final totalSpent = expenses.fold(0.0, (a, b) => a + b.amount);
    final pct = totalBudget > 0
        ? (totalSpent / totalBudget).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // White-on-gradient is intentional; these do not follow the scheme.
          const Text(
            'Overall Budget',
            style: TextStyle(color: Colors.white70, fontSize: AppType.label),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: MoneyText(
                  totalSpent,
                  currency: currency,
                  autoShrink: true,
                  size: AppType.title,
                  weight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'of ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: AppType.body,
                    ),
                  ),
                  MoneyText(
                    totalBudget,
                    currency: currency,
                    size: AppType.body,
                    color: Colors.white70,
                  ),
                ],
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
                backgroundColor: Colors.white24,
                color: Colors.white,
                minHeight: AppSpacing.sm,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${(pct * 100).toStringAsFixed(0)}% used',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: AppType.caption,
              fontFeatures: AppType.tabular,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(
    BuildContext context,
    WidgetRef ref,
    Category cat,
    Budget budget,
    double spent,
    String currency,
  ) {
    final hasLimit = budget.monthlyLimit > 0;
    final pct = hasLimit ? (spent / budget.monthlyLimit).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = hasLimit && spent > budget.monthlyLimit;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(cat.icon, color: cat.color, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isOverBudget)
                              Text(
                                'Over budget!',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () =>
                      _showAddBudget(context, ref, existing: budget),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Spent: ',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isOverBudget ? AppColors.error : null,
                      ),
                    ),
                    MoneyText(
                      spent,
                      currency: currency,
                      size: AppType.body,
                      weight: FontWeight.w600,
                      color: isOverBudget ? AppColors.error : scheme.onSurface,
                    ),
                  ],
                ),
                if (hasLimit)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Limit: ', style: theme.textTheme.bodySmall),
                      MoneyText(
                        budget.monthlyLimit,
                        currency: currency,
                        size: AppType.label,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  )
                else
                  Text('No limit set', style: theme.textTheme.bodySmall),
              ],
            ),
            if (hasLimit) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: AppRadius.smAll,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) => LinearProgressIndicator(
                    value: val,
                    backgroundColor: scheme.outlineVariant,
                    color: isOverBudget
                        ? AppColors.error
                        : (pct > 0.8 ? AppColors.warning : cat.color),
                    minHeight: AppSpacing.sm,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddBudget(BuildContext context, WidgetRef ref, {Budget? existing}) {
    final catController = ValueNotifier<Category>(
      existing?.category ?? Category.food,
    );
    final amountController = TextEditingController(
      text: existing?.monthlyLimit.toStringAsFixed(0) ?? '',
    );
    final currency = ref.read(appSettingsProvider).currency;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
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
              existing != null ? 'Edit Budget' : 'Set Budget',
              style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ValueListenableBuilder<Category>(
              valueListenable: catController,
              builder: (ctx, cat, child) => DropdownButtonFormField<Category>(
                initialValue: cat,
                decoration: const InputDecoration(labelText: 'Category'),
                items: Category.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(c.icon, color: c.color, size: 18),
                            const SizedBox(width: AppSpacing.sm),
                            Text(c.name),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => catController.value = v!,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monthly Limit ($currency)',
                prefixText: '$currency ',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final amount = parsePositiveAmount(amountController.text);
                if (amount != null) {
                  await ref
                      .read(budgetProvider.notifier)
                      .setBudget(
                        Budget(
                          category: catController.value,
                          monthlyLimit: amount,
                        ),
                      );
                  if (context.mounted) Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid monthly limit'),
                    ),
                  );
                }
              },
              child: const Text(
                'Save Budget',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    ).whenComplete(() {
      amountController.dispose();
      catController.dispose();
    });
  }
}
