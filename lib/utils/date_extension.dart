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

  bool isTargetCustomMonth(int targetMonth, int targetYear, int startingDay) {
    // If we're looking at a specific month, e.g., March 2026, the custom month
    // starts on March `startingDay` and ends on April `startingDay - 1`.
    final start = DateTime(targetYear, targetMonth, startingDay);
    final end = DateTime(targetYear, targetMonth + 1, startingDay).subtract(const Duration(seconds: 1));
    return isAfter(start.subtract(const Duration(seconds: 1))) && isBefore(end.add(const Duration(seconds: 1)));
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

