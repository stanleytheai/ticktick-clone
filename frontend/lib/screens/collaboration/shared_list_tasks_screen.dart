import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:ticktick_clone/models/shared_list.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/shared_list_provider.dart';
import 'package:ticktick_clone/screens/collaboration/comment_thread_screen.dart';
import 'package:ticktick_clone/screens/collaboration/share_list_screen.dart';
import 'package:ticktick_clone/screens/collaboration/activity_feed_screen.dart';

class SharedListTasksScreen extends ConsumerWidget {
  final String listId;

  const SharedListTasksScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharedList = ref.watch(sharedListByIdProvider(listId));
    final tasksAsync = ref.watch(sharedTasksProvider(listId));
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    if (sharedList == null || user == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('List not found')),
      );
    }

    final canEdit = sharedList.canEdit(user.uid);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(sharedList.name,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Activity',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ActivityFeedScreen(listId: listId),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.group),
            tooltip: 'Members',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShareListScreen(listId: listId),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _showAddTaskDialog(context, ref, sharedList),
              child: const Icon(Icons.add),
            )
          : null,
      body: tasksAsync.when(
        data: (tasks) {
          final incomplete = tasks.where((t) => !t.isCompleted).toList();
          final completed = tasks.where((t) => t.isCompleted).toList();

          if (incomplete.isEmpty && completed.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.task_alt,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No tasks in this shared list',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ...incomplete.map((task) => _SharedTaskTile(
                    task: task,
                    listId: listId,
                    sharedList: sharedList,
                    canEdit: canEdit,
                  )),
              if (completed.isNotEmpty) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Completed (${completed.length})',
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
                ...completed.map((task) => _SharedTaskTile(
                      task: task,
                      listId: listId,
                      sharedList: sharedList,
                      canEdit: canEdit,
                    )),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showAddTaskDialog(
      BuildContext context, WidgetRef ref, SharedList sharedList) {
    final titleController = TextEditingController();
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Task'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Task title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              final task = Task(
                id: const Uuid().v4(),
                title: title,
                listId: listId,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                userId: user.uid,
              );
              ref
                  .read(firestoreServiceProvider)
                  .addSharedTask(listId, task);
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _SharedTaskTile extends ConsumerWidget {
  final Task task;
  final String listId;
  final SharedList sharedList;
  final bool canEdit;

  const _SharedTaskTile({
    required this.task,
    required this.listId,
    required this.sharedList,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.MMMd();
    final assignee = task.assigneeId != null
        ? sharedList.members[task.assigneeId]
        : null;

    return ListTile(
      leading: canEdit
          ? Checkbox(
              value: task.isCompleted,
              onChanged: (v) {
                ref.read(firestoreServiceProvider).updateSharedTask(
                      listId,
                      task.copyWith(
                          isCompleted: v ?? false, updatedAt: DateTime.now()),
                    );
              },
            )
          : Icon(
              task.isCompleted ? Icons.check_circle : Icons.circle_outlined,
              color:
                  task.isCompleted ? Colors.green : theme.colorScheme.outline,
            ),
      title: Text(
        task.title,
        style: task.isCompleted
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.outline)
            : null,
      ),
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
          if (assignee != null) ...[
            Icon(Icons.person, size: 14, color: theme.colorScheme.outline),
            const SizedBox(width: 4),
            Text(
              assignee.displayName.isNotEmpty
                  ? assignee.displayName
                  : assignee.email,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.priority.value > 0)
            Icon(Icons.flag,
                color: Color(task.priority.colorValue), size: 20),
          IconButton(
            icon: const Icon(Icons.comment_outlined, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommentThreadScreen(
                  listId: listId,
                  taskId: task.id,
                  taskTitle: task.title,
                  members: sharedList.members,
                ),
              ),
            ),
          ),
        ],
      ),
      onTap: canEdit
          ? () => _showTaskOptions(context, ref)
          : null,
    );
  }

  void _showTaskOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Assign'),
              onTap: () {
                Navigator.pop(ctx);
                _showAssigneeDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.comment),
              title: const Text('Comments'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommentThreadScreen(
                      listId: listId,
                      taskId: task.id,
                      taskTitle: task.title,
                      members: sharedList.members,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outlined, color: Colors.red),
              title: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                ref
                    .read(firestoreServiceProvider)
                    .deleteSharedTask(listId, task.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAssigneeDialog(BuildContext context, WidgetRef ref) {
    final members = sharedList.members.values.toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign to'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.person_off),
                title: const Text('Unassign'),
                onTap: () {
                  ref
                      .read(firestoreServiceProvider)
                      .assignSharedTask(listId, task.id, null);
                  Navigator.pop(ctx);
                },
              ),
              ...members.map((m) => ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text(
                        (m.displayName.isNotEmpty ? m.displayName : m.email)
                            .substring(0, 1)
                            .toUpperCase(),
                      ),
                    ),
                    title: Text(m.displayName.isNotEmpty
                        ? m.displayName
                        : m.email),
                    trailing: task.assigneeId == m.uid
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () {
                      ref
                          .read(firestoreServiceProvider)
                          .assignSharedTask(listId, task.id, m.uid);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
