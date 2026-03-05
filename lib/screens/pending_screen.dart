import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../utils/constants.dart';

class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(expenseProvider).where((e) => e.isUncategorized).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Categorization', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: pending.isEmpty
          ? const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text('All caught up!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('No pending transactions to categorize.', style: TextStyle(color: Colors.grey)),
              ]),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${pending.length} transaction${pending.length > 1 ? 's' : ''} need${pending.length == 1 ? 's' : ''} categorization. Swipe or tap to assign.',
                        style: const TextStyle(color: Colors.orange, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: pending.length,
                  itemBuilder: (_, i) => _PendingTile(expense: pending[i]),
                ),
              ),
            ]),
    );
  }
}

class _PendingTile extends ConsumerWidget {
  final Expense expense;
  const _PendingTile({required this.expense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            Text('₹${NumberFormat('#,##0.##').format(expense.amount)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)),
          ]),
          const SizedBox(height: 4),
          Text(DateFormat('MMM dd, yyyy  hh:mm a').format(expense.date),
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          const Text('Select Category:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8,
            children: Category.values.map((cat) => GestureDetector(
              onTap: () {
                ref.read(expenseProvider.notifier).categorizeExpense(expense.id, cat);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${expense.title} → ${cat.name}'), duration: const Duration(seconds: 2)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cat.color.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(cat.icon, size: 14, color: cat.color),
                  const SizedBox(width: 5),
                  Text(cat.name, style: TextStyle(color: cat.color, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            )).toList(),
          ),
        ]),
      ),
    );
  }
}
