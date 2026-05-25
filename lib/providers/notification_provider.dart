import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/app_notification.dart';
import '../models/budget.dart';
import '../models/category.dart';
import 'app_settings_provider.dart';

final notificationProvider =
    NotifierProvider<NotificationNotifier, List<AppNotification>>(
        NotificationNotifier.new);

class NotificationNotifier extends Notifier<List<AppNotification>> {
  static const _prefsKey = 'app_notifications_v1';

  @override
  List<AppNotification> build() {
    // Load persisted notifications from SharedPreferences on startup.
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list
            .map((e) => _notifFromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Corrupt prefs — start fresh
    }
    return [];
  }

  void markAllRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    _persist();
  }

  void markRead(String id) {
    state = state
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    _persist();
  }

  void clearAll() {
    state = [];
    _persist();
  }

  /// Checks budgets against spending and adds relevant notifications.
  /// [currency] should come from appSettingsProvider.currency.
  void checkBudgets(
    List<Budget> budgets,
    Map<Category, double> spending, {
    String currency = '₹',
  }) {
    for (final budget in budgets) {
      if (budget.monthlyLimit <= 0) continue;
      final spent = spending[budget.category] ?? 0.0;
      final pct = spent / budget.monthlyLimit;

      final alreadyHas80 = state.any((n) =>
          n.type == NotifType.budgetWarning &&
          n.title.contains(budget.category.displayName));
      final alreadyHasOver = state.any((n) =>
          n.type == NotifType.budgetExceeded &&
          n.title.contains(budget.category.displayName));

      if (pct >= 1.0 && !alreadyHasOver) {
        _add(AppNotification(
          id: const Uuid().v4(),
          title: '🚨 Budget Exceeded: ${budget.category.displayName}',
          body:
              'You\'ve spent $currency${spent.toStringAsFixed(0)} of your '
              '$currency${budget.monthlyLimit.toStringAsFixed(0)} '
              '${budget.category.displayName} budget.',
          time: DateTime.now(),
          type: NotifType.budgetExceeded,
        ));
      } else if (pct >= budget.alertAt && !alreadyHas80) {
        _add(AppNotification(
          id: const Uuid().v4(),
          title: '⚠️ Budget Warning: ${budget.category.displayName}',
          body:
              '${(pct * 100).toStringAsFixed(0)}% of your '
              '${budget.category.displayName} budget used. '
              '$currency${(budget.monthlyLimit - spent).toStringAsFixed(0)} remaining.',
          time: DateTime.now(),
          type: NotifType.budgetWarning,
        ));
      }
    }
  }

  /// Add a spending milestone tip notification.
  void addTip(String title, String body) {
    _add(AppNotification(
      id: const Uuid().v4(),
      title: title,
      body: body,
      time: DateTime.now(),
      type: NotifType.tip,
    ));
  }

  void _add(AppNotification notif) {
    state = [notif, ...state];
    _persist();
  }

  void _persist() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      prefs.setString(_prefsKey, jsonEncode(state.map(_notifToJson).toList()));
    } catch (_) {
      // Non-critical — skip if prefs unavailable
    }
  }

  // ── Serialization ───────────────────────────────────────────────────────────

  static Map<String, dynamic> _notifToJson(AppNotification n) => {
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'time': n.time.toIso8601String(),
        'type': n.type.index,
        'isRead': n.isRead,
      };

  static AppNotification _notifFromJson(Map<String, dynamic> m) =>
      AppNotification(
        id: m['id'] as String,
        title: m['title'] as String,
        body: m['body'] as String,
        time: DateTime.parse(m['time'] as String),
        type: NotifType.values[m['type'] as int],
        isRead: (m['isRead'] as bool?) ?? false,
      );
}
