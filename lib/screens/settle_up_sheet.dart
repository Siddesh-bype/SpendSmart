import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_expense.dart';
import '../models/split_group.dart';
import '../providers/group_expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../utils/theme.dart';
import '../utils/design.dart';

class SettleUpSheet extends ConsumerStatefulWidget {
  final GroupExpense expense;
  final SplitGroup group;

  const SettleUpSheet({super.key, required this.expense, required this.group});

  @override
  ConsumerState<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends ConsumerState<SettleUpSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _settle() async {
    if (_saving || widget.expense.isSettled) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(groupExpenseProvider.notifier)
          .settleExpense(widget.expense.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        const SnackBar(content: Text('Marked as settled')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not settle this expense. Try again.';
      });
    }
  }

  String _participantName(String id) {
    final match = widget.group.participants
        .where((p) => p.id == id)
        .firstOrNull;
    return match?.name ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    final theme = Theme.of(context);
    final scheme = SchemeTheme.of(context);
    final currency = ref.watch(appSettingsProvider).currency;
    final paidByName = _participantName(expense.paidBy);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
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
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: scheme.primary,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Settle Expense',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  expense.description,
                  style: TextStyle(color: scheme.muted, fontSize: AppType.body),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '$currency${expense.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: AppType.display,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Paid by $paidByName',
                  style: TextStyle(
                    color: scheme.muted,
                    fontSize: AppType.label,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: scheme.error)),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving || expense.isSettled ? null : _settle,
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.ctaFill,
                foregroundColor: scheme.ctaText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _saving
                    ? 'Saving…'
                    : (expense.isSettled
                          ? 'Already settled'
                          : 'Mark as Settled'),
                style: const TextStyle(
                  fontSize: AppType.headline,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
