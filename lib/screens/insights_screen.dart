import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/category.dart';
import '../utils/date_extension.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseProvider).where((e) => !e.isUncategorized).toList();
    final budgets = ref.watch(budgetProvider);
    final settings = ref.watch(appSettingsProvider);
    final now = DateTime.now();

    final thisMonth = expenses.where(
      (e) => e.date.isTargetCustomMonth(now.month, now.year, settings.startingDayOfMonth),
    ).toList();
    
    final lmDate = DateTime(now.year, now.month - 1);
    final lastMonth = expenses.where(
      (e) => e.date.isTargetCustomMonth(lmDate.month, lmDate.year, settings.startingDayOfMonth),
    ).toList();

    final thisTotal = thisMonth.fold(0.0, (a, b) => a + b.amount);
    final lastTotal = lastMonth.fold(0.0, (a, b) => a + b.amount);
    final change = lastTotal > 0 ? ((thisTotal - lastTotal) / lastTotal * 100) : 0.0;

    // Category breakdown this month
    final catSums = <Category, double>{};
    for (final e in thisMonth) {
      catSums[e.category] = (catSums[e.category] ?? 0) + e.amount;
    }
    final topCat = catSums.entries.isEmpty ? null :
        catSums.entries.reduce((a, b) => a.value > b.value ? a : b);

    // Recurring expenses
    final recurring = _detectRecurring(expenses);

    // Insights list
    final insights = _generateInsights(thisTotal, lastTotal, change, catSums, budgets, settings, topCat, recurring);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Insights', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: expenses.isEmpty
          ? const Center(child: Text('Add some expenses to see insights!', style: TextStyle(color: Colors.grey)))
          : ListView(padding: const EdgeInsets.all(16), children: [
              // Month comparison card
              _comparisonCard(thisTotal, lastTotal, change, settings.currency),
              const SizedBox(height: 16),

              // Top spending category
              if (topCat != null)
                _infoCard(
                  icon: topCat.key.icon,
                  color: topCat.key.color,
                  title: 'Top Category: ${topCat.key.name}',
                  subtitle: '${settings.currency}${NumberFormat('#,##0').format(topCat.value)} this month'
                    ' (${thisTotal > 0 ? (topCat.value / thisTotal * 100).toStringAsFixed(0) : 0}% of spending)',
                ),
              const SizedBox(height: 12),

              // Recurring subscriptions
              if (recurring.isNotEmpty) ...[
                const Text('Recurring Expenses Detected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...recurring.map((r) => _recurringTile(r, settings.currency)),
                const SizedBox(height: 16),
              ],

              // Smart Tips
              const Text('Smart Tips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ...insights.map((i) => _tipCard(i)),
            ]),
    );
  }

  Widget _comparisonCard(double thisMonth, double lastMonth, double change, String currency) {
    final isUp = change > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUp ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
                       : [const Color(0xFF059669), const Color(0xFF10B981)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('vs Last Month', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          Icon(isUp ? Icons.trending_up : Icons.trending_down, color: Colors.white, size: 28),
          const SizedBox(width: 8),
          Text('${isUp ? '+' : ''}${change.toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Text('This month: $currency${NumberFormat('#,##0').format(thisMonth)}', style: const TextStyle(color: Colors.white70)),
        Text('Last month: $currency${NumberFormat('#,##0').format(lastMonth)}', style: const TextStyle(color: Colors.white70)),
      ]),
    );
  }

  Widget _infoCard({required IconData icon, required Color color, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ])),
      ]),
    );
  }

  Widget _recurringTile(Map<String, dynamic> r, String currency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.autorenew, color: Colors.purple, size: 20)),
        title: Text(r['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('~${r['frequency']}  •  Monthly ~$currency${NumberFormat('#,##0').format(r['amount'])}',
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.repeat, size: 16, color: Colors.purple),
      ),
    );
  }

  Widget _tipCard(Map<String, dynamic> tip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: (tip['color'] as Color).withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(tip['icon'] as IconData, color: tip['color'] as Color, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tip['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(tip['body'], style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
          ])),
        ]),
      ),
    );
  }

  List<Map<String, dynamic>> _detectRecurring(List expenses) {
    final titleCount = <String, int>{};
    final titleAmount = <String, double>{};
    for (final e in expenses) {
      final key = e.title.toLowerCase().trim();
      titleCount[key] = (titleCount[key] ?? 0) + 1;
      titleAmount[key] = (titleAmount[key] ?? 0) + e.amount;
    }
    final recurring = <Map<String, dynamic>>[];
    titleCount.forEach((key, count) {
      if (count >= 2) {
        final avg = titleAmount[key]! / count;
        String freq = count >= 12 ? 'Monthly' : count >= 4 ? 'Quarterly' : 'Occasional';
        recurring.add({'name': _capitalize(key), 'amount': avg, 'count': count, 'frequency': freq});
      }
    });
    recurring.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return recurring.take(5).toList();
  }

  List<Map<String, dynamic>> _generateInsights(
    double thisTotal, double lastTotal, double change,
    Map<Category, double> catSums, List budgets,
    dynamic settings, dynamic topCat, List recurring,
  ) {
    final tips = <Map<String, dynamic>>[];

    if (change > 20) {
      tips.add({
        'icon': Icons.warning_amber_rounded,
        'color': Colors.orange,
        'title': 'Spending Increased Significantly',
        'body': 'Your spending is up ${change.toStringAsFixed(0)}% compared to last month. Consider reviewing your discretionary expenses.',
      });
    } else if (change < -10) {
      tips.add({
        'icon': Icons.celebration,
        'color': Colors.green,
        'title': 'Great Job Saving!',
        'body': 'You spent ${(-change).toStringAsFixed(0)}% less than last month. Keep it up!',
      });
    }

    // Budget warnings
    for (final entry in catSums.entries) {
      final matchingBudgets = budgets.where((b) => b.category == entry.key);
      if (matchingBudgets.isEmpty) continue;
      final budget = matchingBudgets.first;
      if (budget.monthlyLimit > 0) {
        final pct = entry.value / budget.monthlyLimit;
        if (pct > 0.9) {
          tips.add({
            'icon': Icons.account_balance_wallet,
            'color': Colors.red,
            'title': '${entry.key.name} Budget Almost Exhausted',
            'body': 'You\'ve used ${(pct * 100).toStringAsFixed(0)}% of your ${entry.key.name} budget. Only ${settings.currency}${(budget.monthlyLimit - entry.value).toStringAsFixed(0)} remaining.',
          });
        }
      }
    }

    if (topCat != null && thisTotal > 0 && (topCat.value / thisTotal) > 0.4) {
      tips.add({
        'icon': topCat.key.icon,
        'color': topCat.key.color,
        'title': '${topCat.key.name} Dominates Your Spending',
        'body': '${(topCat.value / thisTotal * 100).toStringAsFixed(0)}% of your budget goes to ${topCat.key.name}. Consider setting a specific budget cap.',
      });
    }

    if (settings.monthlyBudget > 0) {
      final savingsRate = (settings.monthlyBudget - thisTotal) / settings.monthlyBudget;
      if (savingsRate > 0.3) {
        tips.add({
          'icon': Icons.savings,
          'color': Colors.green,
          'title': 'Strong Budget Management',
          'body': 'You have ${(savingsRate * 100).toStringAsFixed(0)}% of your budget left this month. Awesome job!',
        });
      } else if (savingsRate < 0.1 && savingsRate > 0) {
        tips.add({
          'icon': Icons.savings,
          'color': Colors.orange,
          'title': 'Approaching Budget Limit',
          'body': 'You have less than 10% of your total budget remaining. Consider reducing spending on non-essentials.',
        });
      }
    }

    if (recurring.isNotEmpty) {
      final recTotal = recurring.fold(0.0, (a, b) => a + (b['amount'] as double));
      tips.add({
        'icon': Icons.autorenew,
        'color': Colors.purple,
        'title': 'Recurring Charges',
        'body': 'You have ${recurring.length} recurring expenses totalling approx. ${settings.currency}${NumberFormat('#,##0').format(recTotal)}/month. Review if all subscriptions are still being used.',
      });
    }

    if (tips.isEmpty) {
      tips.add({
        'icon': Icons.thumb_up,
        'color': Colors.blue,
        'title': 'Looking Good!',
        'body': 'Your spending looks healthy this month. Keep tracking to get more personalized insights.',
      });
    }

    return tips;
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
