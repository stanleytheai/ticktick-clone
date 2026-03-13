import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/pomodoro_session.dart';
import 'package:ticktick_clone/providers/pomodoro_provider.dart';
import 'package:ticktick_clone/providers/task_provider.dart';
import 'package:ticktick_clone/screens/pomodoro/pomodoro_settings_sheet.dart';
import 'package:ticktick_clone/screens/pomodoro/pomodoro_stats_sheet.dart';

class PomodoroScreen extends ConsumerWidget {
  const PomodoroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(pomodoroTimerProvider);
    final theme = Theme.of(context);
    final todayMinutes = ref.watch(todayFocusMinutesProvider).value ?? 0;
    final todayCount = ref.watch(todaySessionCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Focus',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const PomodoroStatsSheet(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showModalBottomSheet(
              context: context,
              builder: (_) => const PomodoroSettingsSheet(),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Session type selector
            _SessionTypeSelector(timerState: timerState),
            const SizedBox(height: 32),
            // Timer display
            _TimerDisplay(timerState: timerState),
            const SizedBox(height: 32),
            // Controls
            _TimerControls(timerState: timerState),
            const SizedBox(height: 24),
            // Task selector
            _TaskSelector(taskId: timerState.taskId),
            const SizedBox(height: 24),
            // Ambient sounds
            _AmbientSoundSelector(selectedSounds: timerState.selectedSounds),
            const SizedBox(height: 24),
            // Today's stats summary
            _TodayStats(
              focusMinutes: todayMinutes,
              sessionCount: todayCount,
              completedInCycle: timerState.completedWorkSessions,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SessionTypeSelector extends ConsumerWidget {
  final PomodoroTimerState timerState;
  const _SessionTypeSelector({required this.timerState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIdle = timerState.state == TimerState.idle;

    return SegmentedButton<PomodoroSessionType>(
      segments: PomodoroSessionType.values
          .map((t) => ButtonSegment(
                value: t,
                label: Text(t.label),
              ))
          .toList(),
      selected: {timerState.sessionType},
      onSelectionChanged: isIdle
          ? (selected) => ref
              .read(pomodoroTimerProvider.notifier)
              .setSessionType(selected.first)
          : null,
    );
  }
}

class _TimerDisplay extends StatelessWidget {
  final PomodoroTimerState timerState;
  const _TimerDisplay({required this.timerState});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (timerState.sessionType) {
      PomodoroSessionType.work => theme.colorScheme.primary,
      PomodoroSessionType.shortBreak => Colors.green,
      PomodoroSessionType.longBreak => Colors.blue,
    };

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 240,
            height: 240,
            child: CustomPaint(
              painter: _TimerRingPainter(
                progress: timerState.progress,
                color: color,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timerState.timeDisplay,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w300,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
              Text(
                timerState.sessionType.label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _TimerRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 8.0;

    // Background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_TimerRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _TimerControls extends ConsumerWidget {
  final PomodoroTimerState timerState;
  const _TimerControls({required this.timerState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(pomodoroTimerProvider.notifier);
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (timerState.state != TimerState.idle)
          IconButton.filled(
            onPressed: notifier.stop,
            icon: const Icon(Icons.stop),
            iconSize: 32,
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
          ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: timerState.state == TimerState.running
              ? notifier.pause
              : notifier.start,
          icon: Icon(timerState.state == TimerState.running
              ? Icons.pause
              : Icons.play_arrow),
          label: Text(switch (timerState.state) {
            TimerState.idle => 'Start',
            TimerState.running => 'Pause',
            TimerState.paused => 'Resume',
          }),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _TaskSelector extends ConsumerWidget {
  final String? taskId;
  const _TaskSelector({this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksStreamProvider).value ?? [];
    final incompleteTasks = tasks.where((t) => !t.isCompleted).toList();
    final selectedTask = taskId != null
        ? tasks.where((t) => t.id == taskId).firstOrNull
        : null;
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: Icon(Icons.task_alt, color: theme.colorScheme.primary),
        title: Text(selectedTask?.title ?? 'No task linked'),
        subtitle: selectedTask != null
            ? null
            : const Text('Tap to link a task'),
        trailing: taskId != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () =>
                    ref.read(pomodoroTimerProvider.notifier).setTaskId(null),
              )
            : null,
        onTap: () {
          showModalBottomSheet(
            context: context,
            builder: (ctx) => ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Link to Task',
                      style: theme.textTheme.titleMedium),
                ),
                if (incompleteTasks.isEmpty)
                  const ListTile(
                    title: Text('No incomplete tasks'),
                  ),
                ...incompleteTasks.map((task) => ListTile(
                      leading: const Icon(Icons.circle_outlined),
                      title: Text(task.title),
                      onTap: () {
                        ref
                            .read(pomodoroTimerProvider.notifier)
                            .setTaskId(task.id);
                        Navigator.pop(ctx);
                      },
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AmbientSoundSelector extends ConsumerWidget {
  final List<AmbientSound> selectedSounds;
  const _AmbientSoundSelector({required this.selectedSounds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Ambient Sounds',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AmbientSound.values.map((sound) {
            final isSelected = selectedSounds.contains(sound);
            return FilterChip(
              label: Text(sound.label),
              avatar: Icon(_soundIcon(sound), size: 18),
              selected: isSelected,
              onSelected: (_) =>
                  ref.read(pomodoroTimerProvider.notifier).toggleSound(sound),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _soundIcon(AmbientSound sound) {
    return switch (sound) {
      AmbientSound.rain => Icons.water_drop_outlined,
      AmbientSound.forest => Icons.forest_outlined,
      AmbientSound.cafe => Icons.local_cafe_outlined,
      AmbientSound.ocean => Icons.waves_outlined,
      AmbientSound.fireplace => Icons.local_fire_department_outlined,
    };
  }
}

class _TodayStats extends StatelessWidget {
  final int focusMinutes;
  final int sessionCount;
  final int completedInCycle;

  const _TodayStats({
    required this.focusMinutes,
    required this.sessionCount,
    required this.completedInCycle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.timer_outlined,
              value: '${focusMinutes}m',
              label: 'Today',
              theme: theme,
            ),
            _StatItem(
              icon: Icons.check_circle_outline,
              value: '$sessionCount',
              label: 'Sessions',
              theme: theme,
            ),
            _StatItem(
              icon: Icons.loop,
              value: '$completedInCycle',
              label: 'Cycle',
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final ThemeData theme;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
