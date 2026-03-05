import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/app_notification.dart';
import '../providers/notification_provider.dart';
import '../utils/constants.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(notificationProvider.notifier).markAllRead(),
              child: const Text('Mark all read', style: TextStyle(color: AppColors.primary)),
            ),
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmpty()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _NotifCard(notification: notifications[i]),
            ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No notifications yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Budget alerts and spending tips will appear here.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('This will remove all notifications. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(notificationProvider.notifier).clearAll();
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _NotifCard extends ConsumerWidget {
  final AppNotification notification;
  const _NotifCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = _iconAndColor(notification.type);

    return GestureDetector(
      onTap: () => ref.read(notificationProvider.notifier).markRead(notification.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Theme.of(context).cardTheme.color ?? Colors.white
              : color.withValues(alpha: 0.08),
          border: Border.all(
            color: notification.isRead ? Colors.transparent : color.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                                fontSize: 13,
                              )),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(notification.body,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('MMM d, h:mm a').format(notification.time),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _iconAndColor(NotifType type) => switch (type) {
        NotifType.budgetExceeded => (Icons.warning_rounded, Colors.red),
        NotifType.budgetWarning => (Icons.trending_up_rounded, Colors.orange),
        NotifType.spendingMilestone => (Icons.emoji_events_rounded, Colors.amber),
        NotifType.tip => (Icons.lightbulb_outline_rounded, AppColors.primary),
      };
}
