import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/habit.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/habit_provider.dart';
import 'package:ticktick_clone/screens/habits/habit_edit_screen.dart';
import 'package:ticktick_clone/screens/habits/habit_detail_screen.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsStreamProvider);
    final habitsBySection = ref.watch(habitsBySectionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Habits',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HabitEditScreen()),
            ),
          ),
        ],
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (habits) {
          if (habits.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat_outlined,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No habits yet',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HabitEditScreen()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Habit'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final entry in habitsBySection.entries) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    entry.key.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                for (final habit in entry.value)
                  _HabitTile(habit: habit),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HabitTile extends ConsumerWidget {
  final Habit habit;
  const _HabitTile({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final todayLog = ref.watch(todayLogsMapProvider(habit.id));
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final bool isCompleted;
    if (habit.goalType == HabitGoalType.count) {
      isCompleted =
          todayLog != null && todayLog.value >= (habit.goalCount ?? 1);
    } else {
      isCompleted = todayLog != null && todayLog.value > 0 && !todayLog.skipped;
    }

    final int currentValue = todayLog?.value ?? 0;

    return ListTile(
      leading: _buildCheckIn(context, ref, user?.uid, todayStr, isCompleted,
          currentValue, theme),
      title: Text(habit.name),
      subtitle: _buildSubtitle(theme, currentValue, isCompleted),
      trailing: habit.icon != null
          ? Text(habit.icon!, style: const TextStyle(fontSize: 24))
          : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => HabitDetailScreen(habitId: habit.id)),
      ),
    );
  }

  Widget _buildCheckIn(BuildContext context, WidgetRef ref, String? uid,
      String todayStr, bool isCompleted, int currentValue, ThemeData theme) {
    if (habit.goalType == HabitGoalType.count) {
      return GestureDetector(
        onTap: () {
          if (uid == null) return;
          final newValue = currentValue + 1;
          ref
              .read(firestoreServiceProvider)
              .logHabit(uid, habit.id, todayStr, newValue);
        },
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: (habit.goalCount ?? 1) > 0
                    ? currentValue / (habit.goalCount ?? 1)
                    : 0,
                strokeWidth: 3,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: isCompleted
                    ? Colors.green
                    : theme.colorScheme.primary,
              ),
              Text('$currentValue',
                  style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Checkbox(
      value: isCompleted,
      shape: const CircleBorder(),
      onChanged: (v) {
        if (uid == null) return;
        if (v == true) {
          ref
              .read(firestoreServiceProvider)
              .logHabit(uid, habit.id, todayStr, 1);
        } else {
          ref
              .read(firestoreServiceProvider)
              .deleteHabitLog(uid, habit.id, todayStr);
        }
      },
    );
  }

  Widget? _buildSubtitle(ThemeData theme, int currentValue, bool isCompleted) {
    if (habit.goalType == HabitGoalType.count && habit.goalCount != null) {
      return Text(
        '$currentValue / ${habit.goalCount}',
        style: theme.textTheme.bodySmall?.copyWith(
            color: isCompleted ? Colors.green : theme.colorScheme.outline),
      );
    }
    return Text(
      habit.frequency.label,
      style: theme.textTheme.bodySmall
          ?.copyWith(color: theme.colorScheme.outline),
    );
  }
}
