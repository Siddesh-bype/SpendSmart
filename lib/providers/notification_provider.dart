import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/app_notification.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../services/expense_category_resolver.dart';
import '../utils/financial_period.dart';
import 'app_settings_provider.dart';

final notificationProvider =
    NotifierProvider<NotificationNotifier, List<AppNotification>>(
      NotificationNotifier.new,
    );

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
  void checkBudgets<K>(
    List<Budget> budgets,
    Map<K, double> spending, {
    String currency = '₹',
    FinancialPeriod? period,
    ExpenseCategoryCatalog catalog = const ExpenseCategoryCatalog.empty(),
  }) {
    final now = DateTime.now();
    final activePeriod = period ?? FinancialPeriod.containing(now, 1);
    bool isInActivePeriod(AppNotification notification) =>
        activePeriod.contains(notification.time);

    for (final budget in budgets) {
      if (budget.monthlyLimit <= 0) continue;
      final label = budget.customCategoryId == null
          ? budget.category.displayName
          : (catalog.customById(budget.customCategoryId!)?.name ??
              budget.customCategoryId!);
      final categoryKey = budget.customCategoryId == null
          ? ExpenseCategoryKey.builtIn(budget.category).storageKey
          : ExpenseCategoryKey.custom(budget.customCategoryId!).storageKey;
      final spent = _spendingForBudget(spending, budget);
      final pct = spent / budget.monthlyLimit;
      // Notifications saved before 2.2.0 have no categoryKey; match their
      // "<Kind>: <label>" title instead so the upgrade doesn't re-alert.
      bool sameBudget(AppNotification n) =>
          n.categoryKey == categoryKey ||
          (n.categoryKey == null && n.title.endsWith(': $label'));

      final alreadyHas80 = state.any(
        (n) =>
            isInActivePeriod(n) &&
            n.type == NotifType.budgetWarning &&
            sameBudget(n),
      );
      final alreadyHasOver = state.any(
        (n) =>
            isInActivePeriod(n) &&
            n.type == NotifType.budgetExceeded &&
            sameBudget(n),
      );

      if (pct >= 1.0 && !alreadyHasOver) {
        _add(
          AppNotification(
            id: const Uuid().v4(),
             title: '🚨 Budget Exceeded: $label',
             body:
                'You\'ve spent $currency${spent.toStringAsFixed(0)} of your '
                '$currency${budget.monthlyLimit.toStringAsFixed(0)} '
                 '$label budget.',
             time: DateTime.now(),
             type: NotifType.budgetExceeded,
             categoryKey: categoryKey,
          ),
        );
      } else if (pct >= budget.alertAt && !alreadyHas80) {
        _add(
          AppNotification(
            id: const Uuid().v4(),
             title: '⚠️ Budget Warning: $label',
            body:
                '${(pct * 100).toStringAsFixed(0)}% of your '
                 '$label budget used. '
                '$currency${(budget.monthlyLimit - spent).toStringAsFixed(0)} remaining.',
             time: DateTime.now(),
             type: NotifType.budgetWarning,
             categoryKey: categoryKey,
          ),
        );
      }
    }
  }

  double _spendingForBudget<K>(Map<K, double> spending, Budget budget) {
    final expected = budget.customCategoryId == null
        ? ExpenseCategoryKey.builtIn(budget.category)
        : ExpenseCategoryKey.custom(budget.customCategoryId!);
    // Also accept the legacy key shapes: a bare Category or custom id.
    final legacy = budget.customCategoryId ?? budget.category;
    for (final entry in spending.entries) {
      if (entry.key == expected || entry.key == legacy) {
        return entry.value;
      }
    }
    return 0;
  }

  void _add(AppNotification notif) {
    state = [notif, ...state];
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(
        _prefsKey,
        jsonEncode(state.map(_notifToJson).toList()),
      );
    } catch (_) {
      // Non-critical — skip if prefs unavailable
    }
  }

  // ── Serialization ───────────────────────────────────────────────────────────
  //
  // `type` is a STABLE id, not the enum index: id 2 belonged to the removed
  // `spendingMilestone` variant and must stay vacant so old payloads still
  // decode (they map to [NotifType.tip]). Never reuse 2 or reorder these.

  static Map<String, dynamic> _notifToJson(AppNotification n) => {
    'id': n.id,
    'title': n.title,
    'body': n.body,
    'time': n.time.toIso8601String(),
    'type': switch (n.type) {
      NotifType.budgetWarning => 0,
      NotifType.budgetExceeded => 1,
      NotifType.tip => 3,
    },
    'isRead': n.isRead,
    'categoryKey': n.categoryKey,
  };

  static AppNotification _notifFromJson(Map<String, dynamic> m) =>
      AppNotification(
        id: m['id'] as String,
        title: m['title'] as String,
        body: m['body'] as String,
        time: DateTime.parse(m['time'] as String),
        type: switch (m['type'] as int) {
          0 => NotifType.budgetWarning,
          1 => NotifType.budgetExceeded,
          // 2 = legacy `spendingMilestone`: fall back to a sane default.
          2 || 3 => NotifType.tip,
          _ => NotifType.tip,
        },
        isRead: (m['isRead'] as bool?) ?? false,
        categoryKey: m['categoryKey'] as String?,
      );
}
