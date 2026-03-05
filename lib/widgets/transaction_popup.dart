import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../providers/expense_provider.dart';
import '../providers/merchant_memory_provider.dart';
import 'category_grid.dart';
import '../utils/constants.dart';

class TransactionPopup extends ConsumerStatefulWidget {
  final Expense expense;

  const TransactionPopup({super.key, required this.expense});

  @override
  ConsumerState<TransactionPopup> createState() => _TransactionPopupState();

  static void show(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: TransactionPopup(expense: expense),
      ),
    );
  }
}

class _TransactionPopupState extends ConsumerState<TransactionPopup> {
  Category? _selectedCategory;
  bool _rememberMerchant = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight, // Fallback, theme should handle this
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'New Transaction Detected',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            '₹${widget.expense.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'at ${widget.expense.title}',
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          Text(
            DateFormat('EEEE, MMM dd • hh:mm a').format(widget.expense.date),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Text('Select Category', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          CategoryGrid(
            selectedCategory: _selectedCategory,
            onSelect: (cat) => setState(() => _selectedCategory = cat),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Remember for next time'),
            value: _rememberMerchant,
            onChanged: (val) => setState(() => _rememberMerchant = val),
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Skip creates it as uncategorized with 'other' category
                    widget.expense.category = Category.other;
                    widget.expense.isUncategorized = true;
                    ref.read(expenseProvider.notifier).updateExpense(widget.expense);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedCategory == null
                      ? null
                      : () {
                          widget.expense.category = _selectedCategory!;
                          widget.expense.isUncategorized = false;
                          
                          if (_rememberMerchant) {
                            ref.read(merchantNotifierProvider.notifier).saveMerchant(widget.expense.title, _selectedCategory!);
                          }
                          
                          ref.read(expenseProvider.notifier).updateExpense(widget.expense);
                          Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
