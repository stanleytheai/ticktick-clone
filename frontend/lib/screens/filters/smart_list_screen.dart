import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/smart_filter.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/filter_provider.dart';
import 'package:ticktick_clone/screens/filters/filter_builder_screen.dart';
import 'package:ticktick_clone/screens/tasks/task_detail_screen.dart';

class SmartListScreen extends ConsumerWidget {
  final SmartFilter filter;

  const SmartListScreen({super.key, required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(filteredTasksProvider(filter));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(filter.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FilterBuilderScreen(existingFilter: filter),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              filter.pinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            onPressed: () async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;
              await ref.read(firestoreServiceProvider).updateFilter(
                    user.uid,
                    filter.copyWith(
                      pinned: !filter.pinned,
                      updatedAt: DateTime.now(),
                    ),
                  );
            },
          ),
        ],
      ),
      body: tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list_off,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No matching tasks',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _FilteredTaskTile(task: task);
              },
            ),
    );
  }
}

class BuiltInSmartListScreen extends ConsumerWidget {
  final BuiltInSmartList smartList;

  const BuiltInSmartListScreen({super.key, required this.smartList});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(builtInSmartListTasksProvider(smartList));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(smartList.label),
      ),
      body: tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconForSmartList(smartList),
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
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _FilteredTaskTile(task: task);
              },
            ),
    );
  }

  IconData _iconForSmartList(BuiltInSmartList list) {
    switch (list) {
      case BuiltInSmartList.today:
        return Icons.today;
      case BuiltInSmartList.tomorrow:
        return Icons.next_plan;
      case BuiltInSmartList.next7Days:
        return Icons.date_range;
      case BuiltInSmartList.all:
        return Icons.all_inclusive;
      case BuiltInSmartList.completed:
        return Icons.task_alt;
      case BuiltInSmartList.trash:
        return Icons.delete;
    }
  }
}

class _FilteredTaskTile extends ConsumerWidget {
  final Task task;

  const _FilteredTaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return ListTile(
      leading: Checkbox(
        value: task.isCompleted,
        onChanged: (v) {
          if (user == null) return;
          ref.read(firestoreServiceProvider).updateTask(
                user.uid,
                task.copyWith(
                    isCompleted: v ?? false, updatedAt: DateTime.now()),
              );
        },
      ),
      title: Text(
        task.title,
        style: task.isCompleted
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.outline)
            : null,
      ),
      subtitle: task.dueDate != null
          ? Text(
              '${task.dueDate!.month}/${task.dueDate!.day}/${task.dueDate!.year}',
              style: theme.textTheme.bodySmall,
            )
          : null,
      trailing: task.priority.value > 0
          ? Icon(Icons.flag,
              color: Color(task.priority.colorValue), size: 20)
          : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TaskDetailScreen(taskId: task.id),
        ),
      ),
    );
  }
}
