import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/eisenhower_provider.dart';
import 'package:ticktick_clone/providers/list_provider.dart';
import 'package:ticktick_clone/screens/tasks/task_detail_screen.dart';

class EisenhowerScreen extends ConsumerWidget {
  const EisenhowerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(eisenhowerFilterProvider);
    final lists = ref.watch(listsStreamProvider).value ?? [];
    final allTags = ref.watch(allTagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Eisenhower Matrix',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: Badge(
              isLabelVisible: filter.listId != null ||
                  filter.tag != null ||
                  filter.dateFrom != null,
              child: const Icon(Icons.filter_list),
            ),
            onSelected: (value) {
              if (value == 'clear') {
                ref.read(eisenhowerFilterProvider.notifier).state =
                    const EisenhowerFilter();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text('Filter by List',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.primary)),
              ),
              ...lists.map((list) => PopupMenuItem(
                    value: 'list:${list.id}',
                    onTap: () {
                      final current = ref.read(eisenhowerFilterProvider);
                      ref.read(eisenhowerFilterProvider.notifier).state =
                          current.listId == list.id
                              ? current.copyWith(clearListId: true)
                              : current.copyWith(listId: list.id);
                    },
                    child: Row(
                      children: [
                        Icon(Icons.circle,
                            size: 12, color: Color(list.colorValue)),
                        const SizedBox(width: 8),
                        Text(list.name),
                        if (filter.listId == list.id) ...[
                          const Spacer(),
                          const Icon(Icons.check, size: 18),
                        ],
                      ],
                    ),
                  )),
              if (allTags.isNotEmpty) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  enabled: false,
                  child: Text('Filter by Tag',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                ),
                ...allTags.map((tag) => PopupMenuItem(
                      value: 'tag:$tag',
                      onTap: () {
                        final current = ref.read(eisenhowerFilterProvider);
                        ref.read(eisenhowerFilterProvider.notifier).state =
                            current.tag == tag
                                ? current.copyWith(clearTag: true)
                                : current.copyWith(tag: tag);
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.label_outline, size: 16),
                          const SizedBox(width: 8),
                          Text(tag),
                          if (filter.tag == tag) ...[
                            const Spacer(),
                            const Icon(Icons.check, size: 18),
                          ],
                        ],
                      ),
                    )),
              ],
              if (filter.listId != null ||
                  filter.tag != null ||
                  filter.dateFrom != null) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, size: 18),
                      SizedBox(width: 8),
                      Text('Clear Filters'),
                    ],
                  ),
                ),
              ],
            ],
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Date range filter',
            onPressed: () => _pickDateRange(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          if (filter.listId != null ||
              filter.tag != null ||
              filter.dateFrom != null)
            _ActiveFiltersBar(filter: filter, lists: lists),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  // Urgency labels
                  Row(
                    children: [
                      const SizedBox(width: 80),
                      Expanded(
                        child: Center(
                          child: Text('URGENT',
                              style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.error)),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text('NOT URGENT',
                              style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.outline)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Top row: Important
                  Expanded(
                    child: Row(
                      children: [
                        _ImportanceLabel(
                          label: 'IMPORTANT',
                          color: theme.colorScheme.primary,
                        ),
                        Expanded(
                          child: _QuadrantCard(
                            quadrant: EisenhowerQuadrant.urgentImportant,
                            title: 'Do First',
                            color: const Color(0xFFF44336),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _QuadrantCard(
                            quadrant: EisenhowerQuadrant.notUrgentImportant,
                            title: 'Schedule',
                            color: const Color(0xFF2196F3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Bottom row: Not Important
                  Expanded(
                    child: Row(
                      children: [
                        _ImportanceLabel(
                          label: 'NOT\nIMPORTANT',
                          color: theme.colorScheme.outline,
                        ),
                        Expanded(
                          child: _QuadrantCard(
                            quadrant: EisenhowerQuadrant.urgentNotImportant,
                            title: 'Delegate',
                            color: const Color(0xFFFF9800),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _QuadrantCard(
                            quadrant: EisenhowerQuadrant.notUrgentNotImportant,
                            title: 'Eliminate',
                            color: const Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context, WidgetRef ref) async {
    final filter = ref.read(eisenhowerFilterProvider);
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: filter.dateFrom != null && filter.dateTo != null
          ? DateTimeRange(start: filter.dateFrom!, end: filter.dateTo!)
          : null,
    );
    if (result != null) {
      ref.read(eisenhowerFilterProvider.notifier).state = filter.copyWith(
        dateFrom: result.start,
        dateTo: result.end,
      );
    }
  }
}

class _ImportanceLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _ImportanceLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: RotatedBox(
        quarterTurns: 3,
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ),
      ),
    );
  }
}

class _ActiveFiltersBar extends ConsumerWidget {
  final EisenhowerFilter filter;
  final List<dynamic> lists;

  const _ActiveFiltersBar({required this.filter, required this.lists});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 8,
        children: [
          if (filter.listId != null)
            Chip(
              label: Text(_listName(filter.listId!)),
              onDeleted: () => ref
                  .read(eisenhowerFilterProvider.notifier)
                  .state = filter.copyWith(clearListId: true),
              visualDensity: VisualDensity.compact,
            ),
          if (filter.tag != null)
            Chip(
              label: Text('#${filter.tag}'),
              onDeleted: () => ref
                  .read(eisenhowerFilterProvider.notifier)
                  .state = filter.copyWith(clearTag: true),
              visualDensity: VisualDensity.compact,
            ),
          if (filter.dateFrom != null)
            Chip(
              label: Text(
                  '${_formatDate(filter.dateFrom!)} – ${_formatDate(filter.dateTo!)}'),
              onDeleted: () => ref
                  .read(eisenhowerFilterProvider.notifier)
                  .state = filter.copyWith(
                      clearDateFrom: true, clearDateTo: true),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  String _listName(String listId) {
    try {
      final list = lists.firstWhere((l) => l.id == listId);
      return list.name;
    } catch (_) {
      return listId;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}

class _QuadrantCard extends ConsumerWidget {
  final EisenhowerQuadrant quadrant;
  final String title;
  final Color color;

  const _QuadrantCard({
    required this.quadrant,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(eisenhowerTasksProvider(quadrant));
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return DragTarget<Task>(
      onAcceptWithDetails: (details) {
        if (user == null) return;
        final task = details.data;
        final currentQuadrant = classifyTask(task);
        if (currentQuadrant == quadrant) return;

        final updated = _applyQuadrantChange(task, quadrant);
        ref
            .read(firestoreServiceProvider)
            .updateTask(user.uid, updated);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isHovering
                ? BorderSide(color: color, width: 2)
                : BorderSide.none,
          ),
          color: isHovering
              ? color.withValues(alpha: 0.08)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: color.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(title,
                        style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600, color: color)),
                    const Spacer(),
                    Text('${tasks.length}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: color)),
                  ],
                ),
              ),
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text('No tasks',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          return _DraggableTaskItem(
                            task: tasks[index],
                            quadrantColor: color,
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

  Task _applyQuadrantChange(Task task, EisenhowerQuadrant target) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    TaskPriority newPriority = task.priority;
    DateTime? newDueDate = task.dueDate;
    bool clearDueDate = false;

    // Adjust importance (priority)
    switch (target) {
      case EisenhowerQuadrant.urgentImportant:
      case EisenhowerQuadrant.notUrgentImportant:
        if (!_isImportant(task.priority)) {
          newPriority = TaskPriority.high;
        }
      case EisenhowerQuadrant.urgentNotImportant:
      case EisenhowerQuadrant.notUrgentNotImportant:
        if (_isImportant(task.priority)) {
          newPriority = TaskPriority.low;
        }
    }

    // Adjust urgency (due date)
    switch (target) {
      case EisenhowerQuadrant.urgentImportant:
      case EisenhowerQuadrant.urgentNotImportant:
        if (task.dueDate == null ||
            task.dueDate!.isAfter(today.add(const Duration(days: 2)))) {
          newDueDate = today;
        }
      case EisenhowerQuadrant.notUrgentImportant:
      case EisenhowerQuadrant.notUrgentNotImportant:
        if (task.dueDate != null &&
            task.dueDate!.isBefore(today.add(const Duration(days: 2)))) {
          newDueDate = today.add(const Duration(days: 7));
        }
    }

    return task.copyWith(
      priority: newPriority,
      dueDate: newDueDate,
      clearDueDate: clearDueDate,
      updatedAt: DateTime.now(),
    );
  }

  bool _isImportant(TaskPriority priority) {
    return priority == TaskPriority.high || priority == TaskPriority.medium;
  }
}

class _DraggableTaskItem extends ConsumerWidget {
  final Task task;
  final Color quadrantColor;

  const _DraggableTaskItem({
    required this.task,
    required this.quadrantColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return LongPressDraggable<Task>(
      data: task,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: quadrantColor, width: 1.5),
          ),
          child: Text(task.title,
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTile(context, ref, theme, user),
      ),
      child: _buildTile(context, ref, theme, user),
    );
  }

  Widget _buildTile(
      BuildContext context, WidgetRef ref, ThemeData theme, dynamic user) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TaskDetailScreen(taskId: task.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
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
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                task.title,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (task.dueDate != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '${task.dueDate!.month}/${task.dueDate!.day}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: task.dueDate!.isBefore(DateTime.now())
                        ? theme.colorScheme.error
                        : theme.colorScheme.outline,
                  ),
                ),
              ),
            if (task.priority.value > 0)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.flag,
                    size: 14, color: Color(task.priority.colorValue)),
              ),
          ],
        ),
      ),
    );
  }
}
