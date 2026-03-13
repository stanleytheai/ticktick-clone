import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/models/task_list.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/list_provider.dart';
import 'package:ticktick_clone/providers/task_provider.dart';
import 'package:ticktick_clone/screens/tasks/task_detail_screen.dart';

class KanbanScreen extends ConsumerWidget {
  const KanbanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(listsStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Kanban',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: listsAsync.when(
        data: (lists) {
          if (lists.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.view_kanban_outlined,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('Create lists to use the Kanban board',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }
          return _KanbanBoard(lists: lists);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _KanbanBoard extends ConsumerWidget {
  final List<TaskList> lists;

  const _KanbanBoard({required this.lists});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      itemCount: lists.length,
      itemBuilder: (context, index) {
        return _KanbanColumn(list: lists[index]);
      },
    );
  }
}

class _KanbanColumn extends ConsumerWidget {
  final TaskList list;

  const _KanbanColumn({required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tasks = ref.watch(tasksByListProvider(list.id))
        .where((t) => !t.isCompleted)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final user = ref.watch(currentUserProvider);
    final listColor = Color(list.colorValue);

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: listColor.withAlpha(30),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: listColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(list.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600, color: listColor)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: listColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${tasks.length}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: listColor)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: DragTarget<Task>(
                onAcceptWithDetails: (details) {
                  if (user == null) return;
                  final task = details.data;
                  if (task.listId == list.id) return;
                  final maxSort = tasks.isEmpty
                      ? 0
                      : tasks.last.sortOrder + 1;
                  final updated = task.copyWith(
                    listId: list.id,
                    sortOrder: maxSort,
                    updatedAt: DateTime.now(),
                  );
                  ref
                      .read(firestoreServiceProvider)
                      .updateTask(user.uid, updated);
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovering = candidateData.isNotEmpty;

                  if (tasks.isEmpty) {
                    return Container(
                      color: isHovering
                          ? listColor.withAlpha(15)
                          : null,
                      child: Center(
                        child: Text(
                          isHovering ? 'Drop here' : 'No tasks',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isHovering
                                ? listColor
                                : theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    );
                  }

                  return Container(
                    color: isHovering
                        ? listColor.withAlpha(15)
                        : null,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        return _KanbanCard(
                          task: tasks[index],
                          listColor: listColor,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KanbanCard extends ConsumerWidget {
  final Task task;
  final Color listColor;

  const _KanbanCard({required this.task, required this.listColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return LongPressDraggable<Task>(
      data: task,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: listColor, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if (task.dueDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 12, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                        '${task.dueDate!.month}/${task.dueDate!.day}',
                        style: theme.textTheme.labelSmall),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCard(context, ref, theme, user),
      ),
      child: _buildCard(context, ref, theme, user),
    );
  }

  Widget _buildCard(
      BuildContext context, WidgetRef ref, ThemeData theme, dynamic user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TaskDetailScreen(taskId: task.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: task.isCompleted,
                      onChanged: (v) {
                        if (user == null) return;
                        ref.read(firestoreServiceProvider).updateTask(
                              user.uid,
                              task.copyWith(
                                  isCompleted: v ?? false,
                                  updatedAt: DateTime.now()),
                            );
                      },
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(task.title,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              if (task.dueDate != null ||
                  task.priority.value > 0 ||
                  task.subtasks.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (task.dueDate != null) ...[
                      Icon(Icons.calendar_today,
                          size: 12,
                          color: task.dueDate!.isBefore(DateTime.now())
                              ? theme.colorScheme.error
                              : theme.colorScheme.outline),
                      const SizedBox(width: 3),
                      Text(
                          '${task.dueDate!.month}/${task.dueDate!.day}',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: task.dueDate!.isBefore(DateTime.now())
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.outline)),
                      const SizedBox(width: 8),
                    ],
                    if (task.subtasks.isNotEmpty) ...[
                      Icon(Icons.checklist,
                          size: 12, color: theme.colorScheme.outline),
                      const SizedBox(width: 3),
                      Text(
                          '${task.subtasks.where((s) => s.isCompleted).length}/${task.subtasks.length}',
                          style: theme.textTheme.labelSmall),
                      const SizedBox(width: 8),
                    ],
                    if (task.priority.value > 0)
                      Icon(Icons.flag,
                          size: 14,
                          color: Color(task.priority.colorValue)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
