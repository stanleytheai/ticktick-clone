import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/calendar_provider.dart';
import 'package:ticktick_clone/providers/list_provider.dart';
import 'package:ticktick_clone/screens/calendar/day_view.dart';
import 'package:ticktick_clone/screens/calendar/unscheduled_panel.dart';
import 'package:ticktick_clone/screens/tasks/task_detail_screen.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(calendarViewModeProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final focusedDate = ref.watch(focusedDateProvider);
    final calendarFormat = ref.watch(calendarFormatProvider);
    final tasksByDate = ref.watch(tasksByDateProvider);
    final tasksForDay = ref.watch(tasksForSelectedDateProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Today',
            onPressed: () {
              final today = DateTime.now();
              final d = DateTime(today.year, today.month, today.day);
              ref.read(selectedDateProvider.notifier).state = d;
              ref.read(focusedDateProvider.notifier).state = d;
            },
          ),
          PopupMenuButton<CalendarViewMode>(
            icon: const Icon(Icons.view_agenda_outlined),
            tooltip: 'View mode',
            initialValue: viewMode,
            onSelected: (mode) =>
                ref.read(calendarViewModeProvider.notifier).state = mode,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: CalendarViewMode.month,
                child: Text('Month'),
              ),
              PopupMenuItem(
                value: CalendarViewMode.twoWeek,
                child: Text('2 Weeks'),
              ),
              PopupMenuItem(
                value: CalendarViewMode.week,
                child: Text('Week'),
              ),
              PopupMenuItem(
                value: CalendarViewMode.day,
                child: Text('Day'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar widget
          _CalendarWidget(
            focusedDate: focusedDate,
            selectedDate: selectedDate,
            calendarFormat: calendarFormat,
            tasksByDate: tasksByDate,
          ),
          const Divider(height: 1),
          // Content area
          Expanded(
            child: viewMode == CalendarViewMode.day
                ? DayView(date: selectedDate)
                : _TaskListForDate(
                    tasks: tasksForDay,
                    selectedDate: selectedDate,
                  ),
          ),
        ],
      ),
    );
  }
}

class _CalendarWidget extends ConsumerWidget {
  final DateTime focusedDate;
  final DateTime selectedDate;
  final CalendarFormat calendarFormat;
  final Map<DateTime, List<Task>> tasksByDate;

  const _CalendarWidget({
    required this.focusedDate,
    required this.selectedDate,
    required this.calendarFormat,
    required this.tasksByDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lists = ref.watch(listsStreamProvider).value ?? [];

    return DragTarget<Task>(
      onAcceptWithDetails: (details) {
        // Handled per-day in the calendar builder
      },
      builder: (context, candidateData, rejectedData) {
        return TableCalendar<Task>(
          firstDay: DateTime(2020),
          lastDay: DateTime(2100),
          focusedDay: focusedDate,
          selectedDayPredicate: (day) => isSameDay(day, selectedDate),
          calendarFormat: calendarFormat,
          startingDayOfWeek: StartingDayOfWeek.monday,
          eventLoader: (day) {
            final key = DateTime(day.year, day.month, day.day);
            return tasksByDate[key] ?? [];
          },
          onDaySelected: (selected, focused) {
            final d = DateTime(selected.year, selected.month, selected.day);
            ref.read(selectedDateProvider.notifier).state = d;
            ref.read(focusedDateProvider.notifier).state =
                DateTime(focused.year, focused.month, focused.day);
          },
          onPageChanged: (focused) {
            ref.read(focusedDateProvider.notifier).state =
                DateTime(focused.year, focused.month, focused.day);
          },
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
            selectedDecoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
            outsideDaysVisible: true,
            markersMaxCount: 3,
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return null;
              return Positioned(
                bottom: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: events.take(3).map((task) {
                    final list = lists
                        .where((l) => l.id == task.listId)
                        .firstOrNull;
                    final color = task.priority.value > 0
                        ? Color(task.priority.colorValue)
                        : (list != null
                            ? Color(list.colorValue)
                            : theme.colorScheme.primary);
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: theme.textTheme.titleMedium!
                .copyWith(fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}

class _TaskListForDate extends ConsumerWidget {
  final List<Task> tasks;
  final DateTime selectedDate;

  const _TaskListForDate({
    required this.tasks,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMEd();
    final lists = ref.watch(listsStreamProvider).value ?? [];
    final user = ref.watch(currentUserProvider);

    return Column(
      children: [
        // Date header with add button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dateFormat.format(selectedDate),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                tooltip: 'Add task on this date',
                onPressed: () => _createTaskOnDate(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.view_sidebar_outlined, size: 20),
                tooltip: 'Unscheduled tasks',
                onPressed: () => _showUnscheduledPanel(context),
              ),
            ],
          ),
        ),
        // Task list - accepts drag from unscheduled panel
        Expanded(
          child: DragTarget<Task>(
            onAcceptWithDetails: (details) {
              if (user == null) return;
              final task = details.data;
              ref.read(firestoreServiceProvider).updateTask(
                    user.uid,
                    task.copyWith(
                      dueDate: selectedDate,
                      updatedAt: DateTime.now(),
                    ),
                  );
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              return Container(
                decoration: isHovering
                    ? BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.2),
                      )
                    : null,
                child: tasks.isEmpty && !isHovering
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_available,
                                size: 48,
                                color: theme.colorScheme.outline),
                            const SizedBox(height: 8),
                            Text('No tasks',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Text(
                              'Tap + to add or drag tasks here',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _CalendarTaskTile(task: task, lists: lists);
                        },
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _createTaskOnDate(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'New task - ${DateFormat.MMMd().format(selectedDate)}'),
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
      dueDate: selectedDate,
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
      userId: user.uid,
    );

    ref.read(firestoreServiceProvider).addTask(user.uid, task);
  }

  void _showUnscheduledPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const UnscheduledPanel(),
    );
  }
}

class _CalendarTaskTile extends ConsumerWidget {
  final Task task;
  final List lists;

  const _CalendarTaskTile({required this.task, required this.lists});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final list = lists.where((l) => l.id == task.listId).firstOrNull;

    final priorityColor = task.priority.value > 0
        ? Color(task.priority.colorValue)
        : null;
    final listColor = list != null ? Color(list.colorValue) : null;
    final accentColor =
        priorityColor ?? listColor ?? theme.colorScheme.primary;

    // LongPressDraggable for drag-and-drop rescheduling
    return LongPressDraggable<Task>(
      data: task,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: accentColor, width: 3),
            ),
          ),
          child: Text(task.title,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTile(context, ref, theme, accentColor),
      ),
      child: _buildTile(context, ref, theme, accentColor),
    );
  }

  Widget _buildTile(
      BuildContext context, WidgetRef ref, ThemeData theme, Color accentColor) {
    final user = ref.watch(currentUserProvider);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
          child: ListTile(
            dense: true,
            leading: SizedBox(
              width: 24,
              child: Checkbox(
                value: task.isCompleted,
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
            title: Text(
              task.title,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: task.subtasks.isNotEmpty
                ? Text(
                    '${task.subtasks.where((s) => s.isCompleted).length}/${task.subtasks.length} subtasks',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  )
                : null,
            trailing: task.priority.value > 0
                ? Icon(Icons.flag,
                    color: Color(task.priority.colorValue), size: 18)
                : null,
          ),
        ),
      ),
    );
  }
}
