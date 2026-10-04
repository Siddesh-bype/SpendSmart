import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../widgets/money_text.dart';
import '../utils/design.dart';
import '../utils/theme.dart';
import '../utils/financial_period.dart';
import '../utils/validation.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  /// Collapsed by default: only categories with a limit or spend are shown.
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
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
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Tooltip(
              message: 'Add Budget',
              child: Material(
                color: SchemeTheme.of(context).ctaFill,
                borderRadius: AppRadius.mdAll,
                child: InkWell(
                  borderRadius: AppRadius.mdAll,
                  onTap: () => _showAddBudget(context, ref),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: SchemeTheme.of(context).ctaText,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: SchemeTheme.of(context).ctaText,
                            fontSize: AppType.body,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(
            context,
            budgets,
            monthlyExpenses,
            settings.currency,
            settings.monthlyBudget,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: () {
                final withActivity = <Category>[];
                final rest = <Category>[];
                for (final cat in Category.values) {
                  final limit = budgets
                      .firstWhere(
                        (b) => b.category == cat,
                        orElse: () => Budget(category: cat, monthlyLimit: 0),
                      )
                      .monthlyLimit;
                  final spent = monthlyExpenses
                      .where((e) => e.category == cat)
                      .fold(0.0, (a, b) => a + b.amount);
                  (spent > 0 || limit > 0 ? withActivity : rest).add(cat);
                }
                Widget cardFor(Category cat) {
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
                }

                final children = <Widget>[
                  for (final cat in withActivity) cardFor(cat),
                ];
                if (rest.isNotEmpty) {
                  children.add(
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: InkWell(
                        borderRadius: AppRadius.smAll,
                        onTap: () => setState(() => _showAll = !_showAll),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  _showAll
                                      ? 'Show fewer categories'
                                      : 'Set limits for ${rest.length} more categories',
                                  style: TextStyle(
                                    color: SchemeTheme.of(context).primary,
                                    fontSize: AppType.body,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Icon(
                                _showAll
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: SchemeTheme.of(context).primary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                  if (_showAll) {
                    children.addAll(rest.map(cardFor));
                  }
                }
                return children;
              }(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
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
    final scheme = SchemeTheme.of(context);
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Budget',
            style: TextStyle(color: scheme.muted, fontSize: AppType.label),
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
                  color: scheme.ink,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'of ',
                    style: TextStyle(
                      color: scheme.muted,
                      fontSize: AppType.body,
                    ),
                  ),
                  MoneyText(
                    totalBudget,
                    currency: currency,
                    size: AppType.body,
                    color: scheme.muted,
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
                backgroundColor: scheme.tint,
                color: val > 0.85 ? scheme.error : scheme.primary,
                minHeight: AppSpacing.sm,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${(pct * 100).toStringAsFixed(0)}% used',
            style: TextStyle(
              color: scheme.muted,
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
    final scheme = SchemeTheme.of(context);
    final catColor = scheme.categoryColors[cat.index];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.border),
      ),
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
                          color: catColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(cat.icon, color: catColor, size: 20),
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 14,
                                    color: scheme.error,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Over budget!',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: scheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit ${cat.displayName} budget',
                  constraints: const BoxConstraints.tightFor(width: 44, height: 44),
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
                        color: isOverBudget ? scheme.error : null,
                      ),
                    ),
                    MoneyText(
                      spent,
                      currency: currency,
                      size: AppType.body,
                      weight: FontWeight.w600,
                      color: isOverBudget ? scheme.error : scheme.ink,
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
                        color: scheme.muted,
                      ),
                    ],
                  )
                else
                  Text('No limit set', style: theme.textTheme.bodySmall),
              ],
            ),
            if (hasLimit) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MoneyText(
                    (budget.monthlyLimit - spent).abs(),
                    currency: currency,
                    size: AppType.caption,
                    color: scheme.muted,
                  ),
                  Text(
                    spent > budget.monthlyLimit ? ' over' : ' left',
                    style: TextStyle(
                      color: scheme.muted,
                      fontSize: AppType.caption,
                      fontFeatures: AppType.tabular,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: AppRadius.smAll,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) => LinearProgressIndicator(
                    value: val,
                    backgroundColor: scheme.tint,
                    color: isOverBudget
                        ? scheme.error
                        : (pct > 0.8 ? scheme.warning : catColor),
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
    final amountError = ValueNotifier<String?>(null);
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
                            Icon(
                              c.icon,
                              color: SchemeTheme.of(
                                ctx,
                              ).categoryColors[c.index],
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(c.displayName),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => catController.value = v!,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ValueListenableBuilder<String?>(
              valueListenable: amountError,
              builder: (ctx, error, _) => TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  if (v.trim().isEmpty) {
                    amountError.value = null;
                  } else {
                    amountError.value =
                        parsePositiveAmount(v) == null
                            ? 'Enter a valid monthly limit'
                            : null;
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Monthly Limit ($currency)',
                  prefixText: '$currency ',
                  errorText: error,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: SchemeTheme.of(sheetContext).ctaFill,
                foregroundColor: SchemeTheme.of(sheetContext).ctaText,
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
                  amountError.value = 'Enter a valid monthly limit';
                  // Snackbar kept as backup; the inline error is the
                  // primary signal.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid monthly limit'),
                    ),
                  );
                }
              },
              child: Text(
                'Save Budget',
                style: TextStyle(
                  color: SchemeTheme.of(sheetContext).ctaText,
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
      amountError.dispose();
    });
  }
}
