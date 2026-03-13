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

    final incomplete = tasks.where((t) => !t.isCompleted).toList();
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
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.task_alt,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No tasks',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: incomplete.length,
              itemBuilder: (context, index) {
                final task = incomplete[index];
                return _SwipeableTaskTile(task: task, user: user);
              },
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

class _SwipeableTaskTile extends ConsumerWidget {
  final Task task;
  final dynamic user;

  const _SwipeableTaskTile({required this.task, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.MMMd();

    return Dismissible(
      key: Key(task.id),
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
        trailing: task.priority.value > 0
            ? Icon(Icons.flag, color: Color(task.priority.colorValue), size: 20)
            : null,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TaskDetailScreen(taskId: task.id)),
        ),
      ),
    );
  }
}
