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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Slidable(
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
              borderRadius: BorderRadius.circular(16),
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
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: 'Delete',
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            )
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: expense.category.color.withValues(alpha: 0.15),
              child: Icon(expense.category.icon, color: expense.category.color, size: 22),
            ),
            title: Text(
              expense.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                DateFormat('MMM dd, yyyy  h:mm a').format(expense.date),
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$cur${NumberFormat('#,##0.##').format(expense.amount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  expense.category.name,
                  style: TextStyle(
                    fontSize: 10,
                    color: expense.category.color,
                    fontWeight: FontWeight.w600,
                  ),
                )
              ]
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              onEdit?.call();
            },
          ),
        ),
      ),
    );
  }
}
