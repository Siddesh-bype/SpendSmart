import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/utils/date_extension.dart';

void main() {
  group('isTargetCustomMonth', () {
    test('a calendar month is bounded by its first and last instant', () {
      expect(DateTime(2026, 3, 1).isTargetCustomMonth(3, 2026, 1), isTrue);
      expect(
        DateTime(2026, 3, 31, 23, 59, 59).isTargetCustomMonth(3, 2026, 1),
        isTrue,
      );
      expect(DateTime(2026, 2, 28).isTargetCustomMonth(3, 2026, 1), isFalse);
      expect(DateTime(2026, 4, 1).isTargetCustomMonth(3, 2026, 1), isFalse);
    });

    // The previous implementation compared against `end - 1s`, so the final
    // second of a period fell outside every month.
    test('the last second before the next period still belongs to it', () {
      expect(
        DateTime(2026, 3, 31, 23, 59, 59, 999).isTargetCustomMonth(3, 2026, 1),
        isTrue,
      );
    });

    test('a custom start day shifts the window forward', () {
      // The "March" period runs Mar 15 -> Apr 14 when the cycle starts on 15.
      expect(DateTime(2026, 3, 15).isTargetCustomMonth(3, 2026, 15), isTrue);
      expect(DateTime(2026, 4, 14).isTargetCustomMonth(3, 2026, 15), isTrue);
      expect(DateTime(2026, 3, 14).isTargetCustomMonth(3, 2026, 15), isFalse);
      expect(DateTime(2026, 4, 15).isTargetCustomMonth(3, 2026, 15), isFalse);
    });

    test('consecutive periods never overlap and never leave a gap', () {
      // Every day of a year lands in exactly one period, for any start day.
      for (final startDay in [1, 5, 15, 28]) {
        for (var day = DateTime(2026, 1, 1);
            day.isBefore(DateTime(2027, 1, 1));
            day = day.add(const Duration(days: 1))) {
          var matches = 0;
          for (var month = -1; month <= 13; month++) {
            if (day.isTargetCustomMonth(month, 2026, startDay)) matches++;
          }
          expect(
            matches,
            1,
            reason: 'start day $startDay, $day matched $matches periods',
          );
        }
      }
    });
  });
}
