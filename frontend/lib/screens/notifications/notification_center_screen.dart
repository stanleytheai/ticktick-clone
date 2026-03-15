import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ticktick_clone/models/app_notification.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/notification_provider.dart';
import 'package:ticktick_clone/screens/tasks/task_detail_screen.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (user == null) return;
              switch (value) {
                case 'read_all':
                  ref
                      .read(firestoreServiceProvider)
                      .markAllNotificationsRead(user.uid);
                case 'clear_all':
                  _confirmClearAll(context, ref);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'read_all',
                child: ListTile(
                  leading: Icon(Icons.done_all),
                  title: Text('Mark all read'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep),
                  title: Text('Clear all'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No notifications',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(notification: notification);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
            'Are you sure you want to delete all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final user = ref.read(currentUserProvider);
              if (user != null) {
                ref
                    .read(firestoreServiceProvider)
                    .clearAllNotifications(user.uid);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat.jm();
    final dateFormat = DateFormat.MMMd();

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        final user = ref.read(currentUserProvider);
        if (user != null) {
          ref
              .read(firestoreServiceProvider)
              .deleteNotification(user.uid, notification.id);
        }
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.read
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primaryContainer,
          child: Icon(
            _iconForType(notification.type),
            color: notification.read
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: notification.read
              ? null
              : const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              _formatTime(notification.createdAt, dateFormat, timeFormat),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          // Mark as read
          final user = ref.read(currentUserProvider);
          if (user != null && !notification.read) {
            ref
                .read(firestoreServiceProvider)
                .markNotificationRead(user.uid, notification.id);
          }
          // Navigate to task if applicable
          if (notification.taskId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    TaskDetailScreen(taskId: notification.taskId!),
              ),
            );
          }
        },
      ),
    );
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.reminder:
        return Icons.alarm;
      case NotificationType.sharedList:
        return Icons.people;
      case NotificationType.comment:
        return Icons.comment;
      case NotificationType.assignment:
        return Icons.assignment_ind;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  String _formatTime(
      DateTime dt, DateFormat dateFormat, DateFormat timeFormat) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notifDay = DateTime(dt.year, dt.month, dt.day);

    if (notifDay == today) {
      return 'Today ${timeFormat.format(dt)}';
    } else if (notifDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${timeFormat.format(dt)}';
    }
    return '${dateFormat.format(dt)} ${timeFormat.format(dt)}';
  }
}
