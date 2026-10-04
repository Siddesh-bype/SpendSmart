import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/recurring_expense.dart';
import '../models/category.dart';
import '../providers/recurring_expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../utils/constants.dart';
import '../utils/design.dart';
import '../utils/theme.dart';
import '../utils/validation.dart';
import '../widgets/empty_state.dart';

class RecurringExpenseScreen extends ConsumerWidget {
  const RecurringExpenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recurringExpenseProvider);
    final scheme = SchemeTheme.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Recurring Expenses',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Center(
              child: Material(
                color: scheme.ctaFill,
                borderRadius: AppRadius.mdAll,
                child: InkWell(
                  borderRadius: AppRadius.mdAll,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const _AddRecurringSheet(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 18, color: scheme.ctaText),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: scheme.ctaText,
                            fontSize: AppType.body,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.repeat_rounded,
              title: 'No recurring expenses yet',
              subtitle: 'Add subscriptions, rent, EMIs & more',
              iconColor: scheme.primary.withValues(alpha: 0.5),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
    final currency = ref.watch(appSettingsProvider).currency;
    final scheme = SchemeTheme.of(context);
    final catColor = scheme.categoryColors[item.category.index];
    final freqLabel =
        {
          'daily': 'Daily',
          'weekly': 'Weekly',
          'monthly': 'Monthly',
          'yearly': 'Yearly',
        }[item.frequency] ??
        'Monthly';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isActive
              ? catColor.withValues(alpha: 0.3)
              : scheme.border,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: item.isActive
                ? catColor.withValues(alpha: 0.15)
                : scheme.muted.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            item.category.icon,
            color: item.isActive ? catColor : scheme.muted,
            size: 20,
          ),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: item.isActive ? scheme.ink : scheme.muted,
            decoration: item.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          '$freqLabel - Next: ${DateFormat('d MMM yyyy').format(item.nextDue)}${item.isActive ? '' : ' · Paused'}',
          style: TextStyle(
            fontSize: AppType.caption,
            color: item.isActive ? scheme.muted : scheme.muted.withValues(alpha: 0.7),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$currency${NumberFormat('#,##0').format(item.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppType.body,
                color: item.isActive ? scheme.ink : scheme.muted,
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'toggle') {
                  ref
                      .read(recurringExpenseProvider.notifier)
                      .toggleActive(item.id);
                } else if (v == 'delete') {
                  _confirmDelete(context, ref);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        item.isActive
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(item.isActive ? 'Pause' : 'Resume'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: scheme.error),
                      const SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: scheme.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final scheme = SchemeTheme.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Recurring Expense'),
        content: Text(
          'Remove "${item.title}"? This won\'t delete past expenses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(recurringExpenseProvider.notifier).delete(item.id);
            },
            child: Text('Delete', style: TextStyle(color: scheme.error)),
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

/// Frequency options: value → display label. Const so not rebuilt every frame.
const _kFrequencyLabels = <String, String>{
  'daily': 'Daily',
  'weekly': 'Weekly',
  'monthly': 'Monthly',
  'yearly': 'Yearly',
};

class _AddRecurringSheetState extends ConsumerState<_AddRecurringSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  Category _category = Category.bills;
  String _frequency = 'monthly';
  DateTime _startDate = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amount = parsePositiveAmount(_amountCtrl.text);
    if (title.isEmpty || amount == null) {
      setState(() => _error = 'Enter a valid title and amount');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final r = buildRecurring(
      title: title,
      amount: amount,
      category: _category,
      frequency: _frequency,
      startDate: _startDate,
    );
    await ref.read(recurringExpenseProvider.notifier).add(r);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recurring expense added')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = SchemeTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'New Recurring Expense',
              style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Title
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Title (e.g. Netflix, Rent)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 14),

            // Amount
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 14),

            // Category
            const Text(
              'Category',
              style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Category.values.map((cat) {
                final selected = cat == _category;
                final catColor = scheme.categoryColors[cat.index];
                return FilterChip(
                  label: Text(cat.displayName),
                  avatar: Icon(
                    cat.icon,
                    size: 16,
                    color: selected ? Scheme.onAvatar(catColor) : catColor,
                  ),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = cat),
                  selectedColor: catColor,
                  labelStyle: TextStyle(
                    color: selected ? Scheme.onAvatar(catColor) : null,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Frequency
            const Text(
              'Frequency',
              style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _kFrequencyLabels.entries.map((entry) {
                final selected = _frequency == entry.key;
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: selected,
                  onSelected: (_) => setState(() => _frequency = entry.key),
                  selectedColor: scheme.ctaFill,
                  labelStyle: TextStyle(
                    color: selected ? scheme.ctaText : null,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Start date
            Row(
              children: [
                const Text(
                  'Starts',
                  style: TextStyle(fontSize: AppType.label, fontWeight: FontWeight.w600),
                ),
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
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: scheme.error, fontSize: AppType.label),
              ),
            ],
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.ctaFill,
                  foregroundColor: scheme.ctaText,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.ctaText,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: AppType.headline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
