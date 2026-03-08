import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/income_provider.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../widgets/expense_tile.dart';
import '../widgets/edit_expense_sheet.dart';
import '../utils/constants.dart';
import '../utils/date_extension.dart';
import '../widgets/glass_container.dart';
import 'pending_screen.dart';
import 'transactions_screen.dart';
import 'notifications_screen.dart';
import 'income_screen.dart';

import 'recurring_expense_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  void _handleDelete(Expense expense) {
    HapticFeedback.mediumImpact();
    ref.read(expenseProvider.notifier).deleteExpense(expense.id);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${expense.title}"'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.accent,
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(expenseProvider.notifier).addExpense(expense);
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => EditExpenseSheet(expense: expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses      = ref.watch(expenseProvider);
    final settings      = ref.watch(appSettingsProvider);
    final budgets       = ref.watch(budgetProvider);
    final notifications = ref.watch(notificationProvider);
    final incomes       = ref.watch(incomeProvider);
    final unreadCount   = notifications.where((n) => !n.isRead).length;
    final uncategorized = expenses.where((e) => e.isUncategorized).toList();
    final now           = DateTime.now();

    final monthlyExpenses = expenses.where(
      (e) => e.date.isTargetCustomMonth(now.month, now.year, settings.startingDayOfMonth) && !e.isUncategorized,
    ).toList();
    final totalSpent = monthlyExpenses.fold(0.0, (a, b) => a + b.amount);

    // Monthly income for current month
    final monthlyIncome = incomes
        .where((i) => i.date.month == now.month && i.date.year == now.year)
        .fold(0.0, (s, i) => s + i.amount);

    // Use income-based net if income is tracked, else fall back to budget-based savings
    final hasIncome  = monthlyIncome > 0;
    final netBalance = hasIncome ? monthlyIncome - totalSpent : settings.monthlyBudget - totalSpent;
    final netLabel   = hasIncome ? 'Net Balance' : 'Savings';

    // Daily budget remaining
    final daysInMonth  = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft     = (daysInMonth - now.day + 1).clamp(1, daysInMonth);
    final dailyLeft    = settings.monthlyBudget > 0
        ? ((settings.monthlyBudget - totalSpent) / daysLeft)
        : 0.0;

    final recentExpenses = expenses.where((e) => !e.isUncategorized).take(5).toList();

    // Budget check on expense changes
    ref.listen(expenseProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final Map<Category, double> spending = {};
        for (var e in monthlyExpenses) {
          spending[e.category] = (spending[e.category] ?? 0) + e.amount;
        }
        ref.read(notificationProvider.notifier).checkBudgets(budgets, spending);
      });
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(DateFormat('MMMM yyyy').format(now),
                          style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color)),
                      const Text('SpendSmart', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ]),
                    Row(children: [
                      if (uncategorized.isNotEmpty)
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingScreen())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(children: [
                              const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                              const SizedBox(width: 4),
                              Text('${uncategorized.length} pending',
                                  style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                        child: Stack(clipBehavior: Clip.none, children: [
                          const Icon(Icons.notifications_outlined),
                          if (unreadCount > 0)
                            Positioned(
                              right: -4, top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: Text(unreadCount > 9 ? '9+' : '$unreadCount',
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ]),
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            // ── Summary card ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF1E88E5), Color(0xFF42A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Total Spent', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          '${settings.currency}${NumberFormat('#,##0').format(totalSpent)}',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1),
                        ),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(netLabel, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: netBalance >= 0
                                ? const Color(0xFF4ADE80).withValues(alpha: 0.2)
                                : Colors.red.shade400.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: netBalance >= 0
                                  ? const Color(0xFF4ADE80).withValues(alpha: 0.5)
                                  : Colors.red.shade400.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            '${netBalance < 0 ? '-' : ''}${settings.currency}${NumberFormat('#,##0').format(netBalance.abs())}',
                            style: TextStyle(
                              color: netBalance >= 0 ? const Color(0xFF4ADE80) : Colors.red.shade300,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ]),
                    ]),
                    const SizedBox(height: 20),
                    if (settings.monthlyBudget > 0) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: (totalSpent / settings.monthlyBudget).clamp(0.0, 1.0),
                          ),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutExpo,
                          builder: (context, val, _) => LinearProgressIndicator(
                            value: val,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            color: val > 0.85 ? Colors.red.shade400 : AppColors.accent,
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      _chip('Budget', '${settings.currency}${NumberFormat('#,##0').format(settings.monthlyBudget)}'),
                      if (hasIncome)
                        _chip('Income', '${settings.currency}${NumberFormat('#,##0').format(monthlyIncome)}'),
                      if (settings.monthlyBudget > 0 && dailyLeft.isFinite)
                        _chip(
                          'Daily left',
                          dailyLeft >= 0
                              ? '${settings.currency}${NumberFormat('#,##0').format(dailyLeft)}'
                              : '-${settings.currency}${NumberFormat('#,##0').format(dailyLeft.abs())}',
                        ),
                    ]),
                  ]),
                ),
              ),
            ),

            // ── Spending alert banner ─────────────────────────────────────────
            if (settings.monthlyBudget > 0 && totalSpent > settings.monthlyBudget * 0.8)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _SpendingAlertBanner(
                    totalSpent: totalSpent,
                    budget: settings.monthlyBudget,
                    currency: settings.currency,
                  ),
                ),
              ),

            // ── Income quick-access card ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncomeScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.account_balance_wallet_rounded, color: Colors.green.shade700, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Monthly Income',
                              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green.shade800, fontSize: 13)),
                          Text(
                            hasIncome
                                ? '${settings.currency}${NumberFormat('#,##0').format(monthlyIncome)} logged this month'
                                : 'Tap to log your income',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                          ),
                        ]),
                      ),
                      Icon(Icons.chevron_right, color: Colors.green.shade400),
                    ]),
                  ),
                ),
              ),
            ),

            // ── Category Spending ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Category Spending', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsScreen())),
                    child: const Text('See All', style: TextStyle(color: AppColors.primary)),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(child: _buildCategoryBars(context, monthlyExpenses, budgets, settings.currency)),

            // ── Recurring expenses card ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringExpenseScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.purple.shade100, shape: BoxShape.circle),
                        child: Icon(Icons.repeat_rounded, color: Colors.purple.shade700, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Recurring Expenses',
                              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.purple.shade800, fontSize: 13)),
                          Text('Subscriptions & bills', style: TextStyle(fontSize: 11, color: Colors.purple.shade600)),
                        ]),
                      ),
                      Icon(Icons.chevron_right, color: Colors.purple.shade400),
                    ]),
                  ),
                ),
              ),
            ),

            // ── Recent Transactions ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Recent Transactions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsScreen())),
                    child: const Text('See All', style: TextStyle(color: AppColors.primary)),
                  ),
                ]),
              ),
            ),
            if (recentExpenses.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No transactions yet.\nTap + to add your first expense.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
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
            const SliverToBoxAdapter(child: SizedBox(height: 160)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildCategoryBars(BuildContext context, List<Expense> expenses, List<Budget> budgets, String currency) {
    final Map<Category, double> sums = {};
    for (var e in expenses) {
      sums[e.category] = (sums[e.category] ?? 0) + e.amount;
    }
    if (sums.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No spending this month', style: TextStyle(color: Colors.grey)),
      );
    }
    final topCats = sums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassContainer(
        borderRadius: 20,
        backgroundColor: Theme.of(context).cardTheme.color ?? Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: topCats.take(4).map((e) {
            final cat    = e.key;
            final spent  = e.value;
            final budget = budgets.firstWhere((b) => b.category == cat, orElse: () => Budget(category: cat, monthlyLimit: 0));
            final limit  = budget.monthlyLimit > 0 ? budget.monthlyLimit : spent * 1.5;
            final pct    = (spent / limit).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Icon(cat.icon, size: 16, color: cat.color),
                    ),
                    const SizedBox(width: 12),
                    Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  Text('$currency${NumberFormat('#,##0').format(spent)} / $currency${NumberFormat('#,##0').format(limit)}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutExpo,
                    builder: (context, val, _) => LinearProgressIndicator(
                      value: val,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      color: pct > 0.85 ? Colors.red.shade400 : cat.color,
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                          color: pct > 0.85 ? Colors.red.shade400 : Colors.grey)),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SpendingAlertBanner extends StatelessWidget {
  final double totalSpent;
  final double budget;
  final String currency;

  const _SpendingAlertBanner({
    required this.totalSpent,
    required this.budget,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final isOver       = totalSpent >= budget;
    final pct          = (totalSpent / budget * 100).toStringAsFixed(0);
    final overAmount   = totalSpent - budget;
    final color        = isOver ? Colors.red.shade600 : Colors.orange.shade700;
    final bgColor      = isOver ? Colors.red.shade50 : Colors.orange.shade50;
    final borderColor  = isOver ? Colors.red.shade200 : Colors.orange.shade200;
    final icon         = isOver ? Icons.error_outline_rounded : Icons.warning_amber_rounded;
    final title        = isOver ? 'Over Budget!' : 'Approaching Budget Limit';
    final message      = isOver
        ? '$currency${NumberFormat('#,##0').format(overAmount)} over your monthly budget'
        : 'You\'ve used $pct% of your monthly budget';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
            Text(message, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.85))),
          ]),
        ),
      ]),
    );
  }
}
