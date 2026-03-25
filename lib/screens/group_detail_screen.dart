import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/split_group.dart';
import '../models/group_expense.dart';
import '../providers/group_provider.dart';
import '../providers/group_expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../utils/constants.dart';
import 'add_group_sheet.dart';
import 'add_group_expense_sheet.dart';
import 'settle_up_sheet.dart';

class GroupDetailScreen extends ConsumerWidget {
  final SplitGroup group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allExpenses = ref.watch(groupExpenseProvider);
    final settings = ref.watch(appSettingsProvider);
    final currency = settings.currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final expenses = allExpenses.where((e) => e.groupId == group.id).toList();
    final unsettledExpenses = expenses.where((e) => !e.isSettled).toList();
    final balances = _computeBalances(unsettledExpenses);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Group',
            onPressed: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => AddGroupSheet(existingGroup: group),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Group',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: Column(children: [
        // Per-person balance cards
        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: group.participants.length,
            itemBuilder: (context, i) {
              final p = group.participants[i];
              final net = balances[p.id] ?? 0;
              final color = Color(p.avatarColorValue);

              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: color,
                      child: Text(
                        p.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      net >= 0
                          ? '+$currency${NumberFormat('#,##0.##').format(net)}'
                          : '-$currency${NumberFormat('#,##0.##').format(net.abs())}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: net >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Settle up hint / who owes whom
        if (balances.values.any((v) => v != 0))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getSettlementHint(balances),
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: 12),

        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expenses (${expenses.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (unsettledExpenses.isNotEmpty)
                TextButton(
                  onPressed: () => _settleAll(context, ref, unsettledExpenses),
                  child: const Text('Settle All'),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        if (expenses.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'No expenses yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add an expense to start tracking',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: expenses.length,
              itemBuilder: (context, i) {
                final expense = expenses[i];
                final paidByName = group.participants
                    .firstWhere((p) => p.id == expense.paidBy,
                        orElse: () => group.participants.first)
                    .name;
                final paidByColor = Color(
                    group.participants
                        .firstWhere((p) => p.id == expense.paidBy,
                            orElse: () => group.participants.first)
                        .avatarColorValue);

                return Dismissible(
                  key: Key(expense.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Expense?'),
                        content: Text(
                            'Delete "${expense.description}"? This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) {
                    ref.read(groupExpenseProvider.notifier).deleteExpense(expense.id);
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) => SettleUpSheet(expense: expense, group: group),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: paidByColor.withValues(alpha: 0.2),
                            child: Text(
                              paidByName[0].toUpperCase(),
                              style: TextStyle(
                                color: paidByColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        expense.description,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          decoration: expense.isSettled
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: expense.isSettled
                                              ? Colors.grey
                                              : null,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (expense.isSettled)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Settled',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$paidByName paid · ${DateFormat('d MMM y').format(expense.date)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$currency${NumberFormat('#,##0.##').format(expense.totalAmount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: expense.isSettled
                                      ? Colors.grey
                                      : AppColors.primary,
                                ),
                              ),
                              if (!expense.isSettled)
                                Text(
                                  'Tap to settle',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                            ],
                          ),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => AddGroupExpenseSheet(group: group),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Expense',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Map<String, double> _computeBalances(List<GroupExpense> expenses) {
    final Map<String, double> totalPaid = {};
    final Map<String, double> totalOwed = {};

    for (final p in group.participants) {
      totalPaid[p.id] = 0;
      totalOwed[p.id] = 0;
    }

    for (final expense in expenses) {
      totalPaid[expense.paidBy] = (totalPaid[expense.paidBy] ?? 0) + expense.totalAmount;
      for (final share in expense.shares) {
        totalOwed[share.participantId] =
            (totalOwed[share.participantId] ?? 0) + share.amount;
      }
    }

    return {
      for (final p in group.participants)
        p.id: (totalPaid[p.id] ?? 0) - (totalOwed[p.id] ?? 0),
    };
  }

  String _getSettlementHint(Map<String, double> balances) {
    final positive = <String>[];
    final negative = <String>[];

    for (final p in group.participants) {
      final net = balances[p.id] ?? 0;
      if (net > 0.01) positive.add(p.name);
      if (net < -0.01) negative.add(p.name);
    }

    if (positive.isEmpty && negative.isEmpty) return 'All settled up!';
    if (positive.length == 1 && negative.length == 1) {
      return '${positive.first} is owed by ${negative.first}';
    }
    if (positive.isNotEmpty) {
      return '${positive.join(", ")} ${positive.length == 1 ? "is" : "are"} owed money';
    }
    if (negative.isNotEmpty) {
      return '${negative.join(", ")} ${negative.length == 1 ? "owes" : "owe"} money';
    }
    return '';
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group?'),
        content: Text(
            'Delete "${group.name}" and all its expenses? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Delete all expenses for this group
              final expenses = ref.read(groupExpenseProvider);
              for (final e in expenses.where((e) => e.groupId == group.id)) {
                ref.read(groupExpenseProvider.notifier).deleteExpense(e.id);
              }
              ref.read(splitGroupProvider.notifier).deleteGroup(group.id);
              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // go back
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _settleAll(
      BuildContext context, WidgetRef ref, List<GroupExpense> expenses) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Settle All Expenses?'),
        content: Text('Mark all ${expenses.length} expenses as settled?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              for (final e in expenses) {
                ref.read(groupExpenseProvider.notifier).settleExpense(e.id);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Settle All'),
          ),
        ],
      ),
    );
  }
}
