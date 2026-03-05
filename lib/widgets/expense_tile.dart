import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../providers/expense_provider.dart';
import '../providers/app_settings_provider.dart';

class ExpenseTile extends ConsumerWidget {
  final Expense expense;
  final VoidCallback? onEdit;

  const ExpenseTile({super.key, required this.expense, this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = ref.watch(appSettingsProvider).currency;

    return Slidable(
      key: ValueKey(expense.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.lightImpact();
              onEdit?.call();
            },
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            icon: Icons.edit_outlined,
            label: 'Edit',
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
          ),
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.mediumImpact();
              final deleted = expense;
              ref.read(expenseProvider.notifier).deleteExpense(expense.id);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted "${deleted.title}"'),
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(expenseProvider.notifier).addExpense(deleted);
                    },
                  ),
                ),
              );
            },
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: expense.category.color.withValues(alpha: 0.15),
          child: Icon(expense.category.icon, color: expense.category.color, size: 20),
        ),
        title: Text(expense.title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
          DateFormat('MMM dd, yyyy  hh:mm a').format(expense.date),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        trailing: Text(
          '$cur${NumberFormat('#,##0.##').format(expense.amount)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          onEdit?.call();
        },
      ),
    );
  }
}
