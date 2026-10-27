import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../providers/expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/merchant_memory_provider.dart';
import '../providers/custom_category_provider.dart';
import '../widgets/category_grid.dart';
import '../utils/design.dart';
import '../utils/date_extension.dart';
import '../utils/theme.dart';
import '../utils/validation.dart';

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
  String? _selectedCustomCategoryId;
  late DateTime _selectedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.expense.amount.toStringAsFixed(2),
    );
    _titleCtrl = TextEditingController(text: widget.expense.title);
    _noteCtrl = TextEditingController(text: widget.expense.note ?? '');
    _selectedCategory = widget.expense.category;
    _selectedCustomCategoryId = widget.expense.customCategoryId;
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
    final currency = ref.watch(appSettingsProvider).currency;
    final theme = Theme.of(context);
    final scheme = SchemeTheme.of(context);
    final customCategories = ref
        .watch(customCategoryProvider)
        .where((category) => !category.archived)
        .toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Expense', style: theme.textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Amount
            TextField(
              controller: _amountCtrl,
              autofocus: true,
              textInputAction: TextInputAction.next,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: theme.textTheme.displaySmall?.copyWith(
                fontFeatures: AppType.tabular,
              ),
              decoration: InputDecoration(
                prefixText: '$currency ',
                labelText: 'Amount',
                border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide(color: scheme.focus, width: 2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Title
            TextField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Merchant / Title',
                border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide(color: scheme.focus, width: 2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Note
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Category
            Text('Category', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            CategoryGrid(
               selectedCategory: _selectedCustomCategoryId == null
                   ? _selectedCategory
                   : null,
               onSelect: (c) {
                 HapticFeedback.selectionClick();
                 setState(() {
                   _selectedCategory = c;
                   _selectedCustomCategoryId = null;
                 });
               },
             ),
             if (customCategories.isNotEmpty) ...[
               const SizedBox(height: AppSpacing.sm),
               Wrap(
                 spacing: AppSpacing.sm,
                 runSpacing: AppSpacing.xs,
                 children: [
                   for (final category in customCategories)
                     ChoiceChip(
                       avatar: Icon(category.icon, size: 16, color: category.color),
                       label: Text(category.name),
                       selected: _selectedCustomCategoryId == category.id,
                       onSelected: (selected) {
                         HapticFeedback.selectionClick();
                         setState(() {
                           _selectedCustomCategoryId = selected ? category.id : null;
                           if (selected) _selectedCategory = Category.other;
                         });
                       },
                     ),
                 ],
               ),
             ],
            const SizedBox(height: AppSpacing.sm),

            // Date
            OutlinedButton.icon(
              icon: Icon(Icons.calendar_today, size: 16, color: scheme.focus),
              label: Text(
                displayDateFormat.format(_selectedDate),
                style: TextStyle(color: scheme.primary),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.primary,
                side: BorderSide(color: scheme.primary),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
              ),
              onPressed: () async {
                final dt = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (dt != null && mounted) {
                  setState(
                    () => _selectedDate = dt.copyWith(
                      hour: _selectedDate.hour,
                      minute: _selectedDate.minute,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Save
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: scheme.ctaFill,
                foregroundColor: scheme.ctaText,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text('Save Changes', style: theme.textTheme.labelLarge),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final scheme = SchemeTheme.of(context);
    final amt = parsePositiveAmount(_amountCtrl.text);
    final title = _titleCtrl.text.trim();
    if (amt == null || amt <= 0 || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill amount and title')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final categoryChanged =
        _selectedCategory != widget.expense.category ||
        _selectedCustomCategoryId != widget.expense.customCategoryId;
    final updated = widget.expense.copyWith(
      title: title,
      amount: amt,
      category: _selectedCategory,
      customCategoryId: _selectedCustomCategoryId,
      clearCustomCategory: _selectedCustomCategoryId == null,
      date: _selectedDate,
      note: _noteCtrl.text,
      isUncategorized: false,
    );
    try {
      await ref.read(expenseProvider.notifier).updateExpense(updated);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update the expense. Try again.'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    if (categoryChanged && _selectedCustomCategoryId == null) {
      ref
          .read(merchantNotifierProvider.notifier)
          .correctMerchant(title, _selectedCategory);
    }
    // Capture messenger before pop — context invalid after pop
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Expense updated ✓'),
        backgroundColor: scheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
