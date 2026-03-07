import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_settings_provider.dart';
import '../providers/expense_provider.dart';
import '../models/category.dart';
import '../utils/constants.dart';
import '../utils/date_extension.dart';

class SummaryCard extends ConsumerWidget {
  const SummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseProvider);
    final settings = ref.watch(appSettingsProvider);
    
    final cur = settings.currency;
    final budget = settings.monthlyBudget;
    
    final now = DateTime.now();
    
    final monthlyExpenses = expenses.where((e) => e.date.isTargetCustomMonth(now.month, now.year, settings.startingDayOfMonth) && e.category != Category.other).toList();
    final totalSpent = monthlyExpenses.fold(0.0, (sum, item) => sum + item.amount);
    
    final remaining = budget - totalSpent;
    final progress = budget > 0 ? (totalSpent / budget).clamp(0.0, 1.0) : 0.0;

    return Card(
      color: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.cardRadius)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Spent', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 5),
                    Text('$cur${totalSpent.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 60,
                      width: 60,
                      child: CircularProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        color: Colors.white,
                        strokeWidth: 6,
                      ),
                    ),
                    Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSubValue('Budget', '$cur${budget.toStringAsFixed(2)}'),
                _buildSubValue('Remaining', '$cur${remaining.toStringAsFixed(2)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
