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
import '../utils/constants.dart';
import '../utils/date_extension.dart';
import '../utils/design.dart';

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
          textColor: AppColors.accent,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.date_range,
              color: _dateRange != null ? AppColors.accent : null,
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
                    ).colorScheme.copyWith(primary: AppColors.secondary),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _dateRange = picked);
            },
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear date filter',
              onPressed: () => setState(() => _dateRange = null),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'date', child: Text('Sort by Date')),
              PopupMenuItem(value: 'amount', child: Text('Sort by Amount')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_dateRange != null ? 130 : 112),
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
              if (_dateRange != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.date_range,
                        size: 14,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d, yyyy').format(_dateRange!.end)}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
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
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedCategory == null,
                      selectedColor: AppColors.secondary.withValues(alpha: 0.2),
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
                          selectedColor: cat.color.withValues(alpha: 0.25),
                          avatar: Icon(cat.icon, size: 14, color: cat.color),
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
                            month,
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
                            weight: FontWeight.bold,
                            color: AppColors.secondary,
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
    final hasFilters =
        _selectedCategory != null ||
        _searchQuery.isNotEmpty ||
        _dateRange != null;
    return EmptyState(
      icon: hasFilters ? Icons.search_off_rounded : Icons.receipt_long_rounded,
      title: hasFilters ? 'No matching transactions' : 'No transactions yet',
      subtitle: hasFilters
          ? 'Try adjusting your filters or search'
          : 'Add your first expense using the + button',
      action: hasFilters
          ? OutlinedButton.icon(
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
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
