import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/services/pdf_import_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test(
    'PDF parser keeps debit rows and rejects credits and invalid dates',
    () async {
      final document = PdfDocument();
      final page = document.pages.add();
      page.graphics.drawString(
        '10/07/2026 Coffee Shop 250.00 Dr\n'
        '10/07/2026 Salary 50000.00 Cr\n'
        '30/02/2026 Invalid Date 100.00 Dr',
        PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(10, 10, 500, 200),
      );
      final file = File(
        '${Directory.systemTemp.path}/spendsmart_parser_test.pdf',
      );
      await file.writeAsBytes(await document.save(), flush: true);
      document.dispose();

      addTearDown(() async {
        if (await file.exists()) await file.delete();
      });

      final expenses = await PdfImportService.parseBankStatement(file);

      expect(expenses, hasLength(1));
      expect(expenses.single.title, contains('Coffee Shop'));
      expect(expenses.single.date.year, 2026);
    },
  );
}
