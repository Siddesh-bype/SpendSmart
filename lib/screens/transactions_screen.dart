import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../widgets/expense_tile.dart';
import '../widgets/category_grid.dart';
import '../utils/constants.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  Category? _selectedCategory;
  String _searchQuery = '';
  String _sortBy = 'date';
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    var expenses = ref.watch(expenseProvider).where((e) => !e.isUncategorized).toList();
    final settings = ref.watch(appSettingsProvider);

    if (_selectedCategory != null) {
      expenses = expenses.where((e) => e.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      expenses = expenses.where((e) => e.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
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
          // Date range picker
          IconButton(
            icon: Icon(
              Icons.date_range,
              color: _dateRange != null ? AppColors.primary : null,
            ),
            tooltip: 'Filter by date',
            onPressed: () async {
              HapticFeedback.lightImpact();
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: now,
                initialDateRange: _dateRange ?? DateTimeRange(
                  start: DateTime(now.year, now.month, 1),
                  end: now,
                ),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
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
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'date', child: Text('Sort by Date')),
              const PopupMenuItem(value: 'amount', child: Text('Sort by Amount')),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  const Icon(Icons.date_range, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('MMM d').format(_dateRange!.start)} – ${DateFormat('MMM d, yyyy').format(_dateRange!.end)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
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
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  onSelected: (_) { HapticFeedback.selectionClick(); setState(() => _selectedCategory = null); },
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
                      setState(() => _selectedCategory = v ? cat : null);
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
                final monthTotal = txns.fold(0.0, (a, b) => a + b.amount);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(month, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                      Text('${settings.currency}${NumberFormat('#,##0').format(monthTotal)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ]),
                  ),
                  const Divider(height: 1),
                  ...txns.map((e) => ExpenseTile(
                    expense: e,
                    onEdit: () => _showEditSheet(context, e),
                  )),
                ]);
              },
            ),
    );
  }

  Widget _buildEmpty() {
    final hasFilters = _selectedCategory != null || _searchQuery.isNotEmpty || _dateRange != null;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(
          hasFilters ? Icons.search_off_rounded : Icons.receipt_long_rounded,
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
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => _EditExpenseSheet(expense: expense),
    );
  }
}

class _EditExpenseSheet extends ConsumerStatefulWidget {
  final Expense expense;
  const _EditExpenseSheet({required this.expense});

  @override
  ConsumerState<_EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends ConsumerState<_EditExpenseSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late Category _selectedCategory;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.expense.amount.toStringAsFixed(2));
    _titleCtrl = TextEditingController(text: widget.expense.title);
    _noteCtrl = TextEditingController(text: widget.expense.note);
    _selectedCategory = widget.expense.category;
    _selectedDate = widget.expense.date;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Edit Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: '₹ ',
              labelText: 'Amount',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: 'Merchant / Title',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: 'Note (Optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          CategoryGrid(
            selectedCategory: _selectedCategory,
            onSelect: (c) { HapticFeedback.selectionClick(); setState(() => _selectedCategory = c); },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
            label: Text(
              DateFormat('dd MMM yyyy').format(_selectedDate),
              style: const TextStyle(color: AppColors.primary),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final dt = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (dt != null) {
                setState(() => _selectedDate = dt.copyWith(
                  hour: _selectedDate.hour, minute: _selectedDate.minute));
              }
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final amt = double.tryParse(_amountCtrl.text);
              final title = _titleCtrl.text.trim();
              if (amt == null || amt <= 0 || title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all required fields')),
                );
                return;
              }
              HapticFeedback.mediumImpact();
              final updated = Expense(
                id: widget.expense.id,
                title: title,
                amount: amt,
                category: _selectedCategory,
                date: _selectedDate,
                note: _noteCtrl.text,
                isManual: widget.expense.isManual,
                isUncategorized: false,
                source: widget.expense.source,
              );
              ref.read(expenseProvider.notifier).updateExpense(updated);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Expense updated ✓'),
                  backgroundColor: Colors.green.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}
