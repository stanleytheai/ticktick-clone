import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/calendar_provider.dart';
import 'package:ticktick_clone/providers/list_provider.dart';
import 'package:ticktick_clone/screens/tasks/task_detail_screen.dart';

class DayView extends ConsumerWidget {
  final DateTime date;

  const DayView({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksForSelectedDateProvider);
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMEd();
    final lists = ref.watch(listsStreamProvider).value ?? [];

    // Group tasks into all-day (no specific time) bucket
    // Since our Task model only has dueDate (no time component typically),
    // we show all tasks as day events and provide an hourly grid for context

    return Column(
      children: [
        // Day header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Navigate previous day
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  final prev = date.subtract(const Duration(days: 1));
                  ref.read(selectedDateProvider.notifier).state = prev;
                  ref.read(focusedDateProvider.notifier).state = prev;
                },
              ),
              Expanded(
                child: Text(
                  dateFormat.format(date),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Navigate next day
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  final next = date.add(const Duration(days: 1));
                  ref.read(selectedDateProvider.notifier).state = next;
                  ref.read(focusedDateProvider.notifier).state = next;
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // All-day tasks section
        if (tasks.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: theme.colorScheme.surfaceContainerLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${tasks.length} task${tasks.length == 1 ? '' : 's'}',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                ...tasks.map((task) {
                  final list =
                      lists.where((l) => l.id == task.listId).firstOrNull;
                  return _DayTaskChip(task: task, list: list);
                }),
              ],
            ),
          ),
        // Hourly grid
        Expanded(
          child: _HourlyGrid(date: date, tasks: tasks),
        ),
      ],
    );
  }
}

class _DayTaskChip extends ConsumerWidget {
  final Task task;
  final dynamic list;

  const _DayTaskChip({required this.task, this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    final priorityColor =
        task.priority.value > 0 ? Color(task.priority.colorValue) : null;
    final listColor = list != null ? Color(list.colorValue) : null;
    final accentColor =
        priorityColor ?? listColor ?? theme.colorScheme.primary;

    return LongPressDraggable<Task>(
      data: task,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(task.title, overflow: TextOverflow.ellipsis),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 2),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: task.isCompleted,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) {
                      if (user == null) return;
                      ref.read(firestoreServiceProvider).updateTask(
                            user.uid,
                            task.copyWith(
                              isCompleted: v ?? false,
                              updatedAt: DateTime.now(),
                            ),
                          );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(task.title,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (task.priority.value > 0)
                  Icon(Icons.flag,
                      color: Color(task.priority.colorValue), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HourlyGrid extends ConsumerWidget {
  final DateTime date;
  final List<Task> tasks;

  const _HourlyGrid({required this.date, required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final timeFormat = DateFormat.j();
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    return ListView.builder(
      itemCount: 24,
      itemBuilder: (context, hour) {
        final hourTime = DateTime(date.year, date.month, date.day, hour);
        final isCurrentHour = isToday && now.hour == hour;

        return DragTarget<Task>(
          onAcceptWithDetails: (details) {
            if (user == null) return;
            // Schedule task to this date (hour info for future use)
            ref.read(firestoreServiceProvider).updateTask(
                  user.uid,
                  details.data.copyWith(
                    dueDate: date,
                    updatedAt: DateTime.now(),
                  ),
                );
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            return InkWell(
              onTap: () => _createTaskAtHour(context, ref, hour),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: isHovering
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : isCurrentHour
                          ? theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.15)
                          : null,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Hour label
                    SizedBox(
                      width: 56,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 8),
                        child: Text(
                          timeFormat.format(hourTime),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isCurrentHour
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isCurrentHour
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    // Vertical divider
                    Container(
                      width: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    // Content area
                    Expanded(
                      child: isCurrentHour
                          ? Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: (now.minute / 60) * 60,
                                  child: Container(
                                    height: 2,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _createTaskAtHour(BuildContext context, WidgetRef ref, int hour) {
    final controller = TextEditingController();
    final timeStr = DateFormat.j().format(
      DateTime(date.year, date.month, date.day, hour),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'New task - ${DateFormat.MMMd().format(date)} $timeStr'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Task title',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            _submitTask(controller.text, ref);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _submitTask(controller.text, ref);
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _submitTask(String title, WidgetRef ref) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final now = DateTime.now();
    final task = Task(
      id: const Uuid().v4(),
      title: trimmed,
      listId: 'inbox',
      dueDate: date,
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
      userId: user.uid,
    );

    ref.read(firestoreServiceProvider).addTask(user.uid, task);
  }
}
