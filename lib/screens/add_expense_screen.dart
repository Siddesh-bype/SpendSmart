import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/lending.dart';
import '../providers/expense_provider.dart';
import '../providers/lending_provider.dart';
import '../providers/app_settings_provider.dart';
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
  final _friendNameCtrl = TextEditingController();
  final _splitAmountCtrl = TextEditingController();
  final _merchantFocusNode = FocusNode();
  Category? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  String _merchantText = '';
  bool _splitWithFriend = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _amountCtrl.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (_splitWithFriend) {
      final amt = double.tryParse(_amountCtrl.text);
      if (amt != null) {
        _splitAmountCtrl.text = (amt / 2).toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountChanged);
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _friendNameCtrl.dispose();
    _splitAmountCtrl.dispose();
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.accent : AppColors.primary;
    final labelColor = isDark ? Colors.white70 : Colors.black54;

    final allExpenses = ref.watch(expenseProvider);
    final settings = ref.watch(appSettingsProvider);
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
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                prefixText: '${settings.currency} ',
                prefixStyle: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                labelText: 'Amount',
                labelStyle: TextStyle(color: labelColor, fontSize: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : const Color(0xFFBBCDE0),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Merchant / Title with autocomplete
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _merchantText),
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return pastMerchants.take(8);
                }
                final query = textEditingValue.text.toLowerCase();
                return pastMerchants
                    .where((m) => m.toLowerCase().contains(query))
                    .take(8);
              },
              onSelected: (String selection) {
                setState(() => _merchantText = selection);
                final matchingExpense = allExpenses
                    .where((e) =>
                        e.title.toLowerCase() == selection.toLowerCase() &&
                        !e.isUncategorized)
                    .toList();
                if (matchingExpense.isNotEmpty && _selectedCategory == null) {
                  setState(() => _selectedCategory = matchingExpense.last.category);
                }
              },
              fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                if (controller.text != _merchantText && _merchantText.isNotEmpty) {
                  controller.text = _merchantText;
                }
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onEditingComplete: onEditingComplete,
                  onChanged: (v) => _merchantText = v,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Merchant / Title',
                    labelStyle: TextStyle(color: labelColor),
                    hintText: 'e.g. Swiggy, Petrol, Grocery',
                    hintStyle: TextStyle(color: labelColor.withValues(alpha: 0.7)),
                    suffixIcon: Icon(Icons.arrow_drop_down, color: primaryColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : const Color(0xFFBBCDE0),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2),
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
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (_, index) {
                          final option = options.elementAt(index);
                          final lastCat = allExpenses
                              .where((e) =>
                                  e.title.toLowerCase() == option.toLowerCase() &&
                                  !e.isUncategorized)
                              .toList();
                          final cat = lastCat.isNotEmpty ? lastCat.last.category : null;
                          return ListTile(
                            leading: cat != null
                                ? Icon(cat.icon, color: cat.color, size: 20)
                                : Icon(Icons.history,
                                    size: 20,
                                    color: isDark ? Colors.white54 : Colors.grey),
                            title: Text(
                              option,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            subtitle: cat != null
                                ? Text(cat.name,
                                    style: TextStyle(fontSize: 11, color: cat.color))
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
            Text(
              'Category',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            CategoryGrid(
              selectedCategory: _selectedCategory,
              onSelect: (c) => setState(() => _selectedCategory = c),
            ),
            const SizedBox(height: 24),

            // Date picker
            OutlinedButton.icon(
              icon: Icon(Icons.calendar_today, color: primaryColor),
              label: Text(
                DateFormat('dd/MM/yyyy').format(_selectedDate),
                style: TextStyle(color: primaryColor),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: primaryColor),
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
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                labelStyle: TextStyle(color: labelColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : const Color(0xFFBBCDE0),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Split with friend ──────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark
                    : AppColors.primary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _splitWithFriend
                      ? primaryColor
                      : (isDark ? Colors.white24 : const Color(0xFFBBCDE0)),
                  width: _splitWithFriend ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      'Split with friend',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      'Record this as a lending slip',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    secondary: Icon(Icons.people_alt_rounded, color: primaryColor),
                    value: _splitWithFriend,
                    activeThumbColor: primaryColor,
                    onChanged: (v) {
                      setState(() {
                        _splitWithFriend = v;
                        if (v) {
                          final amt = double.tryParse(_amountCtrl.text);
                          if (amt != null) {
                            _splitAmountCtrl.text = (amt / 2).toStringAsFixed(2);
                          }
                        }
                      });
                    },
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: _splitWithFriend
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              children: [
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _friendNameCtrl,
                                  style: TextStyle(color: theme.colorScheme.onSurface),
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    labelText: 'Friend\'s Name',
                                    labelStyle: TextStyle(color: labelColor),
                                    hintText: 'Who are you splitting with?',
                                    prefixIcon:
                                        Icon(Icons.person_outline, color: primaryColor),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : const Color(0xFFBBCDE0),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide:
                                          BorderSide(color: primaryColor, width: 2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _splitAmountCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(color: theme.colorScheme.onSurface),
                                  decoration: InputDecoration(
                                    labelText: 'Their share (${settings.currency})',
                                    labelStyle: TextStyle(color: labelColor),
                                    hintText: 'Amount friend owes you',
                                    prefixIcon:
                                        Icon(Icons.currency_rupee, color: primaryColor),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white24
                                            : const Color(0xFFBBCDE0),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide:
                                          BorderSide(color: primaryColor, width: 2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 14,
                                        color: isDark ? Colors.white38 : Colors.black38),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'A lending record will be created: friend owes you this amount',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            // ────────────────────────────────────────────────────────────────

            const SizedBox(height: 32),

            // Save button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final amt = double.tryParse(_amountCtrl.text);
                final title = _merchantText.trim();

                if (amt == null || amt <= 0 || title.isEmpty || _selectedCategory == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Please fill amount, merchant name, and select a category'),
                    ),
                  );
                  return;
                }

                // Validate split fields if enabled
                if (_splitWithFriend) {
                  final friendName = _friendNameCtrl.text.trim();
                  final splitAmt =
                      double.tryParse(_splitAmountCtrl.text);
                  if (friendName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter your friend\'s name')),
                    );
                    return;
                  }
                  if (splitAmt == null || splitAmt <= 0 || splitAmt > amt) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Split amount must be between 0 and the total')),
                    );
                    return;
                  }
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

                // Create lending slip if split is enabled
                if (_splitWithFriend) {
                  final friendName = _friendNameCtrl.text.trim();
                  final splitAmt =
                      double.tryParse(_splitAmountCtrl.text) ?? (amt / 2);
                  final lending = Lending(
                    id: const Uuid().v4(),
                    friendName: friendName,
                    amount: splitAmt,
                    isIGave: true,
                    date: _selectedDate,
                    note: 'Split from: $title',
                  );
                  ref.read(lendingProvider.notifier).addLending(lending);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Expense saved & slip added — $friendName owes you ${settings.currency}${splitAmt.toStringAsFixed(2)}'),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }

                Navigator.pop(context);
              },
              child: const Text('Save Expense',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
