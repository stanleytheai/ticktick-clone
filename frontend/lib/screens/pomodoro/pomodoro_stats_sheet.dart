import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ticktick_clone/models/pomodoro_session.dart';
import 'package:ticktick_clone/providers/pomodoro_provider.dart';
import 'package:ticktick_clone/providers/task_provider.dart';

class PomodoroStatsSheet extends ConsumerWidget {
  const PomodoroStatsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(pomodoroHistoryProvider).value ?? [];
    final theme = Theme.of(context);

    // Calculate stats
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday % 7));
    final monthStart = DateTime(now.year, now.month, 1);

    final todaySessions = history.where((s) =>
        s.completed &&
        s.sessionType == PomodoroSessionType.work &&
        s.startTime.isAfter(todayStart));
    final weekSessions = history.where((s) =>
        s.completed &&
        s.sessionType == PomodoroSessionType.work &&
        s.startTime.isAfter(weekStart));
    final monthSessions = history.where((s) =>
        s.completed &&
        s.sessionType == PomodoroSessionType.work &&
        s.startTime.isAfter(monthStart));

    final todayMinutes =
        todaySessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final weekMinutes =
        weekSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final monthMinutes =
        monthSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);

    // Focus by task
    final taskMinutes = <String, int>{};
    for (final s in history
        .where((s) => s.completed && s.sessionType == PomodoroSessionType.work && s.taskId != null)) {
      taskMinutes[s.taskId!] =
          (taskMinutes[s.taskId!] ?? 0) + s.durationMinutes;
    }

    final tasks = ref.watch(tasksStreamProvider).value ?? [];
    final sortedTaskEntries = taskMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ListView(
          controller: scrollController,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Focus Statistics', style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            // Period summary cards
            Row(
              children: [
                _PeriodCard(
                  label: 'Today',
                  minutes: todayMinutes,
                  sessions: todaySessions.length,
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _PeriodCard(
                  label: 'This Week',
                  minutes: weekMinutes,
                  sessions: weekSessions.length,
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _PeriodCard(
                  label: 'This Month',
                  minutes: monthMinutes,
                  sessions: monthSessions.length,
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Focus by task
            if (sortedTaskEntries.isNotEmpty) ...[
              Text('Focus by Task',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...sortedTaskEntries.take(10).map((entry) {
                final task = tasks
                    .where((t) => t.id == entry.key)
                    .firstOrNull;
                final hours = entry.value ~/ 60;
                final mins = entry.value % 60;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.circle, size: 8),
                  title: Text(task?.title ?? 'Unknown task'),
                  trailing: Text(
                    hours > 0 ? '${hours}h ${mins}m' : '${mins}m',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            // Recent history
            Text('Recent Sessions',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...history.take(20).map((session) {
              final task = session.taskId != null
                  ? tasks
                      .where((t) => t.id == session.taskId)
                      .firstOrNull
                  : null;
              return ListTile(
                dense: true,
                leading: Icon(
                  session.completed
                      ? Icons.check_circle
                      : Icons.cancel_outlined,
                  color: session.completed ? Colors.green : Colors.red,
                  size: 20,
                ),
                title: Text(
                  '${session.sessionType.label} - ${session.durationMinutes}m',
                ),
                subtitle: Text(
                  '${DateFormat('MMM d, h:mm a').format(session.startTime)}'
                  '${task != null ? ' - ${task.title}' : ''}',
                ),
              );
            }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final String label;
  final int minutes;
  final int sessions;
  final ThemeData theme;

  const _PeriodCard({
    required this.label,
    required this.minutes,
    required this.sessions,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(timeStr,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text('$sessions sessions',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
