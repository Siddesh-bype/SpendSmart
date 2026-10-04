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
import '../utils/theme.dart';
import '../utils/design.dart';
import 'add_group_sheet.dart';
import 'add_group_expense_sheet.dart';
import 'settle_up_sheet.dart';
import '../services/financial_calculation_engine.dart';

class GroupDetailScreen extends ConsumerWidget {
  final SplitGroup group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allExpenses = ref.watch(groupExpenseProvider);
    final settings = ref.watch(appSettingsProvider);
    final currency = settings.currency;
    final scheme = SchemeTheme.of(context);

    // Re-read the group from the provider so a "this is me" pick refreshes
    // balances immediately; fall back to the constructor snapshot.
    SplitGroup view = group;
    for (final g in ref.watch(splitGroupProvider)) {
      if (g.id == view.id) view = g;
    }

    final expenses = allExpenses.where((e) => e.groupId == view.id).toList();
    final unsettledExpenses = expenses.where((e) => !e.isSettled).toList();
    final balances = _computeBalances(view, unsettledExpenses);

    return Scaffold(
      appBar: AppBar(
        title: Text(view.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Group',
            iconSize: 24,
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => AddGroupSheet(existingGroup: view),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: scheme.error),
            tooltip: 'Delete Group',
            iconSize: 24,
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => _confirmDelete(context, ref, view),
          ),
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Member balances carousel — tap a member to mark them as "you".
        SizedBox(
          height: 116,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: view.participants.length,
            itemBuilder: (context, i) {
              final p = view.participants[i];
              final net = balances[p.id] ?? 0;
              final color = Color(p.avatarColorValue);
              final isMe = view.meParticipantId == p.id;
              // Whole chip is the tap target (≈90×84dp, ≥44dp each way).
              // Selection is labeled with a "ME" tag, never color-only.
              return Semantics(
                button: true,
                selected: isMe,
                label: isMe
                    ? '${p.name} is you'
                    : 'Set ${p.name} as you',
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: isMe
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(splitGroupProvider.notifier)
                                  .setMyParticipant(view.id, p.id);
                            },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isMe
                                ? scheme.primary
                                : (net.abs() > 0.01
                                    ? color.withValues(alpha: 0.5)
                                    : scheme.border),
                            width: isMe ? 2.5 : 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: color,
                              child: Text(
                                p.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: Scheme.onAvatar(color),
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppType.body,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              p.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: AppType.caption),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isMe)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ME',
                                  style: TextStyle(
                                    fontSize: AppType.micro,
                                    fontWeight: FontWeight.bold,
                                    color: scheme.surface,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              net >= 0
                                  ? '+$currency${NumberFormat('#,##0.##').format(net)}'
                                  : '-$currency${NumberFormat('#,##0.##').format(net.abs())}',
                              style: TextStyle(
                                fontSize: AppType.caption,
                                fontWeight: FontWeight.bold,
                                color: net >= 0 ? scheme.success : scheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Settle up hint / who owes whom
        if (balances.values.any((v) => v.abs() > 0.01))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
            ),
            child: Text(
              _getSettlementHint(view, balances, currency),
              style: TextStyle(
                fontSize: AppType.label,
                color: scheme.primary,
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: AppType.headline),
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
                  Icon(Icons.receipt_long_outlined, size: 64, color: scheme.muted),
                  const SizedBox(height: 16),
                  Text(
                    'No expenses yet',
                    style: TextStyle(
                      fontSize: AppType.headline,
                      fontWeight: FontWeight.bold,
                      color: scheme.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add an expense to start tracking',
                    style: TextStyle(color: scheme.muted, fontSize: AppType.label),
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
                final paidByName = view.participants
                    .firstWhere((p) => p.id == expense.paidBy,
                        orElse: () => view.participants.first)
                    .name;
                final paidByColor = Color(
                    view.participants
                        .firstWhere((p) => p.id == expense.paidBy,
                            orElse: () => view.participants.first)
                        .avatarColorValue);

                return Dismissible(
                  key: Key(expense.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: scheme.error,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.delete_outline, color: Scheme.onAvatar(scheme.error)),
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
                            style: TextButton.styleFrom(
                              foregroundColor: SchemeTheme.of(context).error,
                            ),
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
                    color: scheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                      side: BorderSide(color: scheme.border),
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
                          builder: (_) => SettleUpSheet(expense: expense, group: view),
                        );
                      },
                      borderRadius: AppRadius.mdAll,
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
                                              ? scheme.muted
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
                                          color: scheme.success.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Settled',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: scheme.success,
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
                                    color: scheme.muted,
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
                                      ? scheme.muted
                                      : scheme.primary,
                                ),
                              ),
                              if (!expense.isSettled)
                                Text(
                                  'Tap to settle',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: scheme.muted,
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
            builder: (_) => AddGroupExpenseSheet(group: view),
          );
        },
        backgroundColor: scheme.ctaFill,
        icon: Icon(Icons.add, color: scheme.ctaText),
        label: Text('Add Expense',
            style: TextStyle(color: scheme.ctaText, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Map<String, double> _computeBalances(
      SplitGroup view, List<GroupExpense> expenses) {
    final Map<String, double> totalPaid = {};
    final Map<String, double> totalOwed = {};

    for (final p in view.participants) {
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
      for (final p in view.participants)
        p.id: (totalPaid[p.id] ?? 0) - (totalOwed[p.id] ?? 0),
    };
  }

  String _getSettlementHint(
      SplitGroup view, Map<String, double> balances, String currency) {
    final namedBalances = <String, double>{};
    for (final p in view.participants) {
      namedBalances[p.name] = balances[p.id] ?? 0.0;
    }

    final transfers = FinancialCalculationEngine.optimizeGroupSettlements(namedBalances);
    if (transfers.isEmpty) return 'All settled up! ✨';

    final money = NumberFormat('#,##0.##');
    final hints = transfers.map((t) => '${t.from} pays ${t.to} $currency${money.format(t.amount)}').toList();
    return hints.join('  •  ');
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SplitGroup view) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group?'),
        content: Text(
            'Delete "${view.name}" and all its expenses? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Delete all expenses for this group
              final expenses = ref.read(groupExpenseProvider);
              for (final e in expenses.where((e) => e.groupId == view.id)) {
                ref.read(groupExpenseProvider.notifier).deleteExpense(e.id);
              }
              ref.read(splitGroupProvider.notifier).deleteGroup(view.id);
              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // go back
            },
            style: TextButton.styleFrom(
              foregroundColor: SchemeTheme.of(context).error,
            ),
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
