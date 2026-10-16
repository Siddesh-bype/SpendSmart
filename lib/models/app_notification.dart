class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime time;
  final NotifType type;
  final bool isRead;
  final String? categoryKey;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    this.isRead = false,
    this.categoryKey,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id, title: title, body: body, time: time, type: type,
    isRead: isRead ?? this.isRead,
    categoryKey: categoryKey,
  );
}

enum NotifType {
  budgetWarning,
  budgetExceeded,
  tip,
}
