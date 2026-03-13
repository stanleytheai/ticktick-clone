import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/focus_session.dart';
import 'package:ticktick_clone/models/habit.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/task_provider.dart';

// Focus sessions stream
final focusSessionsStreamProvider = StreamProvider<List<FocusSession>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchFocusSessions(user.uid);
});

// Habits stream
final habitsStreamProvider = StreamProvider<List<Habit>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchHabits(user.uid);
});

// Habit logs stream per habit
final habitLogsProvider =
    StreamProvider.family<List<HabitLog>, String>((ref, habitId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchHabitLogs(user.uid, habitId);
});

// Task statistics
class TaskStats {
  final int completedToday;
  final int completedThisWeek;
  final int completedThisMonth;
  final int completedAllTime;
  final int overdueCount;
  final Map<String, int> completedByDay; // last 7 days
  final Map<String, int> byPriority;
  final Map<String, int> byList;
  final Map<String, int> byTag;

  const TaskStats({
    this.completedToday = 0,
    this.completedThisWeek = 0,
    this.completedThisMonth = 0,
    this.completedAllTime = 0,
    this.overdueCount = 0,
    this.completedByDay = const {},
    this.byPriority = const {},
    this.byList = const {},
    this.byTag = const {},
  });
}

final taskStatsProvider = Provider<TaskStats>((ref) {
  final tasks = ref.watch(tasksStreamProvider).value ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final monthStart = DateTime(now.year, now.month, 1);

  final completed = tasks.where((t) => t.isCompleted).toList();
  final incomplete = tasks.where((t) => !t.isCompleted).toList();

  // Completed counts by period
  int completedToday = 0;
  int completedThisWeek = 0;
  int completedThisMonth = 0;

  for (final t in completed) {
    final date = t.completedAt ?? t.updatedAt;
    if (!date.isBefore(today)) completedToday++;
    if (!date.isBefore(weekStart)) completedThisWeek++;
    if (!date.isBefore(monthStart)) completedThisMonth++;
  }

  // Overdue tasks
  int overdueCount = 0;
  for (final t in incomplete) {
    if (t.dueDate != null && t.dueDate!.isBefore(today)) {
      overdueCount++;
    }
  }

  // Completed by day (last 7 days)
  final Map<String, int> completedByDay = {};
  for (int i = 6; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    final dayEnd = day.add(const Duration(days: 1));
    final key = '${day.month}/${day.day}';
    completedByDay[key] = completed.where((t) {
      final date = t.completedAt ?? t.updatedAt;
      return !date.isBefore(day) && date.isBefore(dayEnd);
    }).length;
  }

  // By priority
  final Map<String, int> byPriority = {};
  for (final t in completed) {
    final key = t.priority.label;
    byPriority[key] = (byPriority[key] ?? 0) + 1;
  }

  // By list
  final Map<String, int> byList = {};
  for (final t in completed) {
    final key = t.listId.isEmpty ? 'Inbox' : t.listId;
    byList[key] = (byList[key] ?? 0) + 1;
  }

  // By tag
  final Map<String, int> byTag = {};
  for (final t in completed) {
    if (t.tags.isEmpty) {
      byTag['Untagged'] = (byTag['Untagged'] ?? 0) + 1;
    } else {
      for (final tag in t.tags) {
        byTag[tag] = (byTag[tag] ?? 0) + 1;
      }
    }
  }

  return TaskStats(
    completedToday: completedToday,
    completedThisWeek: completedThisWeek,
    completedThisMonth: completedThisMonth,
    completedAllTime: completed.length,
    overdueCount: overdueCount,
    completedByDay: completedByDay,
    byPriority: byPriority,
    byList: byList,
    byTag: byTag,
  );
});

// Focus statistics
class FocusStats {
  final int totalSessions;
  final int totalMinutes;
  final int todayMinutes;
  final int thisWeekMinutes;
  final int thisMonthMinutes;
  final Map<String, int> minutesByDay; // last 7 days
  final Map<String, int> minutesByList;

  const FocusStats({
    this.totalSessions = 0,
    this.totalMinutes = 0,
    this.todayMinutes = 0,
    this.thisWeekMinutes = 0,
    this.thisMonthMinutes = 0,
    this.minutesByDay = const {},
    this.minutesByList = const {},
  });
}

final focusStatsProvider = Provider<FocusStats>((ref) {
  final sessions = ref.watch(focusSessionsStreamProvider).value ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final monthStart = DateTime(now.year, now.month, 1);

  int todayMinutes = 0;
  int thisWeekMinutes = 0;
  int thisMonthMinutes = 0;
  int totalMinutes = 0;

  for (final s in sessions) {
    totalMinutes += s.durationMinutes;
    if (!s.startTime.isBefore(today)) todayMinutes += s.durationMinutes;
    if (!s.startTime.isBefore(weekStart)) thisWeekMinutes += s.durationMinutes;
    if (!s.startTime.isBefore(monthStart)) thisMonthMinutes += s.durationMinutes;
  }

  // By day (last 7 days)
  final Map<String, int> minutesByDay = {};
  for (int i = 6; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    final dayEnd = day.add(const Duration(days: 1));
    final key = '${day.month}/${day.day}';
    int mins = 0;
    for (final s in sessions) {
      if (!s.startTime.isBefore(day) && s.startTime.isBefore(dayEnd)) {
        mins += s.durationMinutes;
      }
    }
    minutesByDay[key] = mins;
  }

  // By list
  final Map<String, int> minutesByList = {};
  for (final s in sessions) {
    final key = s.listId ?? 'Unassigned';
    minutesByList[key] = (minutesByList[key] ?? 0) + s.durationMinutes;
  }

  return FocusStats(
    totalSessions: sessions.length,
    totalMinutes: totalMinutes,
    todayMinutes: todayMinutes,
    thisWeekMinutes: thisWeekMinutes,
    thisMonthMinutes: thisMonthMinutes,
    minutesByDay: minutesByDay,
    minutesByList: minutesByList,
  );
});

// Habit statistics
class HabitStats {
  final int totalHabits;

  const HabitStats({
    this.totalHabits = 0,
  });
}

final habitStatsProvider = Provider<HabitStats>((ref) {
  final habits = ref.watch(habitsStreamProvider).value ?? [];
  return HabitStats(totalHabits: habits.length);
});

// Achievements
class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool unlocked;
  final int progress;
  final int target;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.unlocked = false,
    this.progress = 0,
    this.target = 1,
  });
}

final achievementsProvider = Provider<List<Achievement>>((ref) {
  final taskStats = ref.watch(taskStatsProvider);
  final focusStats = ref.watch(focusStatsProvider);

  return [
    // Task milestones
    Achievement(
      id: 'tasks_10',
      title: 'Getting Started',
      description: 'Complete 10 tasks',
      icon: '🌱',
      unlocked: taskStats.completedAllTime >= 10,
      progress: taskStats.completedAllTime,
      target: 10,
    ),
    Achievement(
      id: 'tasks_50',
      title: 'Task Warrior',
      description: 'Complete 50 tasks',
      icon: '⚔️',
      unlocked: taskStats.completedAllTime >= 50,
      progress: taskStats.completedAllTime,
      target: 50,
    ),
    Achievement(
      id: 'tasks_100',
      title: 'Century Club',
      description: 'Complete 100 tasks',
      icon: '💯',
      unlocked: taskStats.completedAllTime >= 100,
      progress: taskStats.completedAllTime,
      target: 100,
    ),
    Achievement(
      id: 'tasks_500',
      title: 'Task Master',
      description: 'Complete 500 tasks',
      icon: '👑',
      unlocked: taskStats.completedAllTime >= 500,
      progress: taskStats.completedAllTime,
      target: 500,
    ),
    Achievement(
      id: 'tasks_1000',
      title: 'Legendary',
      description: 'Complete 1000 tasks',
      icon: '🏆',
      unlocked: taskStats.completedAllTime >= 1000,
      progress: taskStats.completedAllTime,
      target: 1000,
    ),
    // Focus milestones
    Achievement(
      id: 'focus_1h',
      title: 'First Focus',
      description: 'Accumulate 1 hour of focus time',
      icon: '🎯',
      unlocked: focusStats.totalMinutes >= 60,
      progress: focusStats.totalMinutes,
      target: 60,
    ),
    Achievement(
      id: 'focus_10h',
      title: 'Deep Worker',
      description: 'Accumulate 10 hours of focus time',
      icon: '🧠',
      unlocked: focusStats.totalMinutes >= 600,
      progress: focusStats.totalMinutes,
      target: 600,
    ),
    Achievement(
      id: 'focus_50h',
      title: 'Focus Guru',
      description: 'Accumulate 50 hours of focus time',
      icon: '🧘',
      unlocked: focusStats.totalMinutes >= 3000,
      progress: focusStats.totalMinutes,
      target: 3000,
    ),
    // Productivity milestones
    Achievement(
      id: 'daily_5',
      title: 'Productive Day',
      description: 'Complete 5 tasks in one day',
      icon: '⚡',
      unlocked: taskStats.completedToday >= 5,
      progress: taskStats.completedToday,
      target: 5,
    ),
  ];
});
