import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/expense.dart';
import '../models/category.dart';

class CategoryPieChart extends StatelessWidget {
  final List<Expense> expenses;

  const CategoryPieChart({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const Center(child: Text('No data for this period', style: TextStyle(color: Colors.grey)));
    }

    // Group expenses by category
    final Map<Category, double> categorySums = {};
    for (var exp in expenses) {
      categorySums[exp.category] = (categorySums[exp.category] ?? 0) + exp.amount;
    }

    final total = categorySums.values.fold(0.0, (a, b) => a + b);

    final List<PieChartSectionData> sections = [];
    categorySums.forEach((category, sum) {
      final percentage = (sum / total) * 100;
      final radius = 50.0;
      
      sections.add(
        PieChartSectionData(
          color: category.color,
          value: sum,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: radius,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    });

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: sections,
        ),
      ),
    );
  }
}

class ExpenseBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;

  const ExpenseBarChart({super.key, required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Center(child: Text('No data available', style: TextStyle(color: Colors.grey)));
    }

    final maxVal = values.reduce((a, b) => a > b ? a : b);

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < values.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i],
              color: Theme.of(context).primaryColor,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.2,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      labels[value.toInt()],
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }
}
