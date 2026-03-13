import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/providers/pomodoro_provider.dart';

class PomodoroSettingsSheet extends ConsumerWidget {
  const PomodoroSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(pomodoroSettingsProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Timer Settings', style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),
          _DurationSetting(
            label: 'Work Duration',
            value: settings.workMinutes,
            min: 1,
            max: 120,
            onChanged: (v) => ref.read(pomodoroSettingsProvider.notifier).state =
                settings.copyWith(workMinutes: v),
          ),
          _DurationSetting(
            label: 'Short Break',
            value: settings.shortBreakMinutes,
            min: 1,
            max: 30,
            onChanged: (v) => ref.read(pomodoroSettingsProvider.notifier).state =
                settings.copyWith(shortBreakMinutes: v),
          ),
          _DurationSetting(
            label: 'Long Break',
            value: settings.longBreakMinutes,
            min: 1,
            max: 60,
            onChanged: (v) => ref.read(pomodoroSettingsProvider.notifier).state =
                settings.copyWith(longBreakMinutes: v),
          ),
          _DurationSetting(
            label: 'Sessions Until Long Break',
            value: settings.sessionsUntilLongBreak,
            min: 2,
            max: 10,
            onChanged: (v) => ref.read(pomodoroSettingsProvider.notifier).state =
                settings.copyWith(sessionsUntilLongBreak: v),
          ),
          SwitchListTile(
            title: const Text('Auto-start next session'),
            value: settings.autoStartNext,
            onChanged: (v) => ref.read(pomodoroSettingsProvider.notifier).state =
                settings.copyWith(autoStartNext: v),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DurationSetting extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _DurationSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyLarge),
          ),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
