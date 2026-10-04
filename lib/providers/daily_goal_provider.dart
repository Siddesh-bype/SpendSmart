import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings_provider.dart';

/// Per-day spending limits, keyed by 'YYYY-MM-DD'.
///
/// Stored as one JSON blob in SharedPreferences rather than a Hive box: the
/// data is a handful of numbers, and a new box would mean a new adapter and
/// type id for no benefit.
final dailyGoalProvider =
    NotifierProvider<DailyGoalNotifier, Map<String, double>>(
      DailyGoalNotifier.new,
    );

class DailyGoalNotifier extends Notifier<Map<String, double>> {
  static const _key = 'daily_goals';

  @override
  Map<String, double> build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is num) entry.key.toString(): (entry.value as num).toDouble(),
      };
    } catch (_) {
      // Corrupt blob: start clean rather than blocking the whole app.
      return const {};
    }
  }

  static String keyFor(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  Future<void> setGoal(DateTime day, double limit) async {
    final next = Map<String, double>.from(state);
    if (limit <= 0) {
      next.remove(keyFor(day));
    } else {
      next[keyFor(day)] = limit;
    }
    await _persist(next);
  }

  Future<void> _persist(Map<String, double> next) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(next));
    state = next;
  }
}
