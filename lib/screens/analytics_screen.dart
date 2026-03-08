import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/category.dart';
import '../utils/constants.dart';
import '../utils/date_extension.dart';
import '../widgets/glass_container.dart';
import 'transactions_screen.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void _changeMonth(int delta) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expenseProvider).where((e) => !e.isUncategorized).toList();
    final settings = ref.watch(appSettingsProvider);
    final now = DateTime.now();

    final monthlyExpenses = expenses.where(
      (e) => e.date.isTargetCustomMonth(_selectedMonth.month, _selectedMonth.year, settings.startingDayOfMonth),
    ).toList();

    // Previous month for MoM comparison
    final prevMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    final prevExpenses = expenses.where(
      (e) => e.date.isTargetCustomMonth(prevMonth.month, prevMonth.year, settings.startingDayOfMonth),
    ).toList();

    final totalSpent = monthlyExpenses.fold(0.0, (a, b) => a + b.amount);
    final prevTotal = prevExpenses.fold(0.0, (a, b) => a + b.amount);
    final momChange = prevTotal > 0 ? ((totalSpent - prevTotal) / prevTotal * 100) : 0.0;
    final isCurrentMonth = _selectedMonth.month == now.month && _selectedMonth.year == now.year;

    final catSums = <Category, double>{};
    for (final e in monthlyExpenses) {
      catSums[e.category] = (catSums[e.category] ?? 0) + e.amount;
    }
    final sortedCats = catSums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // 6-month bar data — keep list so index maps to DateTime for tap
    final sixMonths = List.generate(6, (i) {
      final m = DateTime(now.year, now.month - (5 - i));
      final total = expenses
          .where((e) => e.date.isTargetCustomMonth(m.month, m.year, settings.startingDayOfMonth))
          .fold(0.0, (a, b) => a + b.amount);
      return (month: m, label: DateFormat('MMM').format(m), total: total);
    });

    // Biggest single expense this month
    final biggestExpense = monthlyExpenses.isNotEmpty
        ? monthlyExpenses.reduce((a, b) => a.amount > b.amount ? a : b)
        : null;
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final daysElapsed = isCurrentMonth
        ? now.day
        : daysInMonth;
    final dailyAvg = daysElapsed > 0 ? totalSpent / daysElapsed : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: monthlyExpenses.isEmpty && sixMonths.every((m) => m.total == 0)
          ? _emptyState()
          : CustomScrollView(
              slivers: [
                // Month Switcher
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _changeMonth(-1),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMMM yyyy').format(_selectedMonth),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (isCurrentMonth)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Current',
                              style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.chevron_right,
                            color: isCurrentMonth ? Colors.grey.shade400 : null),
                        onPressed: isCurrentMonth ? null : () => _changeMonth(1),
                      ),
                    ]),
                  ),
                ),

                // Total Spent Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _totalCard(totalSpent, prevTotal, momChange, settings.currency),
                  ),
                ),

                // Stats row — Daily Avg + Biggest Expense
                if (totalSpent > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(children: [
                        Expanded(
                          child: _statChip(
                            icon: Icons.today_rounded,
                            label: 'Daily Avg',
                            value: '${settings.currency}${NumberFormat('#,##0').format(dailyAvg)}',
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (biggestExpense != null)
                          Expanded(
                            child: _statChip(
                              icon: Icons.arrow_upward_rounded,
                              label: 'Top Expense',
                              value: '${settings.currency}${NumberFormat('#,##0').format(biggestExpense.amount)}',
                              sublabel: biggestExpense.title,
                              color: Colors.deepOrange,
                            ),
                          ),
                      ]),
                    ),
                  ),

                // Pie Chart
                if (sortedCats.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text('Spending Breakdown',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          sections: sortedCats.map((e) => PieChartSectionData(
                            value: e.value,
                            color: e.key.color,
                            title: '${(e.value / totalSpent * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                            radius: 80,
                          )).toList(),
                          sectionsSpace: 3,
                          centerSpaceRadius: 30,
                        ),
                      ),
                    ),
                  ),
                ],

                // Category List
                if (sortedCats.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('By Category',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final e = sortedCats[i];
                        final pct = totalSpent > 0 ? e.value / totalSpent : 0.0;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TransactionsScreen(initialCategory: e.key),
                                ),
                              );
                            },
                            child: GlassContainer(
                            borderRadius: 16,
                            backgroundColor: Theme.of(context).cardTheme.color ?? Colors.white,
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Row(children: [
                                  Container(
                                    width: 38, height: 38,
                                    decoration: BoxDecoration(
                                        color: e.key.color.withValues(alpha: 0.15),
                                        shape: BoxShape.circle),
                                    child: Icon(e.key.icon, color: e.key.color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(e.key.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                ]),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(
                                    '${settings.currency}${NumberFormat('#,##0').format(e.value)}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('${(pct * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 12)),
                                ]),
                              ]),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0, end: pct),
                                  duration: const Duration(milliseconds: 1000),
                                  curve: Curves.easeOutExpo,
                                  builder: (context, val, _) => LinearProgressIndicator(
                                    value: val,
                                    backgroundColor:
                                        Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                    color: e.key.color,
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                            ]),
                          ),
                        ),
                        );
                      },
                      childCount: sortedCats.length,
                    ),
                  ),
                ],

                // 6-Month Bar Chart
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text('6-Month Overview',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
                    child: SizedBox(
                      height: 200,
                      child: BarChart(BarChartData(
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(
                          touchCallback: (event, response) {
                            if (event is FlTapUpEvent &&
                                response != null &&
                                response.spot != null) {
                              final idx = response.spot!.touchedBarGroupIndex;
                              if (idx >= 0 && idx < sixMonths.length) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedMonth = DateTime(
                                    sixMonths[idx].month.year,
                                    sixMonths[idx].month.month,
                                  );
                                });
                              }
                            }
                          },
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, m) {
                              final idx = v.toInt();
                              if (idx >= 0 && idx < sixMonths.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(sixMonths[idx].label,
                                      style: const TextStyle(fontSize: 10)),
                                );
                              }
                              return const SizedBox();
                            },
                          )),
                          leftTitles: AxisTitles(sideTitles: SideTitles(
                            showTitles: true, reservedSize: 44,
                            getTitlesWidget: (v, m) =>
                                Text(NumberFormat.compact().format(v), style: const TextStyle(fontSize: 9)),
                          )),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        barGroups: sixMonths.asMap().entries.map((entry) {
                          final idx  = entry.key;
                          final data = entry.value;
                          final isSelected = data.month.month == _selectedMonth.month
                              && data.month.year == _selectedMonth.year;
                          return BarChartGroupData(x: idx, barRods: [
                            BarChartRodData(
                              toY: data.total,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.secondary.withValues(alpha: 0.6),
                              width: 28,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ]);
                        }).toList(),
                      )),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _totalCard(double total, double prevTotal, double momChange, String currency) {
    final momUp = momChange > 0;
    return GlassContainer(
      borderRadius: 24,
      backgroundColor: AppColors.primary,
      padding: const EdgeInsets.all(24),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total Spent', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text('$currency${NumberFormat('#,##0').format(total)}',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -1)),
          const Text('This Month', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
        if (prevTotal > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: momUp ? Colors.red.shade400.withValues(alpha: 0.2) : const Color(0xFF4ADE80).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: momUp ? Colors.red.shade400.withValues(alpha: 0.5) : const Color(0xFF4ADE80).withValues(alpha: 0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(momUp ? Icons.show_chart : Icons.trending_down,
                  color: momUp ? Colors.red.shade200 : const Color(0xFF4ADE80), size: 16),
              const SizedBox(width: 6),
              Text(
                '${momUp ? '+' : ''}${momChange.toStringAsFixed(1)}%',
                style: TextStyle(
                    color: momUp ? Colors.red.shade100 : const Color(0xFF4ADE80),
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _emptyState() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.bar_chart_rounded, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No data yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text('Add expenses to see your analytics here.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                textAlign: TextAlign.center),
          ),
        ]),
      );

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    String? sublabel,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            if (sublabel != null)
              Text(sublabel, style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}
