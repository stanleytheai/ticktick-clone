import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ticktick_clone/models/habit.dart';
import 'package:ticktick_clone/providers/habit_provider.dart';
import 'package:ticktick_clone/screens/habits/habit_edit_screen.dart';

class HabitDetailScreen extends ConsumerWidget {
  final String habitId;

  const HabitDetailScreen({super.key, required this.habitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsStreamProvider);
    final logsAsync = ref.watch(habitLogsProvider(habitId));
    final theme = Theme.of(context);

    return habitsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (habits) {
        final habit = habits.where((h) => h.id == habitId).firstOrNull;
        if (habit == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Habit not found')),
          );
        }

        final logs = logsAsync.value ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Text(habit.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HabitEditScreen(habit: habit)),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StreakCard(logs: logs, theme: theme),
              const SizedBox(height: 16),
              _StatsCard(logs: logs, habit: habit, theme: theme),
              const SizedBox(height: 16),
              Text('Calendar', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _CalendarHeatMap(logs: logs, theme: theme),
            ],
          ),
        );
      },
    );
  }
}

class _StreakCard extends StatelessWidget {
  final List<HabitLog> logs;
  final ThemeData theme;

  const _StreakCard({required this.logs, required this.theme});

  @override
  Widget build(BuildContext context) {
    final completedDates = logs
        .where((l) => !l.skipped && l.value > 0)
        .map((l) => l.date)
        .toSet();

    final streaks = _calculateStreaks(completedDates);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _StatColumn(
                label: 'Current Streak',
                value: '${streaks.$1}',
                icon: Icons.local_fire_department,
                color: Colors.orange,
              ),
            ),
            Container(
              width: 1,
              height: 48,
              color: theme.colorScheme.outlineVariant,
            ),
            Expanded(
              child: _StatColumn(
                label: 'Longest Streak',
                value: '${streaks.$2}',
                icon: Icons.emoji_events,
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (int current, int longest) _calculateStreaks(Set<String> dates) {
    if (dates.isEmpty) return (0, 0);

    final today = DateTime.now();

    // Current streak (counting back from today)
    int currentStreak = 0;
    var checkDate = today;
    for (var i = 0; i < 365; i++) {
      final dateStr =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (dates.contains(dateStr)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (i == 0) {
        // If today isn't logged, check yesterday
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      } else {
        break;
      }
    }

    // Longest streak
    final sorted = dates.toList()..sort();
    int longestStreak = 0;
    int tempStreak = 0;
    for (var i = 0; i < sorted.length; i++) {
      if (i == 0) {
        tempStreak = 1;
      } else {
        final prev = DateTime.parse(sorted[i - 1]);
        final curr = DateTime.parse(sorted[i]);
        if (curr.difference(prev).inDays == 1) {
          tempStreak++;
        } else {
          tempStreak = 1;
        }
      }
      if (tempStreak > longestStreak) longestStreak = tempStreak;
    }

    return (currentStreak, longestStreak);
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  final List<HabitLog> logs;
  final Habit habit;
  final ThemeData theme;

  const _StatsCard(
      {required this.logs, required this.habit, required this.theme});

  @override
  Widget build(BuildContext context) {
    final completed = logs.where((l) => !l.skipped && l.value > 0).length;
    final total = logs.length;
    final rate = total > 0 ? (completed / total * 100).round() : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statistics', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _StatRow(label: 'Total logged days', value: '$total'),
            _StatRow(label: 'Completed', value: '$completed'),
            _StatRow(label: 'Completion rate', value: '$rate%'),
            _StatRow(
                label: 'Frequency', value: habit.frequency.label),
            if (habit.goalType == HabitGoalType.count &&
                habit.goalCount != null)
              _StatRow(
                  label: 'Goal',
                  value: '${habit.goalCount} per day'),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CalendarHeatMap extends StatelessWidget {
  final List<HabitLog> logs;
  final ThemeData theme;

  const _CalendarHeatMap({required this.logs, required this.theme});

  @override
  Widget build(BuildContext context) {
    final logMap = <String, HabitLog>{};
    for (final log in logs) {
      logMap[log.date] = log;
    }

    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 90));

    return SizedBox(
      height: 120,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: 91,
        itemBuilder: (context, index) {
          final date = startDate.add(Duration(days: index));
          final dateStr =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final log = logMap[dateStr];

          Color color;
          if (log == null) {
            color = theme.colorScheme.surfaceContainerHighest;
          } else if (log.skipped) {
            color = theme.colorScheme.outlineVariant;
          } else if (log.value > 0) {
            color = Colors.green.withValues(alpha: 0.4 + (log.value * 0.15).clamp(0.0, 0.6));
          } else {
            color = theme.colorScheme.surfaceContainerHighest;
          }

          final isToday = dateStr ==
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

          return Tooltip(
            message:
                '${DateFormat.MMMd().format(date)}: ${log != null && log.value > 0 ? "done" : "—"}',
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                border: isToday
                    ? Border.all(
                        color: theme.colorScheme.primary, width: 1.5)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
