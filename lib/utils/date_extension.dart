import 'package:intl/intl.dart';

/// Shared display format for standalone dates ('28 Oct 2026'). Reuse this
/// instance instead of building `DateFormat('dd MMM yyyy')` per call — intl
/// construction is not free and the pattern is app-wide.
final DateFormat displayDateFormat = DateFormat('dd MMM yyyy');

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

