import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/split_group.dart';
import '../models/group_expense.dart';
import '../providers/group_expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../utils/design.dart';
import '../utils/validation.dart';

class AddGroupExpenseSheet extends ConsumerStatefulWidget {
  final SplitGroup group;

  const AddGroupExpenseSheet({super.key, required this.group});

  @override
  ConsumerState<AddGroupExpenseSheet> createState() =>
      _AddGroupExpenseSheetState();
}

class _AddGroupExpenseSheetState extends ConsumerState<AddGroupExpenseSheet> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _uuid = const Uuid();

  late String _paidBy;
  bool _equalSplit = true;
  late DateTime _date;
  late Map<String, TextEditingController> _shareCtrls;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _paidBy = widget.group.participants.first.id;
    _date = DateTime.now();
    _shareCtrls = {
      for (final p in widget.group.participants) p.id: TextEditingController(),
    };
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    for (final c in _shareCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onAmountChanged() {
    if (!_equalSplit) return;
    final amount = parsePositiveAmount(_amountCtrl.text) ?? 0;
    if (amount > 0 && widget.group.participants.isNotEmpty) {
      final share = amount / widget.group.participants.length;
      for (final c in _shareCtrls.values) {
        c.text = share.toStringAsFixed(2);
      }
    }
  }

  double get _totalShares {
    double total = 0;
    for (final c in _shareCtrls.values) {
      total += double.tryParse(c.text.trim()) ?? 0;
    }
    return total;
  }

  Future<void> _save() async {
    final desc = _descCtrl.text.trim();
    final amount = parsePositiveAmount(_amountCtrl.text);
    if (desc.isEmpty || amount == null) {
      setState(() => _errorMessage = 'Please enter a valid description and amount');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid description and amount'),
        ),
      );
      return;
    }

    final shares = widget.group.participants.map((p) {
      return ParticipantShare(
        participantId: p.id,
        amount: parsePositiveAmount(_shareCtrls[p.id]!.text) ?? 0,
      );
    }).toList();

    if (shares.any((share) => share.amount <= 0)) {
      setState(() => _errorMessage = 'Every participant share must be greater than zero');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Every participant share must be greater than zero'),
        ),
      );
      return;
    }

    final diff = (amount - _totalShares).abs();
    if (diff > 0.02) {
      setState(() => _errorMessage =
          'Shares must sum to total (difference: ${diff.toStringAsFixed(2)})');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Shares must sum to total (difference: ${diff.toStringAsFixed(2)})',
          ),
        ),
      );
      return;
    }

    final expense = GroupExpense(
      id: _uuid.v4(),
      groupId: widget.group.id,
      description: desc,
      totalAmount: amount,
      paidBy: _paidBy,
      shares: shares,
      date: _date,
      note: _noteCtrl.text.trim(),
    );

    try {
      await ref.read(groupExpenseProvider.notifier).addExpense(expense);
      if (mounted) Navigator.pop(context);
      HapticFeedback.mediumImpact();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the group expense. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = SchemeTheme.of(context);
    final currency = ref.watch(appSettingsProvider).currency;
    final currencySymbol = currency.isNotEmpty ? currency : '\$';

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
              'Add Expense',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Dinner at restaurant',
                prefixIcon: const Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _onAmountChanged(),
              decoration: InputDecoration(
                labelText: 'Amount ($currencySymbol)',
                prefixIcon: const Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _paidBy,
              decoration: InputDecoration(
                labelText: 'Paid by',
                prefixIcon: const Icon(Icons.person_outline),
              ),
              items: widget.group.participants.map((p) {
                return DropdownMenuItem(value: p.id, child: Text(p.name));
              }).toList(),
              onChanged: (v) => setState(() => _paidBy = v!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _equalSplit = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _equalSplit
                            ? scheme.ctaFill
                            : scheme.tint,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Equal Split',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _equalSplit
                                ? scheme.ctaText
                                : scheme.ink,
                            fontSize: AppType.label,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _equalSplit = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_equalSplit
                            ? scheme.ctaFill
                            : scheme.tint,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Custom',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_equalSplit
                                ? scheme.ctaText
                                : scheme.ink,
                            fontSize: AppType.label,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...widget.group.participants.map((p) {
              final color = Color(p.avatarColorValue);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: color,
                      child: Text(
                        p.name[0].toUpperCase(),
                        style: TextStyle(
                          color: Scheme.onAvatar(color),
                          fontWeight: FontWeight.bold,
                          fontSize: AppType.caption,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _shareCtrls[p.id],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        readOnly: _equalSplit,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: AppType.body),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (!_equalSplit)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Total: $currencySymbol${_totalShares.toStringAsFixed(2)} / $currencySymbol${double.tryParse(_amountCtrl.text.trim()) ?? 0}',
                  style: TextStyle(
                    fontSize: AppType.caption,
                    color:
                        (_totalShares -
                                    (double.tryParse(_amountCtrl.text.trim()) ??
                                        0))
                                .abs() <
                            0.02
                        ? scheme.success
                        : scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: const Icon(Icons.note_outlined),
              ),
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: TextStyle(color: scheme.error, fontSize: AppType.label),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.ctaFill,
                  foregroundColor: scheme.ctaText,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdAll,
                  ),
                ),
                child: const Text(
                  'Add Expense',
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
