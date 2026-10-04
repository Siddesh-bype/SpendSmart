import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:uuid/uuid.dart';
import '../models/lending.dart';
import '../providers/lending_provider.dart';
import '../providers/app_settings_provider.dart';
import '../services/lending_pdf_service.dart';
import '../utils/constants.dart';
import '../utils/design.dart';
import '../utils/theme.dart';
import '../utils/validation.dart';

class LendingScreen extends ConsumerStatefulWidget {
  const LendingScreen({super.key});

  @override
  ConsumerState<LendingScreen> createState() => _LendingScreenState();
}

class _LendingScreenState extends ConsumerState<LendingScreen> {
  bool _exporting = false;

  Future<void> _exportPDF(List<Lending> lendings, String currency) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating PDF…'),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
    try {
      final path = await LendingPdfService.exportToPDF(
        lendings,
        currency: currency,
      );
      setState(() => _exporting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF exported successfully'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OPEN',
            textColor: SchemeTheme.of(context).primary,
            onPressed: () => OpenFilex.open(path),
          ),
        ),
      );
    } catch (_) {
      setState(() => _exporting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to generate PDF'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lendings = ref.watch(lendingProvider);
    final settings = ref.watch(appSettingsProvider);
    final currency = settings.currency;

    // Group by friend
    final Map<String, List<Lending>> byFriend = {};
    for (final l in lendings) {
      byFriend.putIfAbsent(l.friendName, () => []).add(l);
    }

    // Net balance per friend: positive = they owe me, negative = I owe them
    final Map<String, double> netBalance = {};
    for (final entry in byFriend.entries) {
      double net = 0;
      for (final l in entry.value) {
        net += l.isIGave ? l.amount : -l.amount;
      }
      netBalance[entry.key] = net;
    }

    final scheme = SchemeTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lend & Borrow',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  tooltip: 'Export PDF',
                  onPressed: lendings.isEmpty
                      ? null
                      : () => _exportPDF(lendings, currency),
                ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Center(
              child: Material(
                color: scheme.ctaFill,
                borderRadius: AppRadius.mdAll,
                child: InkWell(
                  borderRadius: AppRadius.mdAll,
                  onTap: () => _showAddSheet(context),
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
                          'Record',
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
      body: Column(
        children: [
          // Summary card — solid surface + 1px border
          Container(
            margin: const EdgeInsets.all(AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _summaryCol(
                    'Total Owed to You',
                    netBalance.values
                        .where((v) => v > 0)
                        .fold(0.0, (a, b) => a + b),
                    scheme.success,
                    currency,
                    scheme,
                  ),
                ),
                Container(width: 1, height: 40, color: scheme.border),
                Expanded(
                  child: _summaryCol(
                    'You Owe Others',
                    netBalance.values
                        .where((v) => v < 0)
                        .fold(0.0, (a, b) => a + b.abs()),
                    scheme.error,
                    currency,
                    scheme,
                  ),
                ),
              ],
            ),
          ),

          if (byFriend.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 72,
                      color: scheme.muted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No active lendings',
                      style: TextStyle(
                        fontSize: AppType.headline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use Record to log money you gave or owe.',
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
                children: netBalance.entries.map((entry) {
                  final name = entry.key;
                  final net = entry.value;
                  final iOweThemMore = net < 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: scheme.border),
                    ),
                    child: ExpansionTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: iOweThemMore
                            ? scheme.error.withValues(alpha: 0.15)
                            : scheme.success.withValues(alpha: 0.15),
                        child: Text(
                          name[0].toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: iOweThemMore ? scheme.error : scheme.success,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        iOweThemMore
                            ? 'You owe $currency${NumberFormat('#,##0').format(net.abs())}'
                            : 'Owed to you $currency${NumberFormat('#,##0').format(net)}',
                        style: TextStyle(
                          color: iOweThemMore ? scheme.error : scheme.success,
                          fontWeight: FontWeight.w600,
                          fontSize: AppType.label,
                        ),
                      ),
                      children: byFriend[name]!
                          .map((l) => _lendingTile(context, l, currency))
                          .toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryCol(
    String label,
    double amount,
    Color valueColor,
    String currency,
    SchemeTheme scheme,
  ) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.muted, fontSize: AppType.caption),
        ),
        const SizedBox(height: 4),
        Text(
          '$currency${NumberFormat('#,##0').format(amount)}',
          style: TextStyle(
            color: valueColor,
            fontSize: AppType.title,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _lendingTile(BuildContext context, Lending l, String currency) {
    final scheme = SchemeTheme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(
        l.isIGave ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        color: l.isIGave ? scheme.success : scheme.error,
        size: 20,
      ),
      title: Text(
        l.isIGave
            ? 'You gave $currency${NumberFormat('#,##0').format(l.amount)}'
            : 'You owe $currency${NumberFormat('#,##0').format(l.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: l.isIGave ? scheme.success : scheme.error,
          fontSize: AppType.label,
        ),
      ),
      subtitle: Text(
        '${DateFormat('d MMM y').format(l.date)}${l.note.isNotEmpty ? ' · ${l.note}' : ''}',
        style: TextStyle(fontSize: AppType.caption, color: scheme.muted),
      ),
      trailing: TextButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          ref.read(lendingProvider.notifier).settle(l.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Marked as settled'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
        child: Text(
          'Settle',
          style: TextStyle(fontSize: AppType.caption, color: scheme.primary),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddLendingSheet(ref: ref),
    );
  }
}

// ── Add lending bottom sheet ───────────────────────────────────────────────────

class _AddLendingSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddLendingSheet({required this.ref});

  @override
  State<_AddLendingSheet> createState() => _AddLendingSheetState();
}

class _AddLendingSheetState extends State<_AddLendingSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _iGave = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = parsePositiveAmount(_amountCtrl.text);
    if (name.isEmpty || amount == null) {
      setState(() => _error = 'Please enter a valid name and amount');
      return;
    }
    final lending = Lending(
      id: const Uuid().v4(),
      friendName: name,
      amount: amount,
      isIGave: _iGave,
      date: DateTime.now(),
      note: _noteCtrl.text.trim(),
    );
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.ref.read(lendingProvider.notifier).addLending(lending);
      if (mounted) Navigator.pop(context);
      HapticFeedback.mediumImpact();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this lending entry. Try again.'),
          ),
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
              'Record Lending',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Type toggle
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _iGave = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _iGave ? scheme.success : scheme.elevated,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'I Gave',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _iGave ? Scheme.onAvatar(scheme.success) : scheme.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _iGave = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_iGave ? scheme.error : scheme.elevated,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'I Owe',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_iGave ? Scheme.onAvatar(scheme.error) : scheme.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Friend\'s Name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
