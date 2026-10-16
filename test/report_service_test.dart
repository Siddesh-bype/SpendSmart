import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/models/category.dart';
import 'package:spendsmart/models/custom_category.dart';
import 'package:spendsmart/models/expense.dart';
import 'package:spendsmart/models/report_models.dart';
import 'package:spendsmart/services/report_service.dart';
import 'package:spendsmart/services/expense_category_resolver.dart';

void main() {
  final range = ReportDateRange(
    start: DateTime(2026, 3, 10),
    endInclusive: DateTime(2026, 3, 12),
  );

  Expense expense(
    String id,
    DateTime date,
    double amount, {
    Category category = Category.food,
    bool uncategorized = false,
    String title = 'Coffee',
    String? customCategoryId,
  }) => Expense(
    id: id,
    title: title,
    amount: amount,
    category: category,
    date: date,
    isManual: true,
    isUncategorized: uncategorized,
    source: 'test',
    customCategoryId: customCategoryId,
  );

  test('date filtering includes both inclusive date boundaries', () {
    final report = ReportService.buildReport([
      expense('before', DateTime(2026, 3, 9, 23, 59), 1),
      expense('start', DateTime(2026, 3, 10, 0, 1), 2),
      expense('end', DateTime(2026, 3, 12, 23, 59), 3),
      expense('after', DateTime(2026, 3, 13), 4),
    ], ReportConfiguration(range: range));

    expect(report.expenses.map((item) => item.id), ['end', 'start']);
    expect(report.total, 5);
  });

  test('financial presets resolve the current and previous periods', () {
    final current = ReportService.resolvePreset(
      ReportPreset.currentFinancialPeriod,
      now: DateTime(2026, 8, 4),
      startingDayOfMonth: 10,
    );
    final previous = ReportService.resolvePreset(
      ReportPreset.previousFinancialPeriod,
      now: DateTime(2026, 8, 4),
      startingDayOfMonth: 10,
    );

    expect(current.start, DateTime(2026, 7, 10));
    expect(current.endInclusive, DateTime(2026, 8, 9));
    expect(previous.start, DateTime(2026, 6, 10));
    expect(previous.endInclusive, DateTime(2026, 7, 9));
  });

  test('category and uncategorized filters are applied together', () {
    final expenses = [
      expense('food', DateTime(2026, 3, 10), 10),
      expense(
        'transport',
        DateTime(2026, 3, 10),
        20,
        category: Category.transport,
      ),
      expense('uncategorized', DateTime(2026, 3, 10), 30, uncategorized: true),
    ];
    final foodOnly = ReportService.buildReport(
      expenses,
      ReportConfiguration(range: range, category: Category.food),
    );
    final foodAndUncategorized = ReportService.buildReport(
      expenses,
      ReportConfiguration(
        range: range,
        category: Category.food,
        includeUncategorized: true,
      ),
    );

    expect(foodOnly.expenses.map((item) => item.id), ['food']);
    expect(foodAndUncategorized.expenses.map((item) => item.id), [
      'food',
      'uncategorized',
    ]);
  });

  test('sort order changes the filtered set order', () {
    final expenses = [
      expense('small', DateTime(2026, 3, 12), 5),
      expense('large', DateTime(2026, 3, 10), 50),
      expense('middle', DateTime(2026, 3, 11), 20),
    ];

    final byAmount = ReportService.buildReport(
      expenses,
      ReportConfiguration(
        range: range,
        sortOrder: ReportSortOrder.highestAmountFirst,
      ),
    );
    final oldest = ReportService.buildReport(
      expenses,
      ReportConfiguration(range: range, sortOrder: ReportSortOrder.oldestFirst),
    );

    expect(byAmount.expenses.map((item) => item.id), [
      'large',
      'middle',
      'small',
    ]);
    expect(oldest.expenses.map((item) => item.id), [
      'large',
      'middle',
      'small',
    ]);
  });

  test('empty ranges produce a zero-count report and no total', () {
    final report = ReportService.buildReport([
      expense('outside', DateTime(2026, 2, 1), 99),
    ], ReportConfiguration(range: range));

    expect(report.expenses, isEmpty);
    expect(report.total, 0);
    expect(report.categoryTotals, isEmpty);
  });

  test('day count uses calendar dates rather than elapsed local hours', () {
    final reportRange = ReportDateRange(
      start: DateTime(2026, 3, 7, 23, 59),
      endInclusive: DateTime(2026, 3, 9, 0, 1),
    );

    expect(reportRange.dayCount, 3);
  });

  test('CSV reflects the range and sanitizes formula-like values', () {
    final report = ReportService.buildReport([
      expense('=id', DateTime(2026, 3, 10), 12.5, title: '=HYPERLINK("bad")'),
    ], ReportConfiguration(range: range));

    final csv = ReportService.csvText(report);
    expect(csv, contains('10 Mar 2026 – 12 Mar 2026'));
    expect(csv, contains("'=id"));
    expect(csv, contains("'=HYPERLINK(\"\"bad\"\")"));
  });

  test('custom categories are filterable and remain distinct from Other', () {
    final catalog = ExpenseCategoryCatalog([
      CustomCategory(
        id: 'subscriptions',
        name: 'Subscriptions',
        iconCodePoint: 0xe3b0,
        colorValue: 0xFF9AB8EE,
      ),
    ]);
    final report = ReportService.buildReport(
      [
        expense(
          'custom',
          DateTime(2026, 3, 10),
          20,
          customCategoryId: 'subscriptions',
        ),
        expense('other', DateTime(2026, 3, 10), 5, category: Category.other),
      ],
      ReportConfiguration(
        range: ReportDateRange(
          start: DateTime(2026, 3, 10),
          endInclusive: DateTime(2026, 3, 12),
        ),
        customCategoryId: 'subscriptions',
      ),
      catalog: catalog,
    );

    expect(report.expenses.map((item) => item.id), ['custom']);
    expect(report.categoryTotals, {'Subscriptions': 20});
    expect(ReportService.csvText(report), contains('Subscriptions'));
  });

  test('custom category labels are sanitized in report CSV', () {
    final catalog = ExpenseCategoryCatalog([
      CustomCategory(
        id: 'unsafe',
        name: '=HYPERLINK("bad")',
        iconCodePoint: 0xe3b0,
        colorValue: 0xFF9AB8EE,
      ),
    ]);
    final report = ReportService.buildReport(
      [
        expense(
          'unsafe',
          DateTime(2026, 3, 10),
          20,
          customCategoryId: 'unsafe',
        ),
      ],
      ReportConfiguration(range: range),
      catalog: catalog,
    );

    expect(ReportService.csvText(report), contains("'=HYPERLINK"));
  });
}
