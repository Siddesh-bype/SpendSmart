import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/app_notification.dart';
import '../providers/notification_provider.dart';
import '../utils/theme.dart';
import '../utils/design.dart';
import '../widgets/empty_state.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);
    final scheme = SchemeTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
                minimumSize: const Size(64, 44),
              ),
              onPressed: () => ref.read(notificationProvider.notifier).markAllRead(),
              child: const Text('Mark all read'),
            ),
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              color: scheme.muted,
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmpty(scheme)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _NotifCard(notification: notifications[i]),
            ),
    );
  }

  Widget _buildEmpty(SchemeTheme scheme) => EmptyState(
        icon: Icons.notifications_none_rounded,
        iconColor: scheme.muted.withValues(alpha: 0.5),
        title: 'No notifications yet',
        subtitle: 'Budget alerts and spending tips will appear here.',
      );

  void _confirmClear(BuildContext context, WidgetRef ref) {
    final scheme = SchemeTheme.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('This will remove all notifications. Are you sure?'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.bg,
              minimumSize: const Size(64, 44),
            ),
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
    final scheme = SchemeTheme.of(context);
    final (icon, color, label) = _indicator(scheme, notification.type);

    return GestureDetector(
      onTap: () => ref.read(notificationProvider.notifier).markRead(notification.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(
            color: notification.isRead ? scheme.border : color,
          ),
          borderRadius: AppRadius.mdAll,
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
                                fontSize: AppType.label,
                                color: scheme.ink,
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
                    // Severity is never color-only: text label + icon accompany the hue.
                    Row(
                      children: [
                        Icon(icon, color: color, size: 12),
                        const SizedBox(width: 4),
                        Text(label,
                            style: TextStyle(
                              color: color,
                              fontSize: AppType.micro,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(notification.body,
                        style: TextStyle(color: scheme.muted, fontSize: AppType.caption),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('MMM d, h:mm a').format(notification.time),
                      style: TextStyle(color: scheme.muted, fontSize: AppType.caption),
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

  (IconData, Color, String) _indicator(SchemeTheme scheme, NotifType type) => switch (type) {
        NotifType.budgetExceeded => (Icons.warning_rounded, scheme.error, 'Budget exceeded'),
        NotifType.budgetWarning => (Icons.trending_up_rounded, scheme.warning, 'Budget warning'),
        NotifType.tip => (Icons.lightbulb_outline_rounded, scheme.primary, 'Tip'),
      };
}
