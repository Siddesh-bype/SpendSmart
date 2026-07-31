import 'package:intl/intl.dart';

extension CustomDateExtension on DateTime {
  DateTime customMonthStart(int startingDay) {
    if (day >= startingDay) {
      return DateTime(year, month, startingDay);
    } else {
      return DateTime(year, month - 1, startingDay);
    }
  }

  DateTime customMonthEnd(int startingDay) {
    if (day >= startingDay) {
      return DateTime(year, month + 1, startingDay).subtract(const Duration(seconds: 1));
    } else {
      return DateTime(year, month, startingDay).subtract(const Duration(seconds: 1));
    }
  }

  bool isDefaultMonth(int currentMonth, int currentYear) {
    return month == currentMonth && year == currentYear;
  }

  /// Whether this date falls in the custom month starting on [startingDay] of
  /// [targetMonth]/[targetYear].
  ///
  /// Half-open: `[start, nextStart)`. Every screen filters whole expense lists
  /// through here on each rebuild, so this stays allocation-light — two
  /// DateTimes, no Durations.
  bool isTargetCustomMonth(int targetMonth, int targetYear, int startingDay) {
    final start = DateTime(targetYear, targetMonth, startingDay);
    final nextStart = DateTime(targetYear, targetMonth + 1, startingDay);
    return !isBefore(start) && isBefore(nextStart);
  }
}

/// Groups a list of items by calendar month label ('January 2026').
///
/// Returns a [LinkedHashMap]-ordered map so months appear in insertion order
/// (which matches the list's existing sort order).
///
/// Example:
/// ```dart
/// final grouped = groupByMonth(expenses, (e) => e.date);
/// ```
Map<String, List<T>> groupByMonth<T>(
  List<T> items,
  DateTime Function(T) dateOf,
) {
  final result = <String, List<T>>{};
  for (final item in items) {
    final key = DateFormat('MMMM yyyy').format(dateOf(item));
    result.putIfAbsent(key, () => []).add(item);
  }
  return result;
}

