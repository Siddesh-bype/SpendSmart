import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/services/csv_import_service.dart';

void main() {
  test('CSV parser accepts explicit aliases and skips malformed rows', () {
    final result = CsvImportService.parse('''
Transaction Date,Merchant,Debit Amount
2026-07-10,Coffee Shop,250.50
2026-02-30,Impossible Date,100
2026-07-10,Missing Amount
''');

    expect(result.imported, hasLength(1));
    expect(result.imported.single.title, 'Coffee Shop');
    expect(result.imported.single.amount, 250.50);
    expect(result.skipped, 2);
  });

  test('CSV parser does not accept loosely matching required headers', () {
    final result = CsvImportService.parse('''
Update,Paid By,Total
2026-07-10,Someone,100
''');

    expect(result.imported, isEmpty);
    expect(result.errors.single, contains('Missing required columns'));
  });
}
