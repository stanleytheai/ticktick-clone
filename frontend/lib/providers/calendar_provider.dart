import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/task_provider.dart';

enum CalendarViewMode { month, twoWeek, week, day }

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final focusedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final calendarViewModeProvider =
    StateProvider<CalendarViewMode>((ref) => CalendarViewMode.month);

final calendarFormatProvider = Provider<CalendarFormat>((ref) {
  final mode = ref.watch(calendarViewModeProvider);
  switch (mode) {
    case CalendarViewMode.month:
      return CalendarFormat.month;
    case CalendarViewMode.twoWeek:
      return CalendarFormat.twoWeeks;
    case CalendarViewMode.week:
    case CalendarViewMode.day:
      return CalendarFormat.week;
  }
});

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

final tasksByDateProvider =
    Provider<Map<DateTime, List<Task>>>((ref) {
  final tasks = ref.watch(tasksStreamProvider).value ?? [];
  final map = <DateTime, List<Task>>{};
  for (final task in tasks) {
    if (task.dueDate == null || task.isCompleted) continue;
    final key = _dateOnly(task.dueDate!);
    map.putIfAbsent(key, () => []).add(task);
  }
  return map;
});

final tasksForSelectedDateProvider = Provider<List<Task>>((ref) {
  final selected = ref.watch(selectedDateProvider);
  final map = ref.watch(tasksByDateProvider);
  final key = _dateOnly(selected);
  return map[key] ?? [];
});

final unscheduledTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksStreamProvider).value ?? [];
  return tasks.where((t) => t.dueDate == null && !t.isCompleted).toList();
});
