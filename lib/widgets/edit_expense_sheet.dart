import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../providers/expense_provider.dart';
import '../widgets/category_grid.dart';
import '../utils/constants.dart';

/// Shared edit bottom sheet used by both HomeScreen and TransactionsScreen
class EditExpenseSheet extends ConsumerStatefulWidget {
  final Expense expense;
  const EditExpenseSheet({super.key, required this.expense});

  @override
  ConsumerState<EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends ConsumerState<EditExpenseSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late Category _selectedCategory;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.expense.amount.toStringAsFixed(2));
    _titleCtrl = TextEditingController(text: widget.expense.title);
    _noteCtrl  = TextEditingController(text: widget.expense.note ?? '');
    _selectedCategory = widget.expense.category;
    _selectedDate     = widget.expense.date;
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
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Edit Expense',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          const SizedBox(height: 12),

          // Amount
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
                borderSide: const BorderSide(color: AppColors.secondary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Title
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: 'Merchant / Title',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.secondary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Note
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: 'Note (Optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),

          // Category
          const Text('Category',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          CategoryGrid(
            selectedCategory: _selectedCategory,
            onSelect: (c) {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = c);
            },
          ),
          const SizedBox(height: 10),

          // Date
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today,
                size: 16, color: AppColors.secondary),
            label: Text(
              DateFormat('dd MMM yyyy').format(_selectedDate),
              style: const TextStyle(color: AppColors.secondary),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.secondary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
                    hour: _selectedDate.hour,
                    minute: _selectedDate.minute));
              }
            },
          ),
          const SizedBox(height: 20),

          // Save
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _save,
            child: const Text('Save Changes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  void _save() {
    final amt = double.tryParse(_amountCtrl.text);
    final title = _titleCtrl.text.trim();
    if (amt == null || amt <= 0 || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill amount and title')));
      return;
    }
    HapticFeedback.mediumImpact();
    final updated = widget.expense.copyWith(
      title: title,
      amount: amt,
      category: _selectedCategory,
      date: _selectedDate,
      note: _noteCtrl.text,
      isUncategorized: false,
    );
    ref.read(expenseProvider.notifier).updateExpense(updated);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Expense updated ✓'),
      backgroundColor: Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }
}
