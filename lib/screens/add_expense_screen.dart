import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/lending.dart';
import '../models/custom_category.dart';
import '../providers/expense_provider.dart';
import '../providers/lending_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/merchant_memory_provider.dart';
import '../providers/custom_category_provider.dart';
import 'category_manager_screen.dart';
import '../services/category_classifier.dart';
import '../utils/design.dart';
import '../utils/theme.dart';
import '../utils/validation.dart';
import '../widgets/money_text.dart';

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
  final _categorySearchCtrl = TextEditingController();
  Category? _selectedCategory;
  String? _selectedCustomCategoryId;
  String _categoryQuery = '';
  DateTime _selectedDate = DateTime.now();
  String _merchantText = '';
  bool _splitWithFriend = false;
  bool _saving = false;

  /// Owned by [Autocomplete]; we only listen to it.
  FocusNode? _merchantFocusNode;

  List<Expense>? _merchantSource;
  List<String> _pastMerchants = const [];
  Map<String, Category> _merchantCategories = const {};

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
    _categorySearchCtrl.dispose();
    _merchantFocusNode?.removeListener(_onMerchantFocusChange);
    super.dispose();
  }

  /// Rebuilds the merchant index only when the expense list itself changes.
  void _syncMerchantIndex(List<Expense> expenses) {
    if (identical(_merchantSource, expenses)) return;
    _merchantSource = expenses;
    final seen = <String>{};
    final names = <String>[];
    final categories = <String, Category>{};
    for (final e in expenses) {
      final title = e.title.trim();
      if (title.isEmpty) continue;
      final key = title.toLowerCase();
      if (seen.add(key)) names.add(title);
      if (!e.isUncategorized) categories[key] = e.category;
    }
    _pastMerchants = names;
    _merchantCategories = categories;
  }

  void _bindMerchantFocus(FocusNode node) {
    if (identical(_merchantFocusNode, node)) return;
    _merchantFocusNode?.removeListener(_onMerchantFocusChange);
    _merchantFocusNode = node..addListener(_onMerchantFocusChange);
  }

  void _onMerchantFocusChange() {
    if (!mounted || (_merchantFocusNode?.hasFocus ?? true)) return;
    _suggestCategoryFor(_merchantText);
  }

  /// Pre-selects a category for [rawTitle]; never overrides a user's pick.
  void _suggestCategoryFor(String rawTitle) {
    if (_selectedCategory != null) return;
    final suggestion = _suggestionFor(rawTitle);
    if (suggestion == null) return;
    setState(() => _selectedCategory = suggestion);
  }

  /// Merchant-memory → merchant history → classifier suggestion chain.
  Category? _suggestionFor(String rawTitle) {
    final title = rawTitle.trim();
    if (title.isEmpty) return null;
    final memory = ref
        .read(merchantNotifierProvider.notifier)
        .lookupCategory(title);
    final suggestion =
        memory ?? _merchantCategories[title.toLowerCase()] ?? _confidentGuess(title);
    return suggestion;
  }

  Category? _confidentGuess(String title) {
    final result = CategoryClassifier.classify(title);
    return result.isConfident ? result.category : null;
  }

  InputDecoration _inputDecoration({
    required SchemeTheme scheme,
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    TextStyle? labelStyle,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: labelStyle ?? TextStyle(color: scheme.muted),
      hintText: hint,
      hintStyle: TextStyle(color: scheme.muted.withValues(alpha: 0.7)),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: scheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: scheme.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: scheme.focus, width: 2),
      ),
    );
  }

  Widget _buildCategoryPicker(
    BuildContext context,
    List<CustomCategory> customCategories,
    SchemeTheme scheme,
  ) {
    final query = _categoryQuery.trim().toLowerCase();
    final builtIns = Category.values
        .where((category) => category.displayName.toLowerCase().contains(query))
        .toList();
    final customs = customCategories
        .where((category) => category.name.toLowerCase().contains(query))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _categorySearchCtrl,
          onChanged: (value) => setState(() => _categoryQuery = value),
          decoration: _inputDecoration(
            scheme: scheme,
            label: 'Find a category',
            hint: 'Type and use backspace to correct',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _categoryQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear category search',
                    onPressed: () {
                      _categorySearchCtrl.clear();
                      setState(() => _categoryQuery = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (builtIns.isEmpty && customs.isEmpty)
          Text(
            'No matching categories. Add a custom category in Settings.',
            style: TextStyle(color: scheme.muted),
          )
        else
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              for (final category in builtIns)
                _categoryOption(
                  context,
                  name: category.displayName,
                  icon: category.icon,
                  color: scheme.categoryColors[category.index],
                  selected: _selectedCustomCategoryId == null &&
                      _selectedCategory == category,
                  onTap: () => setState(() {
                    _selectedCategory = category;
                    _selectedCustomCategoryId = null;
                  }),
                ),
              for (final category in customs)
                _categoryOption(
                  context,
                  name: category.name,
                  icon: category.icon,
                  color: category.color,
                  selected: _selectedCustomCategoryId == category.id,
                  onTap: () => setState(() {
                    _selectedCategory = Category.other;
                    _selectedCustomCategoryId = category.id;
                  }),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoryManagerScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add or combine categories'),
          ),
        ),
      ],
    );
  }

  Widget _categoryOption(
    BuildContext context, {
    required String name,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = SchemeTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppDuration.base),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : scheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: selected ? color : scheme.border, width: selected ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: AppSpacing.xs),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? color : scheme.ink,
                fontSize: AppType.caption,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = SchemeTheme.of(context);

    final settings = ref.watch(appSettingsProvider);
    _syncMerchantIndex(ref.watch(expenseProvider));
    final customCategories = ref
        .watch(customCategoryProvider)
        .where((category) => !category.archived)
        .toList();
    CustomCategory? selectedCustomCategory;
    for (final category in customCategories) {
      if (category.id == _selectedCustomCategoryId) {
        selectedCustomCategory = category;
        break;
      }
    }

    // Suggestion row is explicit-accept only and never an override.
    final suggestion = _suggestionFor(_merchantText);
    final showSuggestion =
        _selectedCustomCategoryId == null &&
        suggestion != null &&
        suggestion != _selectedCategory;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Expense',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Amount field
            TextField(
              controller: _amountCtrl,
              autofocus: true,
              textInputAction: TextInputAction.next,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                fontSize: AppType.display,
                fontWeight: FontWeight.bold,
                color: scheme.ink,
              ),
              decoration: _inputDecoration(
                scheme: scheme,
                label: 'Amount',
                labelStyle: TextStyle(
                  color: scheme.muted,
                  fontSize: AppType.headline,
                ),
              ).copyWith(
                prefixText: '${settings.currency} ',
                prefixStyle: TextStyle(
                  fontSize: AppType.display,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Merchant / Title with autocomplete
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _merchantText),
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _pastMerchants.take(8);
                }
                final query = textEditingValue.text.toLowerCase();
                return _pastMerchants
                    .where((m) => m.toLowerCase().contains(query))
                    .take(8);
              },
              onSelected: (String selection) {
                setState(() => _merchantText = selection);
                _suggestCategoryFor(selection);
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onEditingComplete) {
                    if (controller.text != _merchantText &&
                        _merchantText.isNotEmpty) {
                      controller.text = _merchantText;
                    }
                    _bindMerchantFocus(focusNode);
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onEditingComplete: onEditingComplete,
                      onChanged: (v) => setState(() => _merchantText = v),
                      textInputAction: TextInputAction.next,
                      style: TextStyle(color: scheme.ink),
                      decoration: _inputDecoration(
                        scheme: scheme,
                        label: 'Merchant / Title',
                        hint: 'e.g. Swiggy, Petrol, Grocery',
                        suffixIcon: Icon(
                          Icons.arrow_drop_down,
                          color: scheme.primary,
                        ),
                      ),
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 8,
                    borderRadius: AppRadius.mdAll,
                    color: scheme.surface,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (_, index) {
                          final option = options.elementAt(index);
                          final cat = _merchantCategories[option.toLowerCase()];
                          return ListTile(
                            leading: cat != null
                                ? Icon(
                                    cat.icon,
                                    color: scheme.categoryColors[cat.index],
                                    size: 20,
                                  )
                                : Icon(
                                    Icons.history,
                                    size: 20,
                                    color: scheme.muted,
                                  ),
                            title: Text(
                              option,
                              style: TextStyle(
                                fontSize: AppType.body,
                                color: scheme.ink,
                              ),
                            ),
                            subtitle: cat != null
                                ? Text(
                                    cat.displayName,
                                    style: TextStyle(
                                      fontSize: AppType.caption,
                                      color: scheme.categoryColors[cat.index],
                                    ),
                                  )
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

            // Explicit-accept suggestion row (merchant-memory / classifier).
            if (showSuggestion) ...[
              const SizedBox(height: AppSpacing.sm),
              Material(
                color: scheme.surface,
                borderRadius: AppRadius.mdAll,
                child: InkWell(
                  borderRadius: AppRadius.mdAll,
                   onTap: () => setState(() {
                     _selectedCategory = suggestion;
                     _selectedCustomCategoryId = null;
                   }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(color: scheme.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          suggestion.icon,
                          size: 18,
                          color: scheme.categoryColors[suggestion.index],
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Use ${suggestion.displayName} instead?',
                            style: TextStyle(
                              fontSize: AppType.body,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.north_east_rounded,
                          size: 16,
                          color: scheme.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
            Text(
              'Category',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppType.body,
                color: scheme.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
             if (_selectedCategory != null || _selectedCustomCategoryId != null)
               Semantics(
                 button: true,
                 label:
                     'Selected category, tap to clear',
                 child: SizedBox(
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                         avatar: Icon(
                          selectedCustomCategory == null
                              ? _selectedCategory!.icon
                              : selectedCustomCategory.icon,
                         size: 18,
                          color: selectedCustomCategory == null
                              ? scheme.categoryColors[_selectedCategory!.index]
                              : selectedCustomCategory.color,
                       ),
                       label: Text(
                          selectedCustomCategory == null
                              ? _selectedCategory!.displayName
                              : selectedCustomCategory.name,
                       ),
                      labelStyle: TextStyle(
                        fontSize: AppType.body,
                        fontWeight: FontWeight.w600,
                        color: scheme.ink,
                      ),
                      backgroundColor: scheme.surface,
                      side: BorderSide(
                          color: selectedCustomCategory == null
                              ? scheme.categoryColors[_selectedCategory!.index]
                              : selectedCustomCategory.color,
                        width: 1.5,
                      ),
                      deleteIcon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: scheme.muted,
                      ),
                      deleteButtonTooltipMessage: 'Clear category',
                      onDeleted: () => setState(() {
                        // Clearing re-arms suggestion; merchant text untouched.
                         _selectedCategory = null;
                         _selectedCustomCategoryId = null;
                       }),
                    ),
                  ),
                ),
              )
            else
               _buildCategoryPicker(context, customCategories, scheme),
            const SizedBox(height: AppSpacing.xl),

            // Date picker
            OutlinedButton.icon(
              icon: Icon(Icons.calendar_today, color: scheme.primary),
              label: Text(
                DateFormat('dd/MM/yyyy').format(_selectedDate),
                style: TextStyle(color: scheme.primary),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: scheme.border),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdAll,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                final dt = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (dt != null && mounted) setState(() => _selectedDate = dt);
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Note
            TextField(
              controller: _noteCtrl,
              textInputAction: TextInputAction.done,
              style: TextStyle(color: scheme.ink),
              decoration: _inputDecoration(
                scheme: scheme,
                label: 'Note (Optional)',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Material(
              color: scheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.mdAll,
                side: BorderSide(
                  color: _splitWithFriend ? scheme.primary : scheme.border,
                  width: _splitWithFriend ? 1.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(
                      'Split with friend',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.ink,
                      ),
                    ),
                    subtitle: Text(
                      'Record this as a lending slip',
                      style: TextStyle(
                        fontSize: AppType.caption,
                        color: scheme.muted,
                      ),
                    ),
                    secondary: Icon(
                      Icons.people_alt_rounded,
                      color: scheme.primary,
                    ),
                    value: _splitWithFriend,
                    activeThumbColor: scheme.primary,
                    onChanged: (v) {
                      setState(() {
                        _splitWithFriend = v;
                        if (v) {
                          final amt = double.tryParse(_amountCtrl.text);
                          if (amt != null) {
                            _splitAmountCtrl.text = (amt / 2).toStringAsFixed(
                              2,
                            );
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
                                Divider(height: 1, color: scheme.border),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _friendNameCtrl,
                                  style: TextStyle(color: scheme.ink),
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _inputDecoration(
                                    scheme: scheme,
                                    label: 'Friend\'s Name',
                                    hint: 'Who are you splitting with?',
                                    prefixIcon: Icon(
                                      Icons.person_outline,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _splitAmountCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  style: TextStyle(color: scheme.ink),
                                  decoration: _inputDecoration(
                                    scheme: scheme,
                                    label:
                                        'Their share (${settings.currency})',
                                    hint: 'Amount friend owes you',
                                    prefixIcon: Icon(
                                      Icons.currency_rupee,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: scheme.muted,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'A lending record will be created: friend owes you this amount',
                                        style: TextStyle(
                                          fontSize: AppType.caption,
                                          color: scheme.muted,
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

            const SizedBox(height: 32),

            // Save button (theme CTA pill)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: scheme.ctaFill,
                foregroundColor: scheme.ctaText,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdAll,
                ),
              ),
              onPressed: _saving
                  ? null
                  : () async {
                      final amt = parsePositiveAmount(_amountCtrl.text);
                      final title = _merchantText.trim();

                      if (amt == null ||
                          amt <= 0 ||
                          title.isEmpty ||
                           _selectedCategory == null &&
                           _selectedCustomCategoryId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please fill amount, merchant name, and select a category',
                              style: TextStyle(color: scheme.ctaText),
                            ),
                            backgroundColor: scheme.error,
                          ),
                        );
                        return;
                      }

                      // Validate and capture split values before any await —
                      // the fields stay editable while the save round-trips,
                      // so they must never be re-read (or force-unwrapped)
                      // afterwards.
                      final friendName = _splitWithFriend
                          ? _friendNameCtrl.text.trim()
                          : '';
                      final splitAmt = _splitWithFriend
                          ? parsePositiveAmount(_splitAmountCtrl.text)
                          : null;
                      if (_splitWithFriend) {
                        if (friendName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Please enter your friend\'s name',
                                style: TextStyle(color: scheme.ctaText),
                              ),
                              backgroundColor: scheme.error,
                            ),
                          );
                          return;
                        }
                        if (splitAmt == null ||
                            splitAmt <= 0 ||
                            splitAmt > amt) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Split amount must be between 0 and the total',
                                style: TextStyle(color: scheme.ctaText),
                              ),
                              backgroundColor: scheme.error,
                            ),
                          );
                          return;
                        }
                      }

                      final exp = Expense(
                        id: const Uuid().v4(),
                        title: title,
                        amount: amt,
                         category: _selectedCategory ?? Category.other,
                         customCategoryId: _selectedCustomCategoryId,
                        date: _selectedDate,
                        note: _noteCtrl.text,
                        isManual: true,
                        isUncategorized: false,
                        source: 'manual',
                      );

                      setState(() => _saving = true);
                      try {
                        await ref
                            .read(expenseProvider.notifier)
                            .addExpense(exp);
                        if (mounted && _selectedCustomCategoryId == null) {
                          ref
                              .read(merchantNotifierProvider.notifier)
                              .correctMerchant(title, exp.category);
                        }

                        if (_splitWithFriend && splitAmt != null) {
                          var slipFailed = false;
                          try {
                            await ref
                                .read(lendingProvider.notifier)
                                .addLending(
                                  Lending(
                                    id: const Uuid().v4(),
                                    friendName: friendName,
                                    amount: splitAmt,
                                    isIGave: true,
                                    date: _selectedDate,
                                    note: 'Split from: $title',
                                  ),
                                );
                          } catch (_) {
                            // The expense is already persisted; deleting it
                            // over a failed slip would silently lose data.
                            slipFailed = true;
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  slipFailed
                                      ? 'Expense saved, but the split slip '
                                          'could not be added'
                                      : 'Expense saved and slip added - '
                                          '$friendName owes you '
                                          '${settings.currency}'
                                          '${formatMoney(splitAmt, decimals: true)}',
                                  style: TextStyle(color: scheme.ctaText),
                                ),
                                backgroundColor: slipFailed
                                    ? scheme.warning
                                    : scheme.success,
                              ),
                            );
                          }
                        }
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not save the expense. Try again.',
                                style: TextStyle(color: scheme.ctaText),
                              ),
                              backgroundColor: scheme.error,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: _saving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save Expense',
                      style: const TextStyle(
                        fontSize: AppType.headline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
