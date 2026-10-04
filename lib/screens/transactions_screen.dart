import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../widgets/expense_tile.dart';
import '../widgets/edit_expense_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/money_text.dart';
import '../utils/date_extension.dart';
import '../utils/design.dart';
import '../utils/theme.dart';
import 'add_expense_screen.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  final Category? initialCategory;
  const TransactionsScreen({super.key, this.initialCategory});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  Category? _selectedCategory;
  String _searchQuery = '';
  String _sortBy = 'date';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  // ref is always valid here; parent is still alive
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
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
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

  @override
  Widget build(BuildContext context) {
    var expenses = ref
        .watch(expenseProvider)
        .where((e) => !e.isUncategorized)
        .toList();
    final settings = ref.watch(appSettingsProvider);

    if (_selectedCategory != null) {
      expenses = expenses
          .where((e) => e.category == _selectedCategory)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      expenses = expenses
          .where(
            (e) => e.title.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    if (_dateRange != null) {
      expenses = expenses
          .where(
            (e) =>
                !e.date.isBefore(_dateRange!.start) &&
                !e.date.isAfter(_dateRange!.end.add(const Duration(days: 1))),
          )
          .toList();
    }
    if (_sortBy == 'date') {
      expenses.sort((a, b) => b.date.compareTo(a.date));
    } else {
      expenses.sort((a, b) => b.amount.compareTo(a.amount));
    }

    final grouped = groupByMonth(expenses, (e) => e.date);
    final scheme = SchemeTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
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
                        color: scheme.ctaText,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Expense',
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
          IconButton(
            icon: Icon(
              Icons.date_range,
              color: _dateRange != null ? scheme.primary : null,
            ),
            tooltip: 'Filter by date',
            onPressed: () async {
              HapticFeedback.lightImpact();
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: now,
                initialDateRange:
                    _dateRange ??
                    DateTimeRange(
                      start: DateTime(now.year, now.month, 1),
                      end: now,
                    ),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: Theme.of(
                      ctx,
                    ).colorScheme.copyWith(primary: scheme.primary),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _dateRange = picked);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort transactions',
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    const Expanded(child: Text('Date (newest first)')),
                    if (_sortBy == 'date')
                      Icon(Icons.check, size: 16, color: scheme.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'amount',
                child: Row(
                  children: [
                    const Expanded(child: Text('Amount (high to low)')),
                    if (_sortBy == 'amount')
                      Icon(Icons.check, size: 16, color: scheme.primary),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                    isDense: true,
                    filled: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    if (_dateRange != null)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: InputChip(
                          avatar: Icon(
                            Icons.date_range,
                            size: 14,
                            color: scheme.primary,
                          ),
                          label: Text(
                            '${DateFormat('MMM d').format(_dateRange!.start)} – ${DateFormat('MMM d').format(_dateRange!.end)}',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: scheme.primary.withValues(
                            alpha: 0.08,
                          ),
                          side: BorderSide(
                            color: scheme.primary.withValues(alpha: 0.4),
                          ),
                          deleteIconColor: scheme.primary,
                          onDeleted: () {
                            HapticFeedback.selectionClick();
                            setState(() => _dateRange = null);
                          },
                        ),
                      ),
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedCategory == null,
                      selectedColor: scheme.primary.withValues(alpha: 0.15),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = null);
                      },
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ...Category.values.map(
                      (cat) => Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: FilterChip(
                          label: Text(cat.displayName),
                          selected: _selectedCategory == cat,
                          selectedColor: scheme
                              .categoryColors[cat.index]
                              .withValues(alpha: 0.25),
                          avatar: Icon(
                            cat.icon,
                            size: 14,
                            color: scheme.categoryColors[cat.index],
                          ),
                          onSelected: (v) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedCategory = v ? cat : null);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: expenses.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              itemCount: grouped.length,
              itemBuilder: (_, i) {
                final month = grouped.keys.elementAt(i);
                final txns = grouped[month]!;
                final monthTotal = txns.fold(0.0, (a, b) => a + b.amount);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.xs,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$month · ${txns.length}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          MoneyText(
                            monthTotal,
                            currency: settings.currency,
                            size: AppType.body,
                            weight: FontWeight.w600,
                            color: scheme.ink,
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ...txns.map(
                      (e) => ExpenseTile(
                        expense: e,
                        onEdit: () => _showEditSheet(context, e),
                        onDelete: () => _handleDelete(e),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildEmpty() {
    final scheme = SchemeTheme.of(context);
    final hasFilters =
        _selectedCategory != null ||
        _searchQuery.isNotEmpty ||
        _dateRange != null;
    return EmptyState(
      icon: hasFilters ? Icons.search_off_rounded : Icons.receipt_long_rounded,
      title: hasFilters ? 'No matching transactions' : 'No transactions yet',
      subtitle: hasFilters
          ? 'Try adjusting your filters or search'
          : 'Add your first expense from the + Expense action above',
      action: hasFilters
          ? OutlinedButton.icon(
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.primary,
                side: BorderSide(color: scheme.primary),
              ),
              onPressed: () => setState(() {
                _selectedCategory = null;
                _searchQuery = '';
                _dateRange = null;
              }),
            )
          : null,
    );
  }

  void _showEditSheet(BuildContext context, Expense expense) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditExpenseSheet(expense: expense),
    );
  }
}
