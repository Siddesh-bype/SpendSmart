import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/income.dart';
import '../providers/income_provider.dart';
import '../providers/app_settings_provider.dart';

class IncomeScreen extends ConsumerWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomes  = ref.watch(incomeProvider);
    final currency = ref.watch(appSettingsProvider).currency;
    final now      = DateTime.now();

    // Monthly totals
    final thisMonthTotal = incomes
        .where((i) => i.date.month == now.month && i.date.year == now.year)
        .fold(0.0, (s, i) => s + i.amount);

    // Group by "MMMM yyyy"
    final Map<String, List<Income>> grouped = {};
    for (final i in incomes) {
      final key = DateFormat('MMMM yyyy').format(i.date);
      grouped.putIfAbsent(key, () => []).add(i);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Income', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        // Summary banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF43A047), Color(0xFF66BB6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('This Month', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                '$currency${NumberFormat('#,##0').format(thisMonthTotal)}',
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ]),
            const Icon(Icons.trending_up_rounded, color: Colors.white54, size: 40),
          ]),
        ),

        if (grouped.isEmpty)
          Expanded(
            child: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.account_balance_wallet_outlined, size: 72, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No income recorded', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Tap + to log your salary, freelance, or any income.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ]),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: grouped.entries.map((entry) {
                final monthTotal = entry.value.fold(0.0, (s, i) => s + i.amount);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Month header
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(entry.key,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey.shade500)),
                      Text('$currency${NumberFormat('#,##0').format(monthTotal)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.green.shade700)),
                    ]),
                  ),
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: entry.value.map((inc) => _IncomeTile(income: inc, currency: currency)).toList(),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: Colors.green.shade700,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Income',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green.withValues(alpha: 0.15),
        child: const Icon(Icons.arrow_downward_rounded, color: Colors.green, size: 20),
      ),
      title: Text(income.source,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(
        '${DateFormat('d MMM y').format(income.date)}${income.note.isNotEmpty ? ' · ${income.note}' : ''}',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          '$currency${NumberFormat('#,##0').format(income.amount)}',
          style: const TextStyle(
              color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          },
          child: const Icon(Icons.close, size: 16, color: Colors.grey),
        ),
      ]),
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
  final _noteCtrl   = TextEditingController();
  String _selectedSource = 'Salary';
  static const _sources = ['Salary', 'Freelance', 'Business', 'Investment', 'Gift', 'Other'];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    widget.ref.read(incomeProvider.notifier).addIncome(Income(
      id: const Uuid().v4(),
      amount: amount,
      source: _selectedSource,
      date: DateTime.now(),
      note: _noteCtrl.text.trim(),
    ));
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
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Log Income', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                selectedColor: Colors.green.shade700,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : null,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) => setState(() => _selectedSource = src),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Amount ($currency)',
              prefixIcon: const Icon(Icons.attach_money),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: const Icon(Icons.note_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}
