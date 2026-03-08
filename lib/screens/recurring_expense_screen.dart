import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/recurring_expense.dart';
import '../models/category.dart';
import '../providers/recurring_expense_provider.dart';
import '../utils/constants.dart';

class RecurringExpenseScreen extends ConsumerWidget {
  const RecurringExpenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recurringExpenseProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Recurring Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'recurring_fab',
        backgroundColor: Colors.purple.shade600,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _AddRecurringSheet(),
        ),
      ),
      body: items.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.repeat_rounded, size: 64, color: Colors.purple.shade200),
                const SizedBox(height: 16),
                Text('No recurring expenses yet',
                    style: TextStyle(fontSize: 16, color: isDark ? Colors.white60 : Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text('Add subscriptions, rent, EMIs & more',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey.shade400)),
              ]),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _RecurringTile(item: items[i]),
            ),
    );
  }
}

class _RecurringTile extends ConsumerWidget {
  final RecurringExpense item;
  const _RecurringTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final cardColor  = isDark ? AppColors.surfaceDark : Colors.white;
    final catColor   = item.category.color;
    final freqLabel  = {
      'daily': 'Daily',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
      'yearly': 'Yearly',
    }[item.frequency] ?? 'Monthly';

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isActive ? catColor.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: item.isActive ? catColor.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(item.category.icon, color: item.isActive ? catColor : Colors.grey, size: 20),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: item.isActive ? null : Colors.grey,
            decoration: item.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          '$freqLabel · Next: ${DateFormat('d MMM yyyy').format(item.nextDue)}',
          style: TextStyle(fontSize: 12, color: item.isActive ? Colors.grey : Colors.grey.shade400),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '₹${NumberFormat('#,##0').format(item.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: item.isActive ? Colors.purple.shade600 : Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'toggle') {
                ref.read(recurringExpenseProvider.notifier).toggleActive(item.id);
              } else if (v == 'delete') {
                _confirmDelete(context, ref);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'toggle',
                child: Row(children: [
                  Icon(item.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(item.isActive ? 'Pause' : 'Resume'),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Recurring Expense'),
        content: Text('Remove "${item.title}"? This won\'t delete past expenses.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(recurringExpenseProvider.notifier).delete(item.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _AddRecurringSheet extends ConsumerStatefulWidget {
  const _AddRecurringSheet();

  @override
  ConsumerState<_AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends ConsumerState<_AddRecurringSheet> {
  final _titleCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();
  Category _category = Category.bills;
  String _frequency  = 'monthly';
  DateTime _startDate = DateTime.now();
  bool _saving       = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title  = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid title and amount')),
      );
      return;
    }
    setState(() => _saving = true);
    final r = buildRecurring(
      title:     title,
      amount:    amount,
      category:  _category,
      frequency: _frequency,
      startDate: _startDate,
    );
    await ref.read(recurringExpenseProvider.notifier).add(r);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurring expense added')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('New Recurring Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Title
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: 'Title (e.g. Netflix, Rent)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 14),

          // Amount
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.currency_rupee),
            ),
          ),
          const SizedBox(height: 14),

          // Category
          const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: Category.values.map((cat) {
              final selected = cat == _category;
              return FilterChip(
                label: Text(cat.name),
                avatar: Icon(cat.icon, size: 16, color: selected ? Colors.white : cat.color),
                selected: selected,
                onSelected: (_) => setState(() => _category = cat),
                selectedColor: cat.color,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : null,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Frequency
          const Text('Frequency', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['daily', 'weekly', 'monthly', 'yearly'].map((f) {
              final label = f[0].toUpperCase() + f.substring(1);
              return ChoiceChip(
                label: Text(label),
                selected: _frequency == f,
                onSelected: (_) => setState(() => _frequency = f),
                selectedColor: Colors.purple.shade600,
                labelStyle: TextStyle(
                  color: _frequency == f ? Colors.white : null,
                  fontWeight: _frequency == f ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Start date
          Row(children: [
            const Text('Starts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            TextButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(DateFormat('d MMM yyyy').format(_startDate)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),
          ]),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}
