import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/list_provider.dart';
import 'package:ticktick_clone/providers/task_provider.dart';
import 'package:ticktick_clone/screens/tasks/task_detail_screen.dart';

class TaskListScreen extends ConsumerWidget {
  final String listId;
  final String title;

  const TaskListScreen({super.key, required this.listId, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksByListProvider(listId));
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final list = ref.watch(listByIdProvider(listId));

    final incomplete = tasks.where((t) => !t.isCompleted).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final completed = tasks.where((t) => t.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(list?.name ?? title,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          if (completed.isNotEmpty)
            Badge(
              label: Text('${completed.length}'),
              child: IconButton(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: () => _showCompleted(context, completed),
              ),
            ),
        ],
      ),
      body: incomplete.isEmpty
          ? _DropTargetEmpty(listId: listId)
          : _ReorderableTaskList(
              listId: listId,
              tasks: incomplete,
              user: user,
            ),
    );
  }

  void _showCompleted(BuildContext context, List<Task> completed) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Completed (${completed.length})',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          ...completed.map((t) => ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(t.title,
                    style: const TextStyle(
                        decoration: TextDecoration.lineThrough)),
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DropTargetEmpty extends ConsumerWidget {
  final String listId;

  const _DropTargetEmpty({required this.listId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return DragTarget<Task>(
      onAcceptWithDetails: (details) {
        if (user == null) return;
        final task = details.data;
        if (task.listId == listId) return;
        final updated = task.copyWith(
          listId: listId,
          sortOrder: 0,
          updatedAt: DateTime.now(),
        );
        ref.read(firestoreServiceProvider).updateTask(user.uid, updated);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isHovering ? Icons.add_circle : Icons.task_alt,
                size: 64,
                color: isHovering
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                isHovering ? 'Drop task here' : 'No tasks',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isHovering
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReorderableTaskList extends ConsumerStatefulWidget {
  final String listId;
  final List<Task> tasks;
  final dynamic user;

  const _ReorderableTaskList({
    required this.listId,
    required this.tasks,
    required this.user,
  });

  @override
  ConsumerState<_ReorderableTaskList> createState() =>
      _ReorderableTaskListState();
}

class _ReorderableTaskListState extends ConsumerState<_ReorderableTaskList> {
  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.tasks.length,
      onReorder: _onReorder,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Material(
            elevation: 4 * animation.value,
            borderRadius: BorderRadius.circular(8),
            child: child,
          ),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final task = widget.tasks[index];
        return _DraggableTaskTile(
          key: ValueKey(task.id),
          task: task,
          user: widget.user,
          listId: widget.listId,
        );
      },
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (widget.user == null) return;
    if (oldIndex < newIndex) newIndex -= 1;

    final tasks = List<Task>.from(widget.tasks);
    final item = tasks.removeAt(oldIndex);
    tasks.insert(newIndex, item);

    final updated = <Task>[];
    for (var i = 0; i < tasks.length; i++) {
      if (tasks[i].sortOrder != i) {
        updated.add(tasks[i].copyWith(sortOrder: i, updatedAt: DateTime.now()));
      }
    }
    if (updated.isNotEmpty) {
      ref
          .read(firestoreServiceProvider)
          .batchUpdateTaskSortOrders(widget.user.uid, updated);
    }
  }
}

class _DraggableTaskTile extends ConsumerWidget {
  final Task task;
  final dynamic user;
  final String listId;

  const _DraggableTaskTile({
    super.key,
    required this.task,
    required this.user,
    required this.listId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.MMMd();

    return LongPressDraggable<Task>(
      data: task,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.primary, width: 1.5),
          ),
          child: Text(task.title,
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTile(context, ref, theme, dateFormat),
      ),
      child: _buildTile(context, ref, theme, dateFormat),
    );
  }

  Widget _buildTile(BuildContext context, WidgetRef ref, ThemeData theme,
      DateFormat dateFormat) {
    return Dismissible(
      key: Key('dismiss-${task.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        color: Colors.green,
        child: const Icon(Icons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (user == null) return false;
        if (direction == DismissDirection.startToEnd) {
          await ref.read(firestoreServiceProvider).updateTask(
                user.uid,
                task.copyWith(
                  isCompleted: true,
                  completedAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
        } else {
          await ref
              .read(firestoreServiceProvider)
              .deleteTask(user.uid, task.id);
        }
        return false;
      },
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (v) {
            if (user == null) return;
            final completing = v ?? false;
            ref.read(firestoreServiceProvider).updateTask(
                  user.uid,
                  task.copyWith(
                    isCompleted: completing,
                    completedAt: completing ? DateTime.now() : null,
                    clearCompletedAt: !completing,
                    updatedAt: DateTime.now(),
                  ),
                );
          },
        ),
        title: Text(task.title),
        subtitle: Row(
          children: [
            if (task.dueDate != null) ...[
              Icon(Icons.calendar_today,
                  size: 14, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Text(dateFormat.format(task.dueDate!),
                  style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
            ],
            if (task.subtasks.isNotEmpty) ...[
              Icon(Icons.checklist, size: 14, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Text(
                  '${task.subtasks.where((s) => s.isCompleted).length}/${task.subtasks.length}',
                  style: theme.textTheme.bodySmall),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.priority.value > 0)
              Icon(Icons.flag,
                  color: Color(task.priority.colorValue), size: 20),
            const SizedBox(width: 4),
            Icon(Icons.drag_handle,
                size: 20, color: theme.colorScheme.outline),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TaskDetailScreen(taskId: task.id)),
        ),
      ),
    );
  }
}
