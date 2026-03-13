import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/models/task_list.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/list_provider.dart';

class QuickAddDialog extends ConsumerStatefulWidget {
  const QuickAddDialog({super.key});

  @override
  ConsumerState<QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends ConsumerState<QuickAddDialog> {
  final _titleController = TextEditingController();
  TaskPriority _priority = TaskPriority.none;
  DateTime? _dueDate;
  String _selectedListId = 'inbox';

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lists = ref.watch(listsStreamProvider).value ?? <TaskList>[];

    return AlertDialog(
      title: const Text('Quick Add Task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Task title',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _addTask(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // List selector
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: lists.any((l) => l.id == _selectedListId)
                      ? _selectedListId
                      : (lists.isNotEmpty ? lists.first.id : null),
                  decoration: const InputDecoration(
                    labelText: 'List',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: lists
                      .map((l) => DropdownMenuItem(
                            value: l.id,
                            child: Text(l.name,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedListId = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Date picker
              ActionChip(
                avatar: Icon(Icons.calendar_today,
                    size: 16,
                    color: _dueDate != null
                        ? theme.colorScheme.primary
                        : null),
                label: Text(_dueDate != null
                    ? '${_dueDate!.month}/${_dueDate!.day}'
                    : 'Date'),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) setState(() => _dueDate = date);
                },
              ),
              const SizedBox(width: 8),
              // Priority selector
              PopupMenuButton<TaskPriority>(
                child: Chip(
                  avatar: Icon(Icons.flag,
                      size: 16,
                      color: _priority.value > 0
                          ? Color(_priority.colorValue)
                          : null),
                  label: Text(_priority.label),
                ),
                itemBuilder: (_) => TaskPriority.values
                    .map((p) => PopupMenuItem(
                          value: p,
                          child: Row(
                            children: [
                              Icon(Icons.flag,
                                  color: p.value > 0
                                      ? Color(p.colorValue)
                                      : null,
                                  size: 18),
                              const SizedBox(width: 8),
                              Text(p.label),
                            ],
                          ),
                        ))
                    .toList(),
                onSelected: (p) => setState(() => _priority = p),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _addTask,
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _addTask() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final now = DateTime.now();
    final task = Task(
      id: const Uuid().v4(),
      title: title,
      listId: _selectedListId,
      dueDate: _dueDate,
      priority: _priority,
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
      userId: user.uid,
    );

    ref.read(firestoreServiceProvider).addTask(user.uid, task);
    Navigator.pop(context);
  }
}
