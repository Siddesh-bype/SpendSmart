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

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Breakdown'),
            Tab(text: 'Trend'),
            Tab(text: 'Category'),
          ],
        ),
      ),
      body: Column(children: [
        // Month Switcher
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeMonth(-1),
            ),
            const SizedBox(width: 8),
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
                child: const Text('Current', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.chevron_right, color: isCurrentMonth ? Colors.grey.shade300 : null),
              onPressed: isCurrentMonth ? null : () => _changeMonth(1),
            ),
          ]),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildBreakdown(sortedCats, totalSpent, prevTotal, momChange, settings.currency),
              _buildTrend(expenses, settings.currency),
              _buildCategoryList(sortedCats, totalSpent, settings.currency),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildBreakdown(
    List<MapEntry<Category, double>> sortedCats,
    double total,
    double prevTotal,
    double momChange,
    String currency,
  ) {
    if (sortedCats.isEmpty) {
      return _emptyState('No spending this month', 'Add expenses to see the breakdown here.', Icons.pie_chart_outline_rounded);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _totalCard(total, prevTotal, momChange, currency),
        const SizedBox(height: 20),
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: sortedCats.map((e) => PieChartSectionData(
                value: e.value,
                color: e.key.color,
                title: '${(e.value / total * 100).toStringAsFixed(0)}%',
                titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                radius: 80,
              )).toList(),
              sectionsSpace: 3,
              centerSpaceRadius: 30,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...sortedCats.map((e) => _catRow(e.key, e.value, total, currency)),
      ]),
    );
  }

  Widget _buildTrend(List expenses, String currency) {
    // Daily data for selected month
    final dailyMap = <int, double>{};
    for (final e in expenses) {
      if (e.date.month == _selectedMonth.month && e.date.year == _selectedMonth.year) {
        dailyMap[e.date.day] = (dailyMap[e.date.day] ?? 0) + e.amount;
      }
    }

    // Weekly bar data for last 6 months
    final now = DateTime.now();
    final monthlyTotals = <String, double>{};
    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      final key = DateFormat('MMM').format(m);
      final total = expenses
          .where((e) => e.date.month == m.month && e.date.year == m.year)
          .fold(0.0, (a, b) => a + b.amount);
      monthlyTotals[key] = total;
    }

    if (dailyMap.isEmpty && monthlyTotals.values.every((v) => v == 0)) {
      return _emptyState('No trend data', 'Add expenses over multiple days to see spending trends.', Icons.show_chart_rounded);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Daily line chart
        if (dailyMap.isNotEmpty) ...[
          const Text('Daily Spending', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(LineChartData(
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, interval: 5,
                  getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)),
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 48,
                  getTitlesWidget: (v, m) => Text(NumberFormat.compact().format(v), style: const TextStyle(fontSize: 9)),
                )),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: dailyMap.entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value))
                      .toList()
                    ..sort((a, b) => a.x.compareTo(b.x)),
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.12)),
                ),
              ],
            )),
          ),
          const SizedBox(height: 28),
        ],

        // 6-month bar chart
        const Text('6-Month Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: BarChart(BarChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) {
                  final keys = monthlyTotals.keys.toList();
                  if (v.toInt() < keys.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(keys[v.toInt()], style: const TextStyle(fontSize: 10)),
                    );
                  }
                  return const SizedBox();
                },
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 44,
                getTitlesWidget: (v, m) => Text(NumberFormat.compact().format(v), style: const TextStyle(fontSize: 9)),
              )),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            barGroups: monthlyTotals.entries.toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final val = entry.value.value;
              final isSelected = entry.value.key == DateFormat('MMM').format(_selectedMonth);
              return BarChartGroupData(
                x: idx,
                barRods: [
                  BarChartRodData(
                    toY: val,
                    color: isSelected ? AppColors.primary : AppColors.secondary.withValues(alpha: 0.6),
                    width: 28,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
              );
            }).toList(),
          )),
        ),
      ]),
    );
  }

  Widget _buildCategoryList(
    List<MapEntry<Category, double>> sortedCats,
    double total,
    String currency,
  ) {
    if (sortedCats.isEmpty) {
      return _emptyState('No categories yet', 'Start adding expenses to see category breakdown.', Icons.category_outlined);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...sortedCats.map((e) {
          final pct = total > 0 ? e.value / total : 0.0;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: e.key.color.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Icon(e.key.icon, color: e.key.color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(e.key.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$currency${NumberFormat('#,##0').format(e.value)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${(pct * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey.shade200,
                    color: e.key.color,
                    minHeight: 8,
                  ),
                ),
              ]),
            ),
          );
        }),
      ],
    );
  }

  Widget _totalCard(double total, double prevTotal, double momChange, String currency) {
    final momUp = momChange > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total Spent', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text('$currency${NumberFormat('#,##0').format(total)}',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const Text('This Month', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
        if (prevTotal > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(momUp ? Icons.arrow_upward : Icons.arrow_downward, color: momUp ? Colors.red.shade200 : Colors.green.shade200, size: 14),
              const SizedBox(width: 4),
              Text(
                '${momUp ? '+' : ''}${momChange.toStringAsFixed(1)}%',
                style: TextStyle(color: momUp ? Colors.red.shade100 : Colors.green.shade100, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _catRow(Category cat, double value, double total, String currency) {
    final pct = total > 0 ? value / total : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(cat.name, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text('$currency${NumberFormat('#,##0').format(value)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    );
  }

  Widget _emptyState(String title, String subtitle, IconData icon) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 72, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
      ),
    ]),
  );
}
