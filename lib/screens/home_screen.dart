import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/notification_provider.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../widgets/expense_tile.dart';
import '../widgets/edit_expense_sheet.dart';
import '../utils/constants.dart';
import 'pending_screen.dart';
import 'transactions_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Delete+undo handled here — ref is always valid in StatefulWidget
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
    final expenses = ref.watch(expenseProvider);
    final settings = ref.watch(appSettingsProvider);
    final budgets = ref.watch(budgetProvider);
    final notifications = ref.watch(notificationProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;
    final uncategorized = expenses.where((e) => e.isUncategorized).toList();
    final now = DateTime.now();
    final monthlyExpenses = expenses.where(
      (e) => e.date.month == now.month && e.date.year == now.year && !e.isUncategorized
    ).toList();
    final totalSpent = monthlyExpenses.fold(0.0, (a, b) => a + b.amount);
    final savings = settings.monthlyIncome - totalSpent;
    final recentExpenses = expenses.where((e) => !e.isUncategorized).take(5).toList();

    // Auto-check budgets when data changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final Map<Category, double> spending = {};
      for (var e in monthlyExpenses) {
        spending[e.category] = (spending[e.category] ?? 0) + e.amount;
      }
      ref.read(notificationProvider.notifier).checkBudgets(budgets, spending);
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(DateFormat('MMMM').format(now),
                        style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)),
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
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const NotificationsScreen())),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_outlined),
                            if (unreadCount > 0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unreadCount > 9 ? '9+' : '$unreadCount',
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            // Summary Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  padding: const EdgeInsets.all(22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Total Spent', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('${settings.currency}${NumberFormat('#,##0').format(totalSpent)}',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text('Savings', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('${settings.currency}${NumberFormat('#,##0').format(savings.abs())}',
                          style: TextStyle(
                            color: savings >= 0 ? const Color(0xFF4ADE80) : Colors.red.shade300,
                            fontSize: 18, fontWeight: FontWeight.bold,
                          )),
                      ]),
                    ]),
                    const SizedBox(height: 16),
                    if (settings.monthlyIncome > 0) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: settings.monthlyIncome > 0 ? (totalSpent / settings.monthlyIncome).clamp(0.0, 1.0) : 0.0,
                          backgroundColor: Colors.white24,
                          color: Colors.white,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      _chip('Income', '${settings.currency}${NumberFormat('#,##0').format(settings.monthlyIncome)}'),
                      _chip('Spent', '${(settings.monthlyIncome > 0 ? (totalSpent / settings.monthlyIncome * 100) : 0).toStringAsFixed(0)}%'),
                    ]),
                  ]),
                ),
              ),
            ),

            // Category Spending
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

            // Recent Transactions
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
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: topCats.take(4).map((e) {
              final cat = e.key;
              final spent = e.value;
              final budget = budgets.firstWhere((b) => b.category == cat, orElse: () => Budget(category: cat, monthlyLimit: 0));
              final limit = budget.monthlyLimit > 0 ? budget.monthlyLimit : spent * 1.5;
              final pct = (spent / limit).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      Icon(cat.icon, size: 16, color: cat.color),
                      const SizedBox(width: 8),
                      Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                    Text('$currency${NumberFormat('#,##0').format(spent)} / $currency${NumberFormat('#,##0').format(limit)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.grey.shade200,
                      color: pct > 0.85 ? Colors.red : cat.color,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Align(alignment: Alignment.centerRight,
                    child: Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 11, color: pct > 0.85 ? Colors.red : Colors.grey))),
                ]),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
