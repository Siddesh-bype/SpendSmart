import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/category.dart';

class ExportService {
  static Future<String> exportToCSV(List<Expense> expenses) async {
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
        exp.id,
        DateFormat('yyyy-MM-dd HH:mm:ss').format(exp.date),
        exp.title,
        exp.amount,
        exp.category.name,
        exp.source,
        exp.isManual,
        exp.isUncategorized,
        exp.note ?? ""
      ]);
    }

    String csv = const CsvEncoder().convert(rows);

    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/SpendSmart_Export_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv";
    final file = File(path);
    await file.writeAsString(csv);
    
    return path;
  }
}
