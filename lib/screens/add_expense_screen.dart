import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../providers/expense_provider.dart';
import '../widgets/category_grid.dart';
import '../utils/constants.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final Category? initialCategory;
  const AddExpenseScreen({super.key, this.initialCategory});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _merchantFocusNode = FocusNode();
  Category? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  String _merchantText = '';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _merchantFocusNode.dispose();
    super.dispose();
  }

  List<String> _getPastMerchants(List<Expense> expenses) {
    final seen = <String>{};
    final result = <String>[];
    for (final e in expenses) {
      final t = e.title.trim();
      if (t.isNotEmpty && seen.add(t.toLowerCase())) {
        result.add(t);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final allExpenses = ref.watch(expenseProvider);
    final pastMerchants = _getPastMerchants(allExpenses);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Amount field
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
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
            const SizedBox(height: 16),

            // Merchant / Title with autocomplete
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _merchantText),
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  // Show all recent merchants when field is focused but empty
                  return pastMerchants.take(8);
                }
                final query = textEditingValue.text.toLowerCase();
                return pastMerchants
                    .where((m) => m.toLowerCase().contains(query))
                    .take(8);
              },
              onSelected: (String selection) {
                setState(() => _merchantText = selection);
                // Auto-select category based on past use of this merchant
                final matchingExpense = allExpenses
                    .where((e) => e.title.toLowerCase() == selection.toLowerCase() && !e.isUncategorized)
                    .toList();
                if (matchingExpense.isNotEmpty && _selectedCategory == null) {
                  setState(() => _selectedCategory = matchingExpense.last.category);
                }
              },
              fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                // Sync any pre-selected text
                if (controller.text != _merchantText && _merchantText.isNotEmpty) {
                  controller.text = _merchantText;
                }
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onEditingComplete: onEditingComplete,
                  onChanged: (v) => _merchantText = v,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Merchant / Title',
                    hintText: 'e.g. Swiggy, Petrol, Grocery',
                    suffixIcon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (_, index) {
                          final option = options.elementAt(index);
                          // Find last used category for this merchant
                          final lastCat = allExpenses
                              .where((e) => e.title.toLowerCase() == option.toLowerCase() && !e.isUncategorized)
                              .toList();
                          final cat = lastCat.isNotEmpty ? lastCat.last.category : null;
                          return ListTile(
                            leading: cat != null
                                ? Icon(cat.icon, color: cat.color, size: 20)
                                : const Icon(Icons.history, size: 20, color: Colors.grey),
                            title: Text(option, style: const TextStyle(fontSize: 14)),
                            subtitle: cat != null
                                ? Text(cat.name, style: TextStyle(fontSize: 11, color: cat.color))
                                : null,
                            onTap: () => onSelected(option),
                            dense: true,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            CategoryGrid(
              selectedCategory: _selectedCategory,
              onSelect: (c) => setState(() => _selectedCategory = c),
            ),
            const SizedBox(height: 24),

            // Date picker
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, color: AppColors.primary),
              label: Text(
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                style: const TextStyle(color: AppColors.primary),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                final dt = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (dt != null) setState(() => _selectedDate = dt);
              },
            ),
            const SizedBox(height: 16),

            // Note
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final amt = double.tryParse(_amountCtrl.text);
                final title = _merchantText.trim();

                if (amt == null || amt <= 0 || title.isEmpty || _selectedCategory == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill amount, merchant name, and select a category')),
                  );
                  return;
                }

                final exp = Expense(
                  id: const Uuid().v4(),
                  title: title,
                  amount: amt,
                  category: _selectedCategory!,
                  date: _selectedDate,
                  note: _noteCtrl.text,
                  isManual: true,
                  isUncategorized: false,
                  source: 'manual',
                );

                ref.read(expenseProvider.notifier).addExpense(exp);
                Navigator.pop(context);
              },
              child: const Text('Save Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
