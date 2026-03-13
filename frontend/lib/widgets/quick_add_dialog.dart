import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/models/task_list.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/list_provider.dart';
import 'package:ticktick_clone/services/nlp_parser.dart';

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
  ParsedTaskInput? _parsed;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _titleController.text.trim();
    if (text.isEmpty) {
      if (_parsed != null) setState(() => _parsed = null);
      return;
    }
    final parsed = parseTaskInput(text);
    // Only update preview if parsing extracted something meaningful
    final hasTokens = parsed.dueDate != null ||
        parsed.priority != TaskPriority.none ||
        parsed.tags.isNotEmpty ||
        parsed.listName != null ||
        parsed.recurrence != null;
    setState(() => _parsed = hasTokens ? parsed : null);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
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
          if (_parsed != null) _buildNlpPreview(theme),
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
    final rawTitle = _titleController.text.trim();
    if (rawTitle.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Parse NLP tokens from the raw input
    final parsed = parseTaskInput(rawTitle);

    // Use parsed values, but manual UI selections take precedence
    final effectiveTitle = parsed.title.isNotEmpty ? parsed.title : rawTitle;
    final effectiveDueDate = _dueDate ?? parsed.dueDate;
    final effectivePriority =
        _priority != TaskPriority.none ? _priority : parsed.priority;

    // Resolve list name to list ID if parsed
    var effectiveListId = _selectedListId;
    if (parsed.listName != null) {
      final lists = ref.read(listsStreamProvider).value ?? <TaskList>[];
      final match = lists
          .where(
              (l) => l.name.toLowerCase() == parsed.listName!.toLowerCase())
          .toList();
      if (match.isNotEmpty) {
        effectiveListId = match.first.id;
      }
    }

    final now = DateTime.now();
    final task = Task(
      id: const Uuid().v4(),
      title: effectiveTitle,
      listId: effectiveListId,
      dueDate: effectiveDueDate,
      priority: effectivePriority,
      tags: parsed.tags,
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
      userId: user.uid,
    );

    ref.read(firestoreServiceProvider).addTask(user.uid, task);
    Navigator.pop(context);
  }

  Widget _buildNlpPreview(ThemeData theme) {
    final p = _parsed!;
    final chips = <Widget>[];

    if (p.dueDate != null) {
      final d = p.dueDate!;
      chips.add(Chip(
        avatar: Icon(Icons.calendar_today,
            size: 14, color: theme.colorScheme.primary),
        label: Text('${d.month}/${d.day}',
            style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
      ));
    }
    if (p.priority != TaskPriority.none) {
      chips.add(Chip(
        avatar: Icon(Icons.flag,
            size: 14, color: Color(p.priority.colorValue)),
        label: Text(p.priority.label,
            style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
      ));
    }
    for (final tag in p.tags) {
      chips.add(Chip(
        label: Text('#$tag', style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
      ));
    }
    if (p.listName != null) {
      chips.add(Chip(
        avatar: const Icon(Icons.list, size: 14),
        label: Text(p.listName!,
            style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
      ));
    }
    if (p.recurrence != null) {
      chips.add(Chip(
        avatar: const Icon(Icons.repeat, size: 14),
        label: Text(p.recurrence!.frequency,
            style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 4, runSpacing: 4, children: chips),
    );
  }
}
