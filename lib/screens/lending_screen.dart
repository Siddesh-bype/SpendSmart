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
      final path =
          await LendingPdfService.exportToPDF(lendings, currency: currency);
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      await OpenFilex.open(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF export failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lendings = ref.watch(lendingProvider);
    final settings = ref.watch(appSettingsProvider);
    final currency = settings.currency;
    final active = lendings.where((l) => !l.isSettled).toList();

    // Group by friend
    final Map<String, List<Lending>> byFriend = {};
    for (final l in active) {
      byFriend.putIfAbsent(l.friendName, () => []).add(l);
    }

    // Net per friend: positive = they owe me, negative = I owe them
    final Map<String, double> netBalance = {};
    for (final entry in byFriend.entries) {
      double net = 0;
      for (final l in entry.value) {
        net += l.isIGave ? l.amount : -l.amount;
      }
      netBalance[entry.key] = net;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends & Lending',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Export PDF',
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  onPressed: lendings.isEmpty
                      ? null
                      : () => _exportPDF(lendings, currency),
                ),
        ],
      ),
      body: Column(children: [
        // Summary banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryCol(
                  'Total Owed to You',
                  netBalance.values
                      .where((v) => v > 0)
                      .fold(0.0, (a, b) => a + b),
                  Colors.green.shade200,
                  currency,
                ),
                Container(width: 1, height: 40, color: Colors.white24),
                _summaryCol(
                  'You Owe Others',
                  netBalance.values
                      .where((v) => v < 0)
                      .fold(0.0, (a, b) => a + b.abs()),
                  Colors.red.shade200,
                  currency,
                ),
              ]),
        ),

        if (byFriend.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_alt_outlined,
                        size: 72, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('No active lendings',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Tap + to record money you gave or owe.',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13)),
                  ]),
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
                      borderRadius: BorderRadius.circular(14)),
                  child: ExpansionTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    leading: CircleAvatar(
                      backgroundColor: iOweThemMore
                          ? Colors.red.withValues(alpha: 0.15)
                          : Colors.green.withValues(alpha: 0.15),
                      child: Text(
                        name[0].toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: iOweThemMore ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      iOweThemMore
                          ? 'You owe $currency${NumberFormat('#,##0').format(net.abs())}'
                          : 'Owed to you $currency${NumberFormat('#,##0').format(net)}',
                      style: TextStyle(
                        color: iOweThemMore ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Record',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _summaryCol(
      String label, double amount, Color valueColor, String currency) {
    return Column(children: [
      Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 11)),
      const SizedBox(height: 4),
      Text(
        '$currency${NumberFormat('#,##0').format(amount)}',
        style: TextStyle(
            color: valueColor, fontSize: 20, fontWeight: FontWeight.bold),
      ),
    ]);
  }

  Widget _lendingTile(
      BuildContext context, Lending l, String currency) {
    return ListTile(
      dense: true,
      leading: Icon(
        l.isIGave ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        color: l.isIGave ? Colors.green : Colors.red,
        size: 20,
      ),
      title: Text(
        l.isIGave
            ? 'You gave $currency${NumberFormat('#,##0').format(l.amount)}'
            : 'You owe $currency${NumberFormat('#,##0').format(l.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: l.isIGave ? Colors.green : Colors.red,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        '${DateFormat('d MMM y').format(l.date)}${l.note.isNotEmpty ? ' · ${l.note}' : ''}',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),
      trailing: TextButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          ref.read(lendingProvider.notifier).settle(l.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Marked as settled ✓'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
        child: const Text('Settle', style: TextStyle(fontSize: 12)),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
  final _nameCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();
  bool _iGave = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name   = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (name.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid name and amount')),
      );
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
    widget.ref.read(lendingProvider.notifier).addLending(lending);
    Navigator.pop(context);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final currency = widget.ref.read(appSettingsProvider).currency;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
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
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text('Record Lending',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Type toggle
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _iGave = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _iGave
                            ? Colors.green
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(12)),
                      ),
                      child: Center(
                        child: Text(
                          'I Gave',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _iGave
                                ? Colors.white
                                : theme.colorScheme.onSurface,
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
                        color: !_iGave
                            ? Colors.red
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(12)),
                      ),
                      child: Center(
                        child: Text(
                          'I Owe',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_iGave
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Friend\'s Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount ($currency)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: const Icon(Icons.note_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
      ),
    );
  }
}
