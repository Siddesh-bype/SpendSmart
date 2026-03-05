import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../providers/app_settings_provider.dart';
import '../utils/constants.dart';

class ExpenseTile extends ConsumerWidget {
  final Expense expense;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete; // Parent handles delete + undo so ref is always valid

  const ExpenseTile({
    super.key,
    required this.expense,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = ref.watch(appSettingsProvider).currency;

    return Slidable(
      key: ValueKey(expense.id),
      // LEFT swipe → Edit (start)
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.lightImpact();
              // Close Slidable FIRST, then open sheet
              Slidable.of(context)?.close();
              Future.microtask(() => onEdit?.call());
            },
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
            icon: Icons.edit_outlined,
            label: 'Edit',
          ),
        ],
      ),
      // RIGHT swipe → Delete (end)
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        dismissible: DismissiblePane(onDismissed: () {
          HapticFeedback.mediumImpact();
          onDelete?.call();
        }),
        children: [
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.mediumImpact();
              onDelete?.call();
            },
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
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
        title: Text(
          expense.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          DateFormat('MMM dd, yyyy  h:mm a').format(expense.date),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$cur${NumberFormat('#,##0.##').format(expense.amount)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            // Visible edit button — essential for web where swipe doesn't work
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: AppColors.secondary),
              tooltip: 'Edit',
              onPressed: () {
                HapticFeedback.lightImpact();
                onEdit?.call();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          ],
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          onEdit?.call();
        },
      ),
    );
  }
}
