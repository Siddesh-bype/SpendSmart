import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/income.dart';
import '../providers/income_provider.dart';
import '../providers/app_settings_provider.dart';
import '../utils/design.dart';
import '../utils/theme.dart';
import '../utils/validation.dart';

class IncomeScreen extends ConsumerWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomes = ref.watch(incomeProvider);
    final settings = ref.watch(appSettingsProvider);
    final currency = settings.currency;

    // Group by month
    final Map<String, List<Income>> grouped = {};
    for (final inc in incomes) {
      final key = DateFormat('MMMM yyyy').format(inc.date);
      grouped.putIfAbsent(key, () => []).add(inc);
    }

    // Current month total
    final now = DateTime.now();
    final thisMonthKey = DateFormat('MMMM yyyy').format(now);
    final thisMonthTotal = (grouped[thisMonthKey] ?? []).fold(
      0.0,
      (s, i) => s + i.amount,
    );
    final scheme = SchemeTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Income',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Material(
              color: scheme.ctaFill,
              borderRadius: AppRadius.mdAll,
              child: InkWell(
                borderRadius: AppRadius.mdAll,
                onTap: () => _showAddSheet(context, ref),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 18, color: scheme.ctaText),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Add Income',
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
        ],
      ),
      body: Column(
        children: [
          // Summary card — solid surface + 1px border
          Container(
            margin: const EdgeInsets.all(AppSpacing.lg),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Month',
                      style: TextStyle(
                        color: scheme.muted,
                        fontSize: AppType.caption,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$currency${NumberFormat('#,##0').format(thisMonthTotal)}',
                      style: TextStyle(
                        color: scheme.ink,
                        fontSize: AppType.title,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.trending_up_rounded,
                  color: scheme.success,
                  size: 40,
                ),
              ],
            ),
          ),

          if (grouped.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 72,
                      color: scheme.muted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No income recorded',
                      style: TextStyle(
                        fontSize: AppType.headline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use Add Income to log your salary, freelance, or any income.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.muted,
                        fontSize: AppType.label,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: grouped.entries.map((entry) {
                  final monthTotal = entry.value.fold(
                    0.0,
                    (s, i) => s + i.amount,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Month header
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppType.label,
                                color: scheme.muted,
                              ),
                            ),
                            Text(
                              '$currency${NumberFormat('#,##0').format(monthTotal)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppType.label,
                                color: scheme.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: scheme.border),
                        ),
                        child: Column(
                          children: entry.value
                              .map(
                                (inc) => _IncomeTile(
                                  income: inc,
                                  currency: currency,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddIncomeSheet(ref: ref),
    );
  }
}

// ── Income tile ───────────────────────────────────────────────────────────────

class _IncomeTile extends ConsumerWidget {
  final Income income;
  final String currency;
  const _IncomeTile({required this.income, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = SchemeTheme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.success.withValues(alpha: 0.15),
        child: Icon(
          Icons.arrow_downward_rounded,
          color: scheme.success,
          size: 20,
        ),
      ),
      title: Text(
        income.source,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: AppType.body),
      ),
      subtitle: Text(
        '${DateFormat('d MMM y').format(income.date)}${income.note.isNotEmpty ? ' · ${income.note}' : ''}',
        style: TextStyle(fontSize: AppType.caption, color: scheme.muted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$currency${NumberFormat('#,##0').format(income.amount)}',
            style: TextStyle(
              color: scheme.success,
              fontWeight: FontWeight.bold,
              fontSize: AppType.body,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              ref.read(incomeProvider.notifier).deleteIncome(income.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Income entry deleted'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: Icon(Icons.close, size: 16, color: scheme.muted),
          ),
        ],
      ),
    );
  }
}

// ── Add income bottom sheet ───────────────────────────────────────────────────

class _AddIncomeSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddIncomeSheet({required this.ref});

  @override
  State<_AddIncomeSheet> createState() => _AddIncomeSheetState();
}

class _AddIncomeSheetState extends State<_AddIncomeSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _selectedSource = 'Salary';
  bool _saving = false;
  String? _error;
  static const _sources = [
    'Salary',
    'Freelance',
    'Business',
    'Investment',
    'Gift',
    'Other',
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parsePositiveAmount(_amountCtrl.text);
    if (amount == null) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.ref
          .read(incomeProvider.notifier)
          .addIncome(
            Income(
              id: const Uuid().v4(),
              amount: amount,
              source: _selectedSource,
              date: DateTime.now(),
              note: _noteCtrl.text.trim(),
            ),
          );
      if (mounted) Navigator.pop(context);
      HapticFeedback.mediumImpact();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save income. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = SchemeTheme.of(context);
    final currency = widget.ref.read(appSettingsProvider).currency;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text(
              'Log Income',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Source chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _sources.map((src) {
                final selected = _selectedSource == src;
                return ChoiceChip(
                  label: Text(src),
                  selected: selected,
                  selectedColor: scheme.ctaFill,
                  labelStyle: TextStyle(
                    color: selected ? scheme.ctaText : null,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _selectedSource = src),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Amount ($currency)',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: const Icon(Icons.note_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.ctaFill,
                  foregroundColor: scheme.ctaText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: AppType.headline, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
