import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/habit.dart';
import 'package:ticktick_clone/providers/statistics_provider.dart';

class HabitStatsTab extends ConsumerWidget {
  const HabitStatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(habitStatsProvider);
    final habits = ref.watch(habitsStreamProvider).value ?? [];
    final theme = Theme.of(context);

    if (habits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.repeat_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('No habits tracked yet',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Create habits to see completion stats here',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.repeat,
                    size: 40, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${stats.totalHabits} Active Habits',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Track your daily habits below',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Per-habit log calendar
        for (final habit in habits) ...[
          _HabitLogCard(habit: habit, theme: theme),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HabitLogCard extends ConsumerWidget {
  final Habit habit;
  final ThemeData theme;

  const _HabitLogCard({required this.habit, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(habitLogsProvider(habit.id));
    final logs = logsAsync.value ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (habit.icon != null) ...[
                  Text(habit.icon!, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(habit.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Text(habit.frequency.label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
            const SizedBox(height: 12),
            _HabitCalendarHeatmap(logs: logs, theme: theme),
            if (logs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${logs.where((l) => !l.skipped).length} completions logged',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HabitCalendarHeatmap extends StatelessWidget {
  final List<HabitLog> logs;
  final ThemeData theme;

  const _HabitCalendarHeatmap({required this.logs, required this.theme});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(const Duration(days: 34));

    // Build set of completed dates (HabitLog.date is yyyy-MM-dd string)
    final completedDates = <String>{};
    for (final log in logs) {
      if (!log.skipped) {
        completedDates.add(log.date);
      }
    }

    return SizedBox(
      height: 80,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
        ),
        itemCount: 35,
        itemBuilder: (context, index) {
          final date = startDate.add(Duration(days: index));
          final key =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final completed = completedDates.contains(key);
          final isFuture = date.isAfter(today);

          return Tooltip(
            message: '${date.month}/${date.day}',
            child: Container(
              decoration: BoxDecoration(
                color: isFuture
                    ? theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3)
                    : completed
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        },
      ),
    );
  }
}
