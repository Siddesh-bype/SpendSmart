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
import '../utils/constants.dart';

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

  // === DELETE + UNDO at parent level (ref is always valid here) ===
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
            // ref is always valid here — parent is still alive
            ref.read(expenseProvider.notifier).addExpense(expense);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var expenses = ref.watch(expenseProvider).where((e) => !e.isUncategorized).toList();
    final settings = ref.watch(appSettingsProvider);

    if (_selectedCategory != null) {
      expenses = expenses.where((e) => e.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      expenses = expenses.where((e) =>
          e.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    if (_dateRange != null) {
      expenses = expenses.where((e) =>
          !e.date.isBefore(_dateRange!.start) &&
          !e.date.isAfter(_dateRange!.end.add(const Duration(days: 1)))).toList();
    }
    if (_sortBy == 'date') {
      expenses.sort((a, b) => b.date.compareTo(a.date));
    } else {
      expenses.sort((a, b) => b.amount.compareTo(a.amount));
    }

    final grouped = <String, List<Expense>>{};
    for (final e in expenses) {
      final key = DateFormat('MMMM yyyy').format(e.date);
      grouped.putIfAbsent(key, () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.date_range,
                color: _dateRange != null ? AppColors.accent : null),
            tooltip: 'Filter by date',
            onPressed: () async {
              HapticFeedback.lightImpact();
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: now,
                initialDateRange: _dateRange ??
                    DateTimeRange(
                        start: DateTime(now.year, now.month, 1), end: now),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: Theme.of(ctx)
                        .colorScheme
                        .copyWith(primary: AppColors.secondary),
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
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                  filled: true,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            if (_dateRange != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(children: [
                  const Icon(Icons.date_range, size: 14, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('MMM d').format(_dateRange!.start)} – ${DateFormat('MMM d, yyyy').format(_dateRange!.end)}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  selectedColor: AppColors.secondary.withValues(alpha: 0.2),
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = null);
                  },
                ),
                const SizedBox(width: 8),
                ...Category.values.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat.name),
                        selected: _selectedCategory == cat,
                        selectedColor: cat.color.withValues(alpha: 0.25),
                        avatar: Icon(cat.icon, size: 14, color: cat.color),
                        onSelected: (v) {
                          HapticFeedback.selectionClick();
                          setState(() =>
                              _selectedCategory = v ? cat : null);
                        },
                      ),
                    )),
              ]),
            ),
          ]),
        ),
      ),
      body: expenses.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              itemCount: grouped.length,
              itemBuilder: (_, i) {
                final month = grouped.keys.elementAt(i);
                final txns = grouped[month]!;
                final monthTotal =
                    txns.fold(0.0, (a, b) => a + b.amount);
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(month,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.grey)),
                              Text(
                                '${settings.currency}${NumberFormat('#,##0').format(monthTotal)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary),
                              ),
                            ]),
                      ),
                      const Divider(height: 1),
                      ...txns.map((e) => ExpenseTile(
                            expense: e,
                            onEdit: () => _showEditSheet(context, e),
                            onDelete: () => _handleDelete(e),
                          )),
                    ]);
              },
            ),
    );
  }

  Widget _buildEmpty() {
    final hasFilters = _selectedCategory != null ||
        _searchQuery.isNotEmpty ||
        _dateRange != null;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(
          hasFilters
              ? Icons.search_off_rounded
              : Icons.receipt_long_rounded,
          size: 72,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 16),
        Text(
          hasFilters ? 'No matching transactions' : 'No transactions yet',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          hasFilters
              ? 'Try adjusting your filters or search'
              : 'Add your first expense using the + button',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        if (hasFilters) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear Filters'),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary)),
            onPressed: () => setState(() {
              _selectedCategory = null;
              _searchQuery = '';
              _dateRange = null;
            }),
          ),
        ],
      ]),
    );
  }

  void _showEditSheet(BuildContext context, Expense expense) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => EditExpenseSheet(expense: expense),
    );
  }
}
