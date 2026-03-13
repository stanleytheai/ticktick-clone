import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/calendar_provider.dart';
import 'package:ticktick_clone/providers/list_provider.dart';
import 'package:ticktick_clone/screens/tasks/task_detail_screen.dart';

class UnscheduledPanel extends ConsumerWidget {
  const UnscheduledPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unscheduled = ref.watch(unscheduledTasksProvider);
    final theme = Theme.of(context);
    final lists = ref.watch(listsStreamProvider).value ?? [];
    final user = ref.watch(currentUserProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      'Unscheduled (${unscheduled.length})',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      'Long-press to drag onto calendar',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Task list
              Expanded(
                child: unscheduled.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 48, color: theme.colorScheme.outline),
                            const SizedBox(height: 8),
                            Text('All tasks are scheduled',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: unscheduled.length,
                        itemBuilder: (context, index) {
                          final task = unscheduled[index];
                          final list = lists
                              .where((l) => l.id == task.listId)
                              .firstOrNull;
                          return _UnscheduledTaskTile(
                            task: task,
                            list: list,
                            onSchedule: () {
                              if (user == null) return;
                              ref
                                  .read(firestoreServiceProvider)
                                  .updateTask(
                                    user.uid,
                                    task.copyWith(
                                      dueDate: selectedDate,
                                      updatedAt: DateTime.now(),
                                    ),
                                  );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UnscheduledTaskTile extends StatelessWidget {
  final Task task;
  final dynamic list;
  final VoidCallback onSchedule;

  const _UnscheduledTaskTile({
    required this.task,
    this.list,
    required this.onSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityColor =
        task.priority.value > 0 ? Color(task.priority.colorValue) : null;
    final listColor = list != null ? Color(list.colorValue) : null;
    final accentColor =
        priorityColor ?? listColor ?? theme.colorScheme.primary;

    return LongPressDraggable<Task>(
      data: task,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: accentColor, width: 3),
            ),
          ),
          child: Text(task.title,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildContent(context, theme, accentColor),
      ),
      child: _buildContent(context, theme, accentColor),
    );
  }

  Widget _buildContent(
      BuildContext context, ThemeData theme, Color accentColor) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(taskId: task.id),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: accentColor, width: 3),
            ),
          ),
          child: ListTile(
            dense: true,
            title: Text(
              task.title,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: list != null
                ? Text(list.name,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task.priority.value > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.flag,
                        color: Color(task.priority.colorValue), size: 16),
                  ),
                IconButton(
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  tooltip: 'Schedule to selected date',
                  onPressed: onSchedule,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
