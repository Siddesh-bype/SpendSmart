import 'dart:io';
import 'dart:ui' show Offset, Rect;

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/expense.dart';
import '../models/report_models.dart';
import '../utils/financial_period.dart';
import '../utils/date_extension.dart';
import 'expense_category_resolver.dart';
import 'export_service.dart';

class ReportService {
  static ReportDateRange resolvePreset(
    ReportPreset preset, {
    required DateTime now,
    required int startingDayOfMonth,
    ReportDateRange? customRange,
  }) {
    final today = dateOnly(now);
    switch (preset) {
      case ReportPreset.currentFinancialPeriod:
        return ReportDateRange.fromFinancialPeriod(
          FinancialPeriod.containing(today, startingDayOfMonth),
        );
      case ReportPreset.previousFinancialPeriod:
        return ReportDateRange.fromFinancialPeriod(
          FinancialPeriod.containing(today, startingDayOfMonth).previous,
        );
      case ReportPreset.last7Days:
        return _lastDays(today, 7);
      case ReportPreset.last30Days:
        return _lastDays(today, 30);
      case ReportPreset.last90Days:
        return _lastDays(today, 90);
      case ReportPreset.custom:
        return customRange ??
            ReportDateRange(start: today, endInclusive: today);
    }
  }

  static ReportDateRange _lastDays(DateTime end, int count) => ReportDateRange(
    start: end.subtract(Duration(days: count - 1)),
    endInclusive: end,
  );

  static ReportData buildReport(
    List<Expense> expenses,
    ReportConfiguration configuration,
    {ExpenseCategoryCatalog? catalog}
  ) {
    final categoryCatalog = catalog ?? const ExpenseCategoryCatalog.empty();
    final filtered = expenses.where((expense) {
      if (!configuration.range.contains(expense.date)) return false;
      if (expense.isUncategorized) return configuration.includeUncategorized;
      if (configuration.customCategoryId != null) {
        return categoryCatalog.keyOf(expense) ==
            ExpenseCategoryKey.custom(configuration.customCategoryId!);
      }
      return configuration.category == null ||
          categoryCatalog.keyOf(expense) ==
              ExpenseCategoryKey.builtIn(configuration.category!);
    }).toList();

    filtered.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      final byAmount = a.amount.compareTo(b.amount);
      return switch (configuration.sortOrder) {
        ReportSortOrder.newestFirst => -byDate,
        ReportSortOrder.oldestFirst => byDate,
        ReportSortOrder.highestAmountFirst => -byAmount,
        ReportSortOrder.lowestAmountFirst => byAmount,
      };
    });

    return ReportData(
      configuration: configuration,
      expenses: filtered,
      catalog: categoryCatalog,
    );
  }

  static String csvText(ReportData report) {
    final range = report.configuration.range;
    final rows = <List<Object?>>[
      ['Report Period', _rangeLabel(range)],
      ['Transaction Count', report.expenses.length],
      ['Total Expenses', report.total.toStringAsFixed(2)],
      <Object?>[],
      [
        'ID',
        'Date',
        'Title',
        'Amount',
        'Category',
        'Source',
        'Is Manual',
        'Is Uncategorized',
        'Note',
      ],
    ];
    for (final expense in report.expenses) {
      rows.add([
        ExportService.sanitizeCell(expense.id),
        DateFormat('yyyy-MM-dd HH:mm:ss').format(expense.date),
        ExportService.sanitizeCell(expense.title),
        expense.amount,
        ExportService.sanitizeCell(
          expense.isUncategorized
              ? 'Uncategorized'
              : report.catalog.labelOf(expense),
        ),
        ExportService.sanitizeCell(expense.source),
        expense.isManual,
        expense.isUncategorized,
        ExportService.sanitizeCell(expense.note ?? ''),
      ]);
    }
    return const CsvEncoder().convert(rows);
  }

  static Future<String> exportCsv(ReportData report) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/SpendSmart_Report_${report.configuration.range.filePart}_'
      '${DateTime.now().microsecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csvText(report));
    return file.path;
  }

  static Future<String> exportPdf(
    ReportData report, {
    required String currency,
  }) async {
    final document = PdfDocument();
    final page = document.pages.add();
    final pageSize = page.getClientSize();
    const left = 24.0;
    final width = pageSize.width - (left * 2);
    final primary = PdfColor(63, 114, 175);
    final ink = PdfColor(17, 45, 78);
    final muted = PdfColor(92, 107, 128);
    final light = PdfColor(219, 226, 239);
    final amount = PdfColor(183, 54, 54);
    final regular = PdfStandardFont(PdfFontFamily.helvetica, 8);
    final small = PdfStandardFont(PdfFontFamily.helvetica, 7);
    final bold = PdfStandardFont(
      PdfFontFamily.helvetica,
      9,
      style: PdfFontStyle.bold,
    );
    final titleFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      20,
      style: PdfFontStyle.bold,
    );
    final footer = PdfPageTemplateElement(
      Rect.fromLTWH(0, 0, pageSize.width, 32),
    );
    footer.graphics.drawLine(
      PdfPen(light),
      const Offset(left, 2),
      Offset(pageSize.width - left, 2),
    );
    footer.graphics.drawString(
      'SpendSmart • ${_rangeLabel(report.configuration.range)}',
      small,
      brush: PdfSolidBrush(muted),
      bounds: Rect.fromLTWH(left, 8, width, 16),
    );
    document.template.bottom = footer;

    final header = PdfPageTemplateElement(
      Rect.fromLTWH(0, 0, pageSize.width, 58),
    );
    header.graphics.drawString(
      'SpendSmart Report Center',
      titleFont,
      brush: PdfSolidBrush(primary),
      bounds: Rect.fromLTWH(left, 8, width, 28),
    );
    header.graphics.drawString(
      'Expense report • ${_rangeLabel(report.configuration.range)}',
      regular,
      brush: PdfSolidBrush(muted),
      bounds: Rect.fromLTWH(left, 38, width, 16),
    );
    document.template.top = header;

    var y = 70.0;

    page.graphics.drawRectangle(
      brush: PdfSolidBrush(light),
      bounds: Rect.fromLTWH(left, y, width, 58),
    );
    page.graphics.drawString(
      'SUMMARY',
      bold,
      brush: PdfSolidBrush(primary),
      bounds: Rect.fromLTWH(left + 10, y + 8, width - 20, 14),
    );
    page.graphics.drawString(
      'Transactions  ${report.expenses.length}',
      regular,
      brush: PdfSolidBrush(ink),
      bounds: Rect.fromLTWH(left + 10, y + 28, width / 3, 16),
    );
    page.graphics.drawString(
      'Total  $currency${_money(report.total)}',
      regular,
      brush: PdfSolidBrush(amount),
      bounds: Rect.fromLTWH(left + width / 3, y + 28, width / 3, 16),
    );
    page.graphics.drawString(
      'Days  ${report.configuration.range.dayCount}',
      regular,
      brush: PdfSolidBrush(ink),
      bounds: Rect.fromLTWH(left + (width * 2 / 3), y + 28, width / 3, 16),
    );
    y += 72;

    page.graphics.drawString(
      'CATEGORY BREAKDOWN',
      bold,
      brush: PdfSolidBrush(primary),
      bounds: Rect.fromLTWH(left, y, width, 16),
    );
    y += 20;
    final categoryRows = report.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in categoryRows) {
      final percentage = report.total == 0 ? 0 : entry.value / report.total;
      page.graphics.drawString(
        entry.key,
        regular,
        brush: PdfSolidBrush(ink),
        bounds: Rect.fromLTWH(left, y, width * 0.42, 14),
      );
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(light),
        bounds: Rect.fromLTWH(left + width * 0.42, y + 2, width * 0.35, 8),
      );
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(primary),
        bounds: Rect.fromLTWH(
          left + width * 0.42,
          y + 2,
          width * 0.35 * percentage,
          8,
        ),
      );
      page.graphics.drawString(
        '$currency${_money(entry.value)}  ${(percentage * 100).toStringAsFixed(0)}%',
        small,
        brush: PdfSolidBrush(muted),
        bounds: Rect.fromLTWH(left + width * 0.79, y, width * 0.21, 14),
      );
      y += 16;
    }
    if (categoryRows.isEmpty) {
      page.graphics.drawString(
        'No expenses in this range.',
        regular,
        brush: PdfSolidBrush(muted),
        bounds: Rect.fromLTWH(left, y, width, 14),
      );
      y += 16;
    }
    y += 10;

    page.graphics.drawString(
      'DAILY SUMMARY',
      bold,
      brush: PdfSolidBrush(primary),
      bounds: Rect.fromLTWH(left, y, width, 16),
    );
    y += 18;
    final dailyGrid = _dailyGrid(
      report,
      regular,
      bold,
      primary,
      light,
      ink,
      muted,
      currency,
    );
    final dailyResult = dailyGrid.draw(
      page: page,
      bounds: Rect.fromLTWH(left, y, width, 0),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );
    var transactionPage = dailyResult?.page ?? page;
    var transactionY = dailyResult == null ? y : dailyResult.bounds.bottom + 14;
    if (transactionY > pageSize.height - 100) {
      transactionPage = document.pages.add();
      transactionY = 24;
    }
    transactionPage.graphics.drawString(
      'TRANSACTION HISTORY',
      bold,
      brush: PdfSolidBrush(primary),
      bounds: Rect.fromLTWH(left, transactionY, width, 16),
    );
    final transactionGrid = _transactionGrid(
      report,
      regular,
      bold,
      primary,
      light,
      ink,
      muted,
      amount,
      currency,
    );
    transactionGrid.draw(
      page: transactionPage,
      bounds: Rect.fromLTWH(left, transactionY + 20, width, 0),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/SpendSmart_Report_${report.configuration.range.filePart}_'
      '${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await document.save());
    document.dispose();
    return file.path;
  }

  static PdfGrid _dailyGrid(
    ReportData report,
    PdfFont regular,
    PdfFont bold,
    PdfColor primary,
    PdfColor light,
    PdfColor ink,
    PdfColor muted,
    String currency,
  ) {
    final grid = PdfGrid()..repeatHeader = true;
    grid.columns.add(count: 2);
    grid.style = PdfGridStyle(
      font: regular,
      cellPadding: PdfPaddings(left: 5, right: 5, top: 3, bottom: 3),
    );
    final header = grid.headers.add(1)[0];
    header.cells[0].value = 'Date';
    header.cells[1].value = 'Total';
    header.style = PdfGridRowStyle(
      backgroundBrush: PdfSolidBrush(primary),
      textBrush: PdfSolidBrush(PdfColor(255, 255, 255)),
      font: bold,
    );
    final days = report.dailyTotals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (var i = 0; i < days.length; i++) {
      final entry = days[i];
      final row = grid.rows.add();
      row.cells[0].value = displayDateFormat.format(entry.key);
      row.cells[1].value = '$currency${_money(entry.value)}';
      row.style = PdfGridRowStyle(
        backgroundBrush: PdfSolidBrush(
          i.isEven ? PdfColor(255, 255, 255) : light,
        ),
        textBrush: PdfSolidBrush(ink),
        font: regular,
      );
    }
    if (days.isEmpty) {
      final row = grid.rows.add();
      row.cells[0].value = 'No expenses';
      row.cells[1].value = '-';
      row.style = PdfGridRowStyle(
        textBrush: PdfSolidBrush(muted),
        font: regular,
      );
    }
    grid.columns[0].width = 180;
    grid.columns[1].width = 180;
    return grid;
  }

  static PdfGrid _transactionGrid(
    ReportData report,
    PdfFont regular,
    PdfFont bold,
    PdfColor primary,
    PdfColor light,
    PdfColor ink,
    PdfColor muted,
    PdfColor amount,
    String currency,
  ) {
    final grid = PdfGrid()..repeatHeader = true;
    grid.columns.add(count: 4);
    grid.style = PdfGridStyle(
      font: regular,
      cellPadding: PdfPaddings(left: 4, right: 4, top: 4, bottom: 4),
    );
    final header = grid.headers.add(1)[0];
    for (final pair in [
      (0, 'Date'),
      (1, 'Description'),
      (2, 'Category'),
      (3, 'Amount'),
    ]) {
      header.cells[pair.$1].value = pair.$2;
    }
    header.style = PdfGridRowStyle(
      backgroundBrush: PdfSolidBrush(primary),
      textBrush: PdfSolidBrush(PdfColor(255, 255, 255)),
      font: bold,
    );
    for (var i = 0; i < report.expenses.length; i++) {
      final expense = report.expenses[i];
      final row = grid.rows.add();
      row.cells[0].value = DateFormat('dd/MM/yy').format(expense.date);
      row.cells[1].value = _shorten(expense.title, 34);
      row.cells[2].value = expense.isUncategorized
          ? 'Uncategorized'
          : report.catalog.labelOf(expense);
      row.cells[3].value = '$currency${_money(expense.amount)}';
      row.style = PdfGridRowStyle(
        backgroundBrush: PdfSolidBrush(
          i.isEven ? PdfColor(255, 255, 255) : light,
        ),
        textBrush: PdfSolidBrush(ink),
        font: regular,
      );
      row.cells[3].style = PdfGridCellStyle(textBrush: PdfSolidBrush(amount));
    }
    if (report.expenses.isEmpty) {
      final row = grid.rows.add();
      row.cells[0].value = '-';
      row.cells[1].value = 'No expenses in this range';
      row.cells[2].value = '-';
      row.cells[3].value = '$currency${_money(0)}';
      row.style = PdfGridRowStyle(
        textBrush: PdfSolidBrush(muted),
        font: regular,
      );
    }
    grid.columns[0].width = 64;
    grid.columns[1].width = 210;
    grid.columns[2].width = 120;
    grid.columns[3].width = 86;
    return grid;
  }

  static String _rangeLabel(ReportDateRange range) =>
      '${displayDateFormat.format(range.start)} – '
      '${displayDateFormat.format(range.endInclusive)}';

  static String _money(double value) => NumberFormat('#,##0.00').format(value);

  static String _shorten(String value, int max) =>
      value.length <= max ? value : '${value.substring(0, max - 1)}…';
}
