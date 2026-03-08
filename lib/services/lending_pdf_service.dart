import 'dart:io';
import 'dart:ui' show Rect;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/lending.dart';

class LendingPdfService {
  static Future<String> exportToPDF(
    List<Lending> lendings, {
    String currency = '₹',
  }) async {
    final document = PdfDocument();
    final page = document.pages.add();
    final graphics = page.graphics;
    final pageWidth = page.getClientSize().width;
    final pageHeight = page.getClientSize().height;

    // Colors
    final blueColor   = PdfColor(21, 101, 192);   // Material Blue 800
    final lightBlue   = PdfColor(66, 165, 245);   // Material Blue 400
    final white        = PdfColor(255, 255, 255);
    final darkText     = PdfColor(17, 24, 39);
    final grayText     = PdfColor(107, 114, 128);
    final greenColor   = PdfColor(46, 125, 50);
    final redColor     = PdfColor(198, 40, 40);
    final rowAlt       = PdfColor(232, 240, 254);  // Very light blue row

    // Fonts
    final boldFont   = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final normalFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    final smallFont  = PdfStandardFont(PdfFontFamily.helvetica, 8);
    final titleFont  = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
    final subFont    = PdfStandardFont(PdfFontFamily.helvetica, 9);

    double y = 0;

    // ── Header banner ─────────────────────────────────────────────
    graphics.drawRectangle(
      brush: PdfSolidBrush(blueColor),
      bounds: Rect.fromLTWH(0, 0, pageWidth, 72),
    );
    graphics.drawString(
      'SpendSmart',
      PdfStandardFont(PdfFontFamily.helvetica, 11),
      brush: PdfSolidBrush(PdfColor(200, 220, 255)),
      bounds: Rect.fromLTWH(20, 12, pageWidth - 40, 16),
    );
    graphics.drawString(
      'Friends & Lending Report',
      titleFont,
      brush: PdfSolidBrush(white),
      bounds: Rect.fromLTWH(20, 28, pageWidth - 40, 28),
    );
    graphics.drawString(
      'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
      subFont,
      brush: PdfSolidBrush(PdfColor(200, 220, 255)),
      bounds: Rect.fromLTWH(20, 56, pageWidth - 40, 12),
    );
    y = 84;

    // ── Summary section ────────────────────────────────────────────
    final active   = lendings.where((l) => !l.isSettled).toList();
    final settled  = lendings.where((l) => l.isSettled).toList();

    double totalOwedToMe = 0;
    double totalIOwe     = 0;
    final Map<String, double> netByFriend = {};

    for (final l in active) {
      if (l.isIGave) {
        totalOwedToMe += l.amount;
        netByFriend[l.friendName] = (netByFriend[l.friendName] ?? 0) + l.amount;
      } else {
        totalIOwe += l.amount;
        netByFriend[l.friendName] = (netByFriend[l.friendName] ?? 0) - l.amount;
      }
    }

    // Summary boxes
    final boxW = (pageWidth - 52) / 2;
    _drawSummaryBox(graphics, 20, y, boxW, 52,
        'Total Owed to You', '$currency${NumberFormat('#,##0.##').format(totalOwedToMe)}',
        PdfColor(232, 245, 233), greenColor, normalFont, boldFont);
    _drawSummaryBox(graphics, 28 + boxW, y, boxW, 52,
        'You Owe Others', '$currency${NumberFormat('#,##0.##').format(totalIOwe)}',
        PdfColor(255, 235, 238), redColor, normalFont, boldFont);
    y += 64;

    // ── Per-friend net balance ─────────────────────────────────────
    if (netByFriend.isNotEmpty) {
      graphics.drawString('Net Balance per Friend', boldFont,
          brush: PdfSolidBrush(blueColor),
          bounds: Rect.fromLTWH(20, y, pageWidth - 40, 14));
      y += 18;

      for (final entry in netByFriend.entries) {
        final isPositive = entry.value >= 0;
        graphics.drawRectangle(
          brush: PdfSolidBrush(isPositive
              ? PdfColor(232, 245, 233)
              : PdfColor(255, 235, 238)),
          bounds: Rect.fromLTWH(20, y, pageWidth - 40, 18),
        );
        graphics.drawString(entry.key, normalFont,
            brush: PdfSolidBrush(darkText),
            bounds: Rect.fromLTWH(28, y + 3, 200, 14));
        final balLabel = isPositive
            ? 'Owes you $currency${NumberFormat('#,##0.##').format(entry.value)}'
            : 'You owe $currency${NumberFormat('#,##0.##').format(entry.value.abs())}';
        graphics.drawString(balLabel, normalFont,
            brush: PdfSolidBrush(isPositive ? greenColor : redColor),
            bounds: Rect.fromLTWH(pageWidth - 170, y + 3, 150, 14),
            format: PdfStringFormat(alignment: PdfTextAlignment.right));
        y += 20;
      }
      y += 8;
    }

    // ── Active slips table ─────────────────────────────────────────
    if (active.isNotEmpty) {
      if (y > pageHeight - 60) {
        final newPage = document.pages.add();
        y = 20;
        _drawTableOnPage(document, newPage, active, currency, blueColor, lightBlue,
            white, darkText, grayText, greenColor, redColor, rowAlt,
            boldFont, normalFont, smallFont, pageHeight);
      } else {
        _drawTableOnPage(document, page, active, currency, blueColor, lightBlue,
            white, darkText, grayText, greenColor, redColor, rowAlt,
            boldFont, normalFont, smallFont, pageHeight,
            startY: y, label: 'Active Slips (${active.length})');
      }
    }

    // ── Settled slips table ────────────────────────────────────────
    if (settled.isNotEmpty) {
      final settledPage = document.pages.add();
      _drawTableOnPage(document, settledPage, settled, currency, grayText,
          PdfColor(150, 150, 150), white, darkText, grayText, greenColor,
          redColor, PdfColor(245, 245, 245), boldFont, normalFont, smallFont,
          settledPage.getClientSize().height,
          label: 'Settled Slips (${settled.length})');
    }

    // Save
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'SpendSmart_Lending_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    final path = '${dir.path}/$fileName';
    await File(path).writeAsBytes(await document.save());
    document.dispose();
    return path;
  }

  static void _drawSummaryBox(
    PdfGraphics g,
    double x, double y, double w, double h,
    String label, String value,
    PdfColor bg, PdfColor valueColor,
    PdfFont labelFont, PdfFont valueFont,
  ) {
    g.drawRectangle(
        brush: PdfSolidBrush(bg),
        bounds: Rect.fromLTWH(x, y, w, h));
    g.drawString(label, labelFont,
        brush: PdfSolidBrush(PdfColor(80, 80, 80)),
        bounds: Rect.fromLTWH(x + 10, y + 8, w - 20, 14));
    g.drawString(value, valueFont,
        brush: PdfSolidBrush(valueColor),
        bounds: Rect.fromLTWH(x + 10, y + 24, w - 20, 20));
  }

  static void _drawTableOnPage(
    PdfDocument document,
    PdfPage page,
    List<Lending> rows,
    String currency,
    PdfColor headerBg,
    PdfColor headerBg2,
    PdfColor headerText,
    PdfColor darkText,
    PdfColor grayText,
    PdfColor greenColor,
    PdfColor redColor,
    PdfColor rowAlt,
    PdfFont boldFont,
    PdfFont normalFont,
    PdfFont smallFont,
    double pageHeight, {
    double startY = 20,
    String label = 'Slips',
  }) {
    final g = page.graphics;
    final pageWidth = page.getClientSize().width;
    double y = startY;

    // Section label
    g.drawString(label, boldFont,
        brush: PdfSolidBrush(headerBg),
        bounds: Rect.fromLTWH(20, y, pageWidth - 40, 14));
    y += 18;

    // Table header
    g.drawRectangle(
        brush: PdfSolidBrush(headerBg),
        bounds: Rect.fromLTWH(20, y, pageWidth - 40, 18));
    const cols = ['Friend', 'Type', 'Amount', 'Date', 'Note'];
    final colX = [28.0, 130.0, 210.0, 290.0, 370.0];
    for (var i = 0; i < cols.length; i++) {
      g.drawString(cols[i], boldFont,
          brush: PdfSolidBrush(headerText),
          bounds: Rect.fromLTWH(colX[i], y + 3, 80, 14));
    }
    y += 20;

    bool alt = false;
    PdfPage currentPage = page;
    PdfGraphics currentG = g;
    double currentY = y;

    for (final l in rows) {
      if (currentY > pageHeight - 30) {
        currentPage = document.pages.add();
        currentG = currentPage.graphics;
        currentY = 20;
      }

      if (alt) {
        currentG.drawRectangle(
            brush: PdfSolidBrush(rowAlt),
            bounds: Rect.fromLTWH(20, currentY, pageWidth - 40, 16));
      }

      currentG.drawString(l.friendName, normalFont,
          brush: PdfSolidBrush(darkText),
          bounds: Rect.fromLTWH(colX[0], currentY + 2, 95, 13));
      currentG.drawString(l.isIGave ? 'I Gave' : 'I Owe', normalFont,
          brush: PdfSolidBrush(l.isIGave ? greenColor : redColor),
          bounds: Rect.fromLTWH(colX[1], currentY + 2, 70, 13));
      currentG.drawString(
          '$currency${NumberFormat('#,##0.##').format(l.amount)}',
          normalFont,
          brush: PdfSolidBrush(l.isIGave ? greenColor : redColor),
          bounds: Rect.fromLTWH(colX[2], currentY + 2, 70, 13));
      currentG.drawString(
          DateFormat('d MMM yy').format(l.date), normalFont,
          brush: PdfSolidBrush(grayText),
          bounds: Rect.fromLTWH(colX[3], currentY + 2, 70, 13));
      if (l.note.isNotEmpty) {
        currentG.drawString(l.note, smallFont,
            brush: PdfSolidBrush(grayText),
            bounds: Rect.fromLTWH(colX[4], currentY + 2, pageWidth - colX[4] - 20, 13));
      }

      currentY += 18;
      alt = !alt;
    }
  }
}
