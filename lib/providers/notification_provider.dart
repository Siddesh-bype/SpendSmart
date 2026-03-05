import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/app_notification.dart';
import '../models/budget.dart';
import '../models/category.dart';

final notificationProvider =
    NotifierProvider<NotificationNotifier, List<AppNotification>>(
        NotificationNotifier.new);

class NotificationNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => [];

  void markAllRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void markRead(String id) {
    state = state
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
  }

  void clearAll() => state = [];

  /// Checks budgets against spending and adds relevant notifications.
  void checkBudgets(List<Budget> budgets, Map<Category, double> spending) {
    for (final budget in budgets) {
      if (budget.monthlyLimit <= 0) continue;
      final spent = spending[budget.category] ?? 0.0;
      final pct = spent / budget.monthlyLimit;

      // Already notified for this category this session? Skip duplicates.
      final alreadyHas80 = state.any((n) =>
          n.type == NotifType.budgetWarning &&
          n.title.contains(budget.category.name));
      final alreadyHasOver = state.any((n) =>
          n.type == NotifType.budgetExceeded &&
          n.title.contains(budget.category.name));

      if (pct >= 1.0 && !alreadyHasOver) {
        _add(AppNotification(
          id: const Uuid().v4(),
          title: '🚨 Budget Exceeded: ${budget.category.name}',
          body:
              'You\'ve spent ₹${spent.toStringAsFixed(0)} of your ₹${budget.monthlyLimit.toStringAsFixed(0)} ${budget.category.name} budget.',
          time: DateTime.now(),
          type: NotifType.budgetExceeded,
        ));
      } else if (pct >= 0.8 && !alreadyHas80) {
        _add(AppNotification(
          id: const Uuid().v4(),
          title: '⚠️ Budget Warning: ${budget.category.name}',
          body:
              '${(pct * 100).toStringAsFixed(0)}% of your ${budget.category.name} budget used. ₹${(budget.monthlyLimit - spent).toStringAsFixed(0)} remaining.',
          time: DateTime.now(),
          type: NotifType.budgetWarning,
        ));
      }
    }
  }

  /// Add a spending milestone tip.
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
  }
}
