import '../models/category.dart';
import '../models/expense.dart';
import '../services/expense_category_resolver.dart';
import '../utils/financial_period.dart';

enum ReportPreset {
  currentFinancialPeriod,
  previousFinancialPeriod,
  last7Days,
  last30Days,
  last90Days,
  custom,
}

extension ReportPresetLabel on ReportPreset {
  String get label => switch (this) {
    ReportPreset.currentFinancialPeriod => 'Current financial period',
    ReportPreset.previousFinancialPeriod => 'Previous financial period',
    ReportPreset.last7Days => 'Last 7 days',
    ReportPreset.last30Days => 'Last 30 days',
    ReportPreset.last90Days => 'Last 90 days',
    ReportPreset.custom => 'Custom range',
  };
}

enum ReportSortOrder {
  newestFirst,
  oldestFirst,
  highestAmountFirst,
  lowestAmountFirst,
}

extension ReportSortOrderLabel on ReportSortOrder {
  String get label => switch (this) {
    ReportSortOrder.newestFirst => 'Newest first',
    ReportSortOrder.oldestFirst => 'Oldest first',
    ReportSortOrder.highestAmountFirst => 'Highest amount first',
    ReportSortOrder.lowestAmountFirst => 'Lowest amount first',
  };
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class ReportDateRange {
  ReportDateRange({required DateTime start, required DateTime endInclusive})
    : start = dateOnly(start),
      endInclusive = dateOnly(endInclusive) {
    if (this.endInclusive.isBefore(this.start)) {
      throw ArgumentError(
        'Report end date must be on or after the start date.',
      );
    }
  }

  factory ReportDateRange.fromFinancialPeriod(FinancialPeriod period) =>
      ReportDateRange(
        start: period.start,
        endInclusive: period.endExclusive.subtract(const Duration(days: 1)),
      );

  final DateTime start;
  final DateTime endInclusive;

  bool contains(DateTime value) {
    final day = dateOnly(value);
    return !day.isBefore(start) && !day.isAfter(endInclusive);
  }

  int get dayCount =>
      DateTime.utc(
        endInclusive.year,
        endInclusive.month,
        endInclusive.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
      1;

  String get filePart => '${_compact(start)}_${_compact(endInclusive)}';

  static String _compact(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is ReportDateRange &&
      other.start == start &&
      other.endInclusive == endInclusive;

  @override
  int get hashCode => Object.hash(start, endInclusive);
}

class ReportConfiguration {
  const ReportConfiguration({
    required this.range,
    this.category,
    this.customCategoryId,
    this.includeUncategorized = false,
    this.sortOrder = ReportSortOrder.newestFirst,
  });

  final ReportDateRange range;
  final Category? category;
  final String? customCategoryId;
  final bool includeUncategorized;
  final ReportSortOrder sortOrder;
}

class ReportData {
  const ReportData({
    required this.configuration,
    required this.expenses,
    this.catalog = const ExpenseCategoryCatalog.empty(),
  });

  final ReportConfiguration configuration;
  final List<Expense> expenses;
  final ExpenseCategoryCatalog catalog;

  double get total => expenses.fold(0, (sum, expense) => sum + expense.amount);

  Map<String, double> get categoryTotals {
    final grouped = <ExpenseCategoryKey, double>{};
    var uncategorized = 0.0;
    for (final expense in expenses) {
      if (expense.isUncategorized) {
        uncategorized += expense.amount;
        continue;
      }
      final key = catalog.keyOf(expense);
      grouped[key] = (grouped[key] ?? 0) + expense.amount;
    }
    final labelCounts = <String, int>{};
    for (final key in grouped.keys) {
      final label = catalog.resolveKey(key)!.label;
      labelCounts[label] = (labelCounts[label] ?? 0) + 1;
    }
    final totals = <String, double>{};
    for (final entry in grouped.entries) {
      final resolved = catalog.resolveKey(entry.key)!;
      final label = labelCounts[resolved.label]! > 1 && resolved.isCustom
          ? '${resolved.label} (custom)'
          : resolved.label;
      totals[label] = (totals[label] ?? 0) + entry.value;
    }
    if (uncategorized > 0) totals['Uncategorized'] = uncategorized;
    return totals;
  }

  Map<DateTime, double> get dailyTotals {
    final totals = <DateTime, double>{};
    for (final expense in expenses) {
      final day = dateOnly(expense.date);
      totals[day] = (totals[day] ?? 0) + expense.amount;
    }
    return totals;
  }
}
