import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/models/subtask.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/task_provider.dart';
import 'package:ticktick_clone/providers/list_provider.dart';
import 'package:ticktick_clone/providers/subscription_provider.dart';
import 'package:ticktick_clone/widgets/reminder_picker.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  final _subtaskController = TextEditingController();
  bool _initialized = false;
  bool _descriptionPreview = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  Task? _findTask(List<Task> tasks) {
    try {
      return tasks.firstWhere((t) => t.id == widget.taskId);
    } catch (_) {
      return null;
    }
  }

  void _initControllers(Task task) {
    if (!_initialized) {
      _titleController = TextEditingController(text: task.title);
      _descriptionController = TextEditingController(text: task.description);
      _initialized = true;
    }
  }

  Future<void> _saveTask(Task task) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(firestoreServiceProvider).updateTask(
          user.uid,
          task.copyWith(updatedAt: DateTime.now()),
        );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksStreamProvider).value ?? [];
    final task = _findTask(tasks);
    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Task not found')),
      );
    }

    _initControllers(task);

    final theme = Theme.of(context);
    final lists = ref.watch(listsStreamProvider).value ?? [];
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outlined),
            onPressed: () async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;
              await ref
                  .read(firestoreServiceProvider)
                  .deleteTask(user.uid, task.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Title
          TextField(
            controller: _titleController,
            style: theme.textTheme.titleLarge,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Task title',
            ),
            onChanged: (v) => _saveTask(task.copyWith(title: v)),
          ),
          const Divider(),

          // List selector
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('List'),
            trailing: DropdownButton<String>(
              value: task.listId,
              underline: const SizedBox(),
              items: lists
                  .map((l) => DropdownMenuItem(
                        value: l.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Color(l.colorValue),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(l.name),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) _saveTask(task.copyWith(listId: v));
              },
            ),
          ),

          // Due date
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Due Date'),
            trailing: Text(
              task.dueDate != null
                  ? dateFormat.format(task.dueDate!)
                  : 'Not set',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: task.dueDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                _saveTask(task.copyWith(dueDate: date));
              }
            },
            onLongPress: () {
              _saveTask(task.copyWith(clearDueDate: true));
            },
          ),

          // Priority
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Priority'),
            trailing: SegmentedButton<TaskPriority>(
              segments: TaskPriority.values
                  .map((p) => ButtonSegment(
                        value: p,
                        label: Text(p.label,
                            style: const TextStyle(fontSize: 11)),
                      ))
                  .toList(),
              selected: {task.priority},
              onSelectionChanged: (s) =>
                  _saveTask(task.copyWith(priority: s.first)),
              showSelectedIcon: false,
            ),
          ),

          // Tags
          ListTile(
            leading: const Icon(Icons.label_outlined),
            title: const Text('Tags'),
            subtitle: task.tags.isEmpty
                ? const Text('No tags')
                : Wrap(
                    spacing: 4,
                    children: task.tags
                        .map((t) => Chip(
                              label: Text(t, style: const TextStyle(fontSize: 12)),
                              onDeleted: () {
                                final tags = List<String>.from(task.tags)
                                  ..remove(t);
                                _saveTask(task.copyWith(tags: tags));
                              },
                            ))
                        .toList(),
                  ),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _addTag(task),
            ),
          ),

          const Divider(),

          // Reminders
          _buildRemindersSection(task, ref),

          const Divider(),

          // Description with markdown support
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Description', style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _descriptionPreview ? Icons.edit : Icons.visibility,
                    size: 20,
                  ),
                  tooltip: _descriptionPreview ? 'Edit' : 'Preview markdown',
                  onPressed: () =>
                      setState(() => _descriptionPreview = !_descriptionPreview),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _descriptionPreview
                ? _descriptionController.text.trim().isEmpty
                    ? Text('No description',
                        style: TextStyle(color: theme.colorScheme.outline))
                    : MarkdownBody(
                        data: _descriptionController.text,
                        selectable: true,
                      )
                : TextField(
                    controller: _descriptionController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Add description... (supports Markdown)',
                    ),
                    onChanged: (v) =>
                        _saveTask(task.copyWith(description: v)),
                  ),
          ),

          const Divider(),

          // Subtasks
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Subtasks', style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          ...task.subtasks.map((sub) => CheckboxListTile(
                value: sub.isCompleted,
                title: Text(sub.title,
                    style: sub.isCompleted
                        ? TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: theme.colorScheme.outline)
                        : null),
                secondary: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    final subs = List<Subtask>.from(task.subtasks)
                      ..removeWhere((s) => s.id == sub.id);
                    _saveTask(task.copyWith(subtasks: subs));
                  },
                ),
                onChanged: (v) {
                  final subs = task.subtasks
                      .map((s) => s.id == sub.id
                          ? s.copyWith(isCompleted: v ?? false)
                          : s)
                      .toList();
                  _saveTask(task.copyWith(subtasks: subs));
                },
              )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subtaskController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Add subtask...',
                    ),
                    onSubmitted: (_) => _addSubtask(task),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addSubtask(task),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersSection(Task task, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);
    final isPremium = subscription.value?.isPremium ?? false;
    final maxReminders = isPremium ? 5 : 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ReminderPicker(
        reminders: task.reminders,
        maxReminders: maxReminders,
        onChanged: (reminders) {
          _saveTask(task.copyWith(reminders: reminders));
        },
      ),
    );
  }

  void _addSubtask(Task task) {
    final text = _subtaskController.text.trim();
    if (text.isEmpty) return;
    final sub = Subtask(
      id: const Uuid().v4(),
      title: text,
      sortOrder: task.subtasks.length,
    );
    final subs = List<Subtask>.from(task.subtasks)..add(sub);
    _saveTask(task.copyWith(subtasks: subs));
    _subtaskController.clear();
  }

  void _addTag(Task task) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tag name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final tag = controller.text.trim();
              if (tag.isNotEmpty) {
                final tags = List<String>.from(task.tags)..add(tag);
                _saveTask(task.copyWith(tags: tags));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
