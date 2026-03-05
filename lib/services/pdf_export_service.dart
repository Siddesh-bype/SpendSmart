import 'dart:io';
import 'dart:ui' show Rect, Offset;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/category.dart';

class PdfExportService {
  /// Generates a PDF statement of expenses and returns the file path
  static Future<String> exportToPDF(
    List<Expense> expenses, {
    String currency = '₹',
    String title = 'SpendSmart - Expense Report',
  }) async {
    // Create PDF document
    final document = PdfDocument();
    final page = document.pages.add();
    final graphics = page.graphics;
    final pageWidth = page.getClientSize().width;
    final pageHeight = page.getClientSize().height;

    // Colors
    final primaryColor = PdfColor(99, 102, 241); // Indigo
    final lightGray = PdfColor(243, 244, 246);
    final darkText = PdfColor(17, 24, 39);
    final grayText = PdfColor(107, 114, 128);
    final redColor = PdfColor(239, 68, 68);

    // Fonts
    final headerFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final normalFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);

    double y = 20;

    // ---- Header ----
    graphics.drawRectangle(
      brush: PdfSolidBrush(primaryColor),
      bounds: Rect.fromLTWH(0, 0, pageWidth, 70),
    );
    graphics.drawString(
      'SpendSmart', 
      PdfStandardFont(PdfFontFamily.helvetica, 22, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      bounds: Rect.fromLTWH(20, 12, pageWidth - 40, 30),
    );
    graphics.drawString(
      'Expense Report  •  Generated ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
      PdfStandardFont(PdfFontFamily.helvetica, 9),
      brush: PdfSolidBrush(PdfColor(199, 210, 254)),
      bounds: Rect.fromLTWH(20, 42, pageWidth - 40, 20),
    );
    y = 90;

    // ---- Summary Section ----
    final sorted = List<Expense>.from(expenses)..sort((a, b) => b.date.compareTo(a.date));
    final totalSpent = sorted.fold(0.0, (a, b) => a + b.amount);

    // Category breakdown
    final catSums = <String, double>{};
    for (final e in sorted) {
      catSums[e.category.name] = (catSums[e.category.name] ?? 0) + e.amount;
    }
    final topCats = catSums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Summary box
    graphics.drawRectangle(
      brush: PdfSolidBrush(lightGray),
      bounds: Rect.fromLTWH(0, y, pageWidth, 80),
    );
    graphics.drawString('SUMMARY', headerFont,
      brush: PdfSolidBrush(primaryColor),
      bounds: Rect.fromLTWH(20, y + 10, 200, 20));

    graphics.drawString('Total Expenses', normalFont,
      brush: PdfSolidBrush(grayText),
      bounds: Rect.fromLTWH(20, y + 30, 120, 20));
    graphics.drawString('$currency${NumberFormat('#,##0.00').format(totalSpent)}',
      PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(redColor),
      bounds: Rect.fromLTWH(20, y + 46, 200, 20));

    graphics.drawString('Total Transactions', normalFont,
      brush: PdfSolidBrush(grayText),
      bounds: Rect.fromLTWH(200, y + 30, 120, 20));
    graphics.drawString('${sorted.length}',
      PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(darkText),
      bounds: Rect.fromLTWH(200, y + 46, 100, 20));

    if (topCats.isNotEmpty) {
      graphics.drawString('Top Category', normalFont,
        brush: PdfSolidBrush(grayText),
        bounds: Rect.fromLTWH(350, y + 30, 140, 20));
      graphics.drawString(topCats.first.key,
        PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(primaryColor),
        bounds: Rect.fromLTWH(350, y + 46, 180, 20));
    }
    y += 96;

    // ---- Category Breakdown ----
    graphics.drawString('CATEGORY BREAKDOWN', headerFont,
      brush: PdfSolidBrush(primaryColor),
      bounds: Rect.fromLTWH(20, y, 200, 20));
    y += 24;

    for (final cat in topCats.take(6)) {
      final pct = totalSpent > 0 ? cat.value / totalSpent : 0;
      final barWidth = (pageWidth - 160) * pct;

      graphics.drawString(cat.key, normalFont,
        brush: PdfSolidBrush(darkText),
        bounds: Rect.fromLTWH(20, y, 120, 16));
      graphics.drawRectangle(
        brush: PdfSolidBrush(lightGray),
        bounds: Rect.fromLTWH(140, y + 2, pageWidth - 220, 10));
      graphics.drawRectangle(
        brush: PdfSolidBrush(primaryColor),
        bounds: Rect.fromLTWH(140, y + 2, barWidth, 10));
      graphics.drawString('$currency${NumberFormat('#,##0').format(cat.value)}  ${(pct*100).toStringAsFixed(0)}%',
        smallFont,
        brush: PdfSolidBrush(grayText),
        bounds: Rect.fromLTWH(pageWidth - 78, y, 78, 16));
      y += 20;
    }
    y += 12;

    // ---- Transaction Table ----
    graphics.drawString('TRANSACTION HISTORY', headerFont,
      brush: PdfSolidBrush(primaryColor),
      bounds: Rect.fromLTWH(20, y, 200, 20));
    y += 24;

    // Table header
    graphics.drawRectangle(
      brush: PdfSolidBrush(primaryColor),
      bounds: Rect.fromLTWH(0, y, pageWidth, 20));
    graphics.drawString('Date', headerFont, brush: PdfSolidBrush(PdfColor(255,255,255)),
      bounds: Rect.fromLTWH(10, y + 4, 70, 14));
    graphics.drawString('Description', headerFont, brush: PdfSolidBrush(PdfColor(255,255,255)),
      bounds: Rect.fromLTWH(85, y + 4, 160, 14));
    graphics.drawString('Category', headerFont, brush: PdfSolidBrush(PdfColor(255,255,255)),
      bounds: Rect.fromLTWH(250, y + 4, 100, 14));
    graphics.drawString('Amount', headerFont, brush: PdfSolidBrush(PdfColor(255,255,255)),
      bounds: Rect.fromLTWH(pageWidth - 80, y + 4, 80, 14));
    y += 22;

    // Rows
    bool alternate = false;
    PdfPage currentPdfPage = page;
    PdfGraphics currentGraphics = graphics;

    for (final e in sorted) {
      // New page if needed
      if (y > pageHeight - 40) {
        currentPdfPage = document.pages.add();
        currentGraphics = currentPdfPage.graphics;
        y = 20;
      }

      if (alternate) {
        currentGraphics.drawRectangle(
          brush: PdfSolidBrush(lightGray),
          bounds: Rect.fromLTWH(0, y, pageWidth, 18));
      }

      currentGraphics.drawString(
        DateFormat('dd/MM/yy').format(e.date), normalFont,
        brush: PdfSolidBrush(darkText),
        bounds: Rect.fromLTWH(10, y + 3, 70, 14));
      currentGraphics.drawString(
        e.title.length > 28 ? '${e.title.substring(0, 25)}...' : e.title,
        normalFont, brush: PdfSolidBrush(darkText),
        bounds: Rect.fromLTWH(85, y + 3, 160, 14));
      currentGraphics.drawString(
        e.category.name, normalFont,
        brush: PdfSolidBrush(grayText),
        bounds: Rect.fromLTWH(250, y + 3, 100, 14));
      currentGraphics.drawString(
        '$currency${NumberFormat('#,##0.00').format(e.amount)}',
        normalFont, brush: PdfSolidBrush(redColor),
        bounds: Rect.fromLTWH(pageWidth - 80, y + 3, 78, 14));

      alternate = !alternate;
      y += 18;
    }

    // Footer
    currentGraphics.drawLine(
      PdfPen(PdfColor(229, 231, 235)),
      Offset(0, y + 4), Offset(pageWidth, y + 4));
    currentGraphics.drawString(
      'Generated by SpendSmart  •  ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
      smallFont, brush: PdfSolidBrush(grayText),
      bounds: Rect.fromLTWH(20, y + 8, pageWidth - 40, 16));

    // Save
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'SpendSmart_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    final path = '${dir.path}/$fileName';
    final file = File(path);
    await file.writeAsBytes(await document.save());
    document.dispose();
    return path;
  }
}
