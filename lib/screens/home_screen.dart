import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/daily_goal_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/income_provider.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../widgets/expense_tile.dart';
import '../widgets/day_detail_sheet.dart';
import '../widgets/edit_expense_sheet.dart';
import '../widgets/money_text.dart';
import '../widgets/spending_calendar.dart';
import '../widgets/spending_pulse_card.dart';
import '../utils/theme.dart';
import '../utils/design.dart';
import '../utils/financial_period.dart';
import 'pending_screen.dart';
import 'transactions_screen.dart';
import 'notifications_screen.dart';
import 'income_screen.dart';
import 'analytics_screen.dart';
import 'add_expense_screen.dart';

import 'recurring_expense_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Collapsed by default: the calendar is ~250px and this screen is already
  /// several viewports long.
  bool _calendarOpen = false;

  /// Null means "no day filter"; tapping the selected day again clears it.
  DateTime? _selectedDay;

  static bool _isSameDay(DateTime a, DateTime? b) =>
      b != null && a.year == b.year && a.month == b.month && a.day == b.day;
  Future<void> _handleDelete(Expense expense) async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(expenseProvider.notifier).deleteExpense(expense.id);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete "${expense.title}".')),
      );
      return;
    }
    if (!mounted) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted "${expense.title}"'),
        duration: const Duration(seconds: 15),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: SchemeTheme.of(context).primary,
          onPressed: () {
            HapticFeedback.lightImpact();
            // A failed restore is the one case that loses user data outright,
            // so it is surfaced rather than swallowed.
            ref
                .read(expenseProvider.notifier)
                .addExpense(expense)
                .catchError(
                  (_) => messenger.showSnackBar(
                    SnackBar(
                      content: Text('Could not restore "${expense.title}".'),
                    ),
                  ),
                );
          },
        ),
      ),
    );
  }

  void _showEditSheet(Expense expense) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EditExpenseSheet(expense: expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expenseProvider);
    final settings = ref.watch(appSettingsProvider);
    final budgets = ref.watch(budgetProvider);
    final notifications = ref.watch(notificationProvider);
    final incomes = ref.watch(incomeProvider);
    final dailyGoals = ref.watch(dailyGoalProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;
    final uncategorized = expenses.where((e) => e.isUncategorized).toList();
    final now = DateTime.now();
    final period = FinancialPeriod.containing(now, settings.startingDayOfMonth);
    final scheme = SchemeTheme.of(context);

    final monthlyExpenses = expenses
        .where((e) => period.contains(e.date) && !e.isUncategorized)
        .toList();
    final totalSpent = monthlyExpenses.fold(0.0, (a, b) => a + b.amount);

    // Income is summed over the same period as spending. Mixing a custom
    // spending window with calendar-month income made the net balance compare
    // two different date ranges.
    final monthlyIncome = incomes
        .where((i) => period.contains(i.date))
        .fold(0.0, (s, i) => s + i.amount);

    // Use income-based net if income is tracked, else fall back to budget-based savings
    final hasIncome = monthlyIncome > 0;
    final netBalance = hasIncome
        ? monthlyIncome - totalSpent
        : settings.monthlyBudget - totalSpent;
    final netLabel = hasIncome ? 'Net Balance' : 'Savings';

    // Daily budget remaining
    final daysLeft = period.daysRemaining(now);
    final dailyLeft = settings.monthlyBudget > 0
        ? ((settings.monthlyBudget - totalSpent) / daysLeft)
        : 0.0;

    // A calendar tap narrows this list to that day; otherwise it's the latest 5.
    final recentExpenses = _selectedDay == null
        ? expenses.where((e) => !e.isUncategorized).take(5).toList()
        : expenses
              .where(
                (e) => !e.isUncategorized && _isSameDay(e.date, _selectedDay),
              )
              .toList();

    // Budget check on expense changes
    ref.listen(expenseProvider, (_, newState) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Read fresh data inside callback to avoid stale closures
        final currentExpenses = ref.read(expenseProvider);
        final currentBudgets = ref.read(budgetProvider);
        final now = DateTime.now();
        final settings = ref.read(appSettingsProvider);
        final currentPeriod = FinancialPeriod.containing(
          now,
          settings.startingDayOfMonth,
        );
        final currentMonthly = currentExpenses
            .where((e) => currentPeriod.contains(e.date) && !e.isUncategorized)
            .toList();
        final Map<Category, double> spending = {};
        for (var e in currentMonthly) {
          spending[e.category] = (spending[e.category] ?? 0) + e.amount;
        }
        ref
            .read(notificationProvider.notifier)
            .checkBudgets(
              currentBudgets,
              spending,
              currency: ref.read(appSettingsProvider).currency,
            );
      });
    });

    return Scaffold(
      backgroundColor: scheme.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 1. Header: month + brand + pending pill + bell (48dp targets)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(now),
                          style: TextStyle(
                            fontSize: AppType.label,
                            color: scheme.muted,
                          ),
                        ),
                        Text(
                          'SpendSmart',
                          style: TextStyle(
                            fontSize: AppType.title,
                            fontWeight: FontWeight.bold,
                            color: scheme.ink,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (uncategorized.isNotEmpty)
                          Semantics(
                            button: true,
                            label: '${uncategorized.length} pending',
                            child: Material(
                              color: scheme.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(24),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PendingScreen(),
                                  ),
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 48,
                                    minWidth: 48,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.warning_amber,
                                          color: scheme.warning,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${uncategorized.length} pending',
                                          style: TextStyle(
                                            fontSize: AppType.caption,
                                            color: scheme.warning,
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
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          label: 'Notifications',
                          child: IconButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            ),
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.notifications_outlined,
                                  color: scheme.ink,
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: -4,
                                    top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: scheme.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        unreadCount > 9
                                            ? '9+'
                                            : '$unreadCount',
                                        style: TextStyle(
                                          color: scheme.ctaText,
                                          fontSize: AppType.micro,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 2. Hero card (solid surface + 1px border)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Spent',
                                  style: TextStyle(
                                    color: scheme.muted,
                                    fontSize: AppType.body,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                MoneyText(
                                  totalSpent,
                                  currency: settings.currency,
                                  size: AppType.display,
                                  weight: FontWeight.bold,
                                  color: scheme.ink,
                                  autoShrink: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  netLabel,
                                  style: TextStyle(
                                    color: scheme.muted,
                                    fontSize: AppType.label,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (netBalance >= 0
                                            ? scheme.success
                                            : scheme.error)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: (netBalance >= 0
                                              ? scheme.success
                                              : scheme.error)
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    '${netBalance < 0 ? '-' : ''}${settings.currency}${NumberFormat('#,##0').format(netBalance.abs())}',
                                    style: TextStyle(
                                      color: netBalance >= 0
                                          ? scheme.success
                                          : scheme.error,
                                      fontSize: AppType.headline,
                                      fontWeight: FontWeight.bold,
                                      fontFeatures: AppType.tabular,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (settings.monthlyBudget > 0) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0,
                              end: (totalSpent / settings.monthlyBudget).clamp(
                                0.0,
                                1.0,
                              ),
                            ),
                            duration: const Duration(milliseconds: 1200),
                            curve: Curves.easeOutExpo,
                            builder: (context, val, _) =>
                                LinearProgressIndicator(
                                  value: val,
                                  backgroundColor: scheme.tint,
                                  color: val > 0.85
                                      ? scheme.error
                                      : scheme.primary,
                                  minHeight: 8,
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: _statChip(
                              scheme,
                              'Budget',
                              '${settings.currency}${NumberFormat('#,##0').format(settings.monthlyBudget)}',
                            ),
                          ),
                          if (hasIncome) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: _statChip(
                                scheme,
                                'Income',
                                '${settings.currency}${NumberFormat('#,##0').format(monthlyIncome)}',
                              ),
                            ),
                          ],
                          if (settings.monthlyBudget > 0 && dailyLeft.isFinite) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: _statChip(
                                scheme,
                                'Daily left',
                                dailyLeft >= 0
                                    ? '${settings.currency}${NumberFormat('#,##0').format(dailyLeft)}'
                                    : '-${settings.currency}${NumberFormat('#,##0').format(dailyLeft.abs())}',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Primary Add Expense CTA
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Semantics(
                  button: true,
                  label: 'Add Expense',
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Material(
                      color: scheme.ctaFill,
                      borderRadius: AppRadius.mdAll,
                      child: InkWell(
                        borderRadius: AppRadius.mdAll,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddExpenseScreen(),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, color: scheme.ctaText),
                            const SizedBox(width: 8),
                            Text(
                              'Add Expense',
                              style: TextStyle(
                                color: scheme.ctaText,
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
            ),

            // 4. Spending-pulse card — THE single glass hero on the page
            SliverToBoxAdapter(
              child: SpendingPulseCard(
                monthlyExpenses: monthlyExpenses,
                allExpenses: expenses,
                currency: settings.currency,
                monthlyBudget: settings.monthlyBudget,
                startingDayOfMonth: settings.startingDayOfMonth,
                pendingCount: uncategorized.length,
                onReviewPending: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PendingScreen()),
                ),
              ),
            ),

            // 5. Income + recurring as one compact linked-rows component
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    _linkedRow(
                      scheme,
                      icon: Icons.account_balance_wallet_rounded,
                      tone: scheme.success,
                      title: 'Monthly Income',
                      subtitle: hasIncome
                          ? '${settings.currency}${NumberFormat('#,##0').format(monthlyIncome)} logged this month'
                          : 'Tap to log your income',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const IncomeScreen()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _linkedRow(
                      scheme,
                      icon: Icons.repeat_rounded,
                      tone: scheme.primary,
                      title: 'Recurring Expenses',
                      subtitle: 'Subscriptions & bills',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RecurringExpenseScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 6. Category Spending: top-4 + "+N more"
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Category Spending',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppType.headline,
                          fontWeight: FontWeight.bold,
                          color: scheme.ink,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AnalyticsScreen(),
                        ),
                      ),
                      child: Text('See All', style: TextStyle(color: scheme.primary)),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildCategoryBars(
                context,
                monthlyExpenses,
                budgets,
                settings.currency,
              ),
            ),

            // Collapsed calendar preview + day jump (Analytics owns the full)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _calendarOpen = !_calendarOpen);
                      },
                      borderRadius: AppRadius.smAll,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'This month, day by day',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Icon(
                              _calendarOpen
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: scheme.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_calendarOpen)
                      SpendingCalendar(
                        period: period,
                        selectedDay: _selectedDay ?? now,
                        expenses: monthlyExpenses,
                        currency: settings.currency,
                        lastSelectableDay: now,
                        goals: dailyGoals,
                        onDaySelected: (day) {
                          setState(
                            () => _selectedDay =
                                _isSameDay(day, _selectedDay) ? null : day,
                          );
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => DayDetailSheet(
                              day: day,
                              currency: settings.currency,
                              expenses: monthlyExpenses
                                  .where((e) => _isSameDay(e.date, day))
                                  .toList(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // 7. Recent Transactions + See All → Transactions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedDay == null
                            ? 'Recent Transactions'
                            : DateFormat('EEE, d MMM').format(_selectedDay!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppType.headline,
                          fontWeight: FontWeight.bold,
                          color: scheme.ink,
                        ),
                      ),
                    ),
                    if (_selectedDay != null)
                      TextButton.icon(
                        onPressed: () => setState(() => _selectedDay = null),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Clear'),
                      )
                    else
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TransactionsScreen(),
                          ),
                        ),
                        child: const Text('See All'),
                      ),
                  ],
                ),
              ),
            ),
            if (recentExpenses.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No transactions yet.\nTap Add Expense above to log your first one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.muted),
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => ExpenseTile(
                    expense: recentExpenses[i],
                    onEdit: () => _showEditSheet(recentExpenses[i]),
                    onDelete: () => _handleDelete(recentExpenses[i]),
                  ),
                  childCount: recentExpenses.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          ],
        ),
      ),
    );
  }

  Widget _statChip(SchemeTheme scheme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tint,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: scheme.muted, fontSize: AppType.caption),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.ink,
              fontSize: AppType.body,
              fontWeight: FontWeight.w600,
              fontFeatures: AppType.tabular,
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkedRow(
    SchemeTheme scheme, {
    required IconData icon,
    required Color tone,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: scheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: tone, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.ink,
                      fontSize: AppType.label,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppType.caption,
                      color: scheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.muted),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBars(
    BuildContext context,
    List<Expense> expenses,
    List<Budget> budgets,
    String currency,
  ) {
    final scheme = SchemeTheme.of(context);
    final Map<Category, double> sums = {};
    for (var e in expenses) {
      sums[e.category] = (sums[e.category] ?? 0) + e.amount;
    }
    if (sums.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No spending this month',
          style: TextStyle(color: scheme.muted),
        ),
      );
    }
    final topCats = sums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final overflowCount = topCats.length - 4;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.border),
        ),
        child: Column(
          children: [
            ...topCats.take(4).map((e) {
              final cat = e.key;
              final spent = e.value;
              final catColor = scheme.categoryColors[cat.index];
              final budget = budgets.firstWhere(
                (b) => b.category == cat,
                orElse: () => Budget(category: cat, monthlyLimit: 0),
              );
              final limit = budget.monthlyLimit > 0
                  ? budget.monthlyLimit
                  : spent * 1.5;
              final pct = (spent / limit).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(cat.icon, size: 16, color: catColor),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              cat.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.ink,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$currency${NumberFormat('#,##0').format(spent)} / $currency${NumberFormat('#,##0').format(limit)}',
                          style: TextStyle(
                            fontSize: AppType.label,
                            color: scheme.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: pct),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutExpo,
                        builder: (context, val, _) => LinearProgressIndicator(
                          value: val,
                          backgroundColor: scheme.tint,
                          color: pct > 0.85 ? scheme.error : catColor,
                          minHeight: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: AppType.caption,
                          fontWeight: FontWeight.bold,
                          color: pct > 0.85 ? scheme.error : scheme.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (overflowCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+$overflowCount more',
                  style: TextStyle(
                    color: scheme.muted,
                    fontSize: AppType.label,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
