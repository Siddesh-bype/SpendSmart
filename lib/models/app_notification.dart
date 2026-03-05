class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime time;
  final NotifType type;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id, title: title, body: body, time: time, type: type,
    isRead: isRead ?? this.isRead,
  );
}

enum NotifType {
  budgetWarning,
  budgetExceeded,
  spendingMilestone,
  tip,
}
