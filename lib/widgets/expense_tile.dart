import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../providers/app_settings_provider.dart';
import '../utils/constants.dart';
import '../utils/design.dart';
import 'money_text.dart';

/// A single ledger entry.
///
/// Not a card: a continuous hairline rail runs down the list at [_railX] and
/// each entry hangs a short category-coloured tick off it. Amounts are
/// right-aligned in tabular figures so they stack into one column.
class ExpenseTile extends ConsumerWidget {
  /// Distance from the tile's left edge to the centre of the rail.
  static const double _railX = 20;

  /// Leading slot the tick is centred in, so tick centre == [_railX].
  static const double _tickSlot = _railX * 2;
  static const double _tickHeight = 24;

  final Expense expense;
  final VoidCallback? onEdit;
  final VoidCallback?
  onDelete; // Parent handles delete + undo so ref is always valid

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
    final scheme = theme.colorScheme;
    final hairline = theme.dividerTheme.thickness ?? 1;

    return Stack(
      children: [
        // The rail. Sits behind the Slidable so it stays put while a row
        // slides, and spans the full tile height so entries share one line.
        Positioned(
          top: 0,
          bottom: 0,
          left: _railX - hairline / 2,
          width: hairline,
          child: ColoredBox(color: scheme.outlineVariant),
        ),
        Slidable(
          key: ValueKey(expense.id),
          // LEFT swipe -> Edit (start)
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
          // RIGHT swipe -> Delete (end)
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.25,
            dismissible: DismissiblePane(
              onDismissed: () {
                HapticFeedback.mediumImpact();
                onDelete?.call();
              },
            ),
            children: [
              SlidableAction(
                onPressed: (_) {
                  HapticFeedback.mediumImpact();
                  onDelete?.call();
                },
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                icon: Icons.delete_outline,
                label: 'Delete',
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onEdit?.call();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.only(
                  right: AppSpacing.lg,
                  top: AppSpacing.md,
                  bottom: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: _tickSlot,
                      child: Center(
                        child: Container(
                          width: 3,
                          height: _tickHeight,
                          decoration: BoxDecoration(
                            color: expense.category.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    Icon(
                      expense.category.icon,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Expanded, so the amount (non-flex) is measured at its
                    // intrinsic width first and the title yields instead.
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.title,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat(
                              'MMM dd, yyyy  h:mm a',
                            ).format(expense.date),
                            style: theme.textTheme.labelMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    MoneyText(
                      expense.amount,
                      currency: cur,
                      decimals: true,
                      size: AppType.headline,
                      weight: FontWeight.w700,
                      color: scheme.onSurface,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
