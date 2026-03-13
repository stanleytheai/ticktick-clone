import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ticktick_clone/providers/shared_list_provider.dart';

class ActivityFeedScreen extends ConsumerWidget {
  final String listId;

  const ActivityFeedScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityProvider(listId));
    final theme = Theme.of(context);
    final sharedList = ref.watch(sharedListByIdProvider(listId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Activity - ${sharedList?.name ?? 'List'}'),
      ),
      body: activityAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No activity yet',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final dateFormat = DateFormat.MMMd().add_jm();
              final icon = _iconForType(entry.type);
              final color = _colorForType(entry.type, theme);

              return ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                title: Text(entry.description),
                subtitle: Text(
                  dateFormat.format(entry.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'list_created':
        return Icons.add_circle;
      case 'member_added':
        return Icons.person_add;
      case 'member_removed':
        return Icons.person_remove;
      case 'member_updated':
        return Icons.manage_accounts;
      case 'task_created':
        return Icons.add_task;
      case 'task_completed':
        return Icons.check_circle;
      case 'task_reopened':
        return Icons.refresh;
      case 'task_deleted':
        return Icons.delete;
      case 'task_assigned':
        return Icons.assignment_ind;
      case 'comment_added':
        return Icons.comment;
      default:
        return Icons.info;
    }
  }

  Color _colorForType(String type, ThemeData theme) {
    switch (type) {
      case 'task_completed':
        return Colors.green;
      case 'task_deleted':
      case 'member_removed':
        return Colors.red;
      case 'member_added':
      case 'task_created':
      case 'list_created':
        return Colors.blue;
      case 'comment_added':
        return Colors.orange;
      case 'task_assigned':
        return Colors.purple;
      default:
        return theme.colorScheme.primary;
    }
  }
}
