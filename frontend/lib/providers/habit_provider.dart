import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/habit.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';

final habitsStreamProvider = StreamProvider<List<Habit>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchHabits(user.uid);
});

final habitsBySectionProvider =
    Provider<Map<HabitSection, List<Habit>>>((ref) {
  final habits = ref.watch(habitsStreamProvider).value ?? [];
  final grouped = <HabitSection, List<Habit>>{};
  for (final section in HabitSection.values) {
    final sectionHabits = habits.where((h) => h.section == section).toList();
    if (sectionHabits.isNotEmpty) {
      grouped[section] = sectionHabits;
    }
  }
  return grouped;
});

final habitLogsProvider =
    StreamProvider.family<List<HabitLog>, String>((ref, habitId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchHabitLogs(user.uid, habitId);
});

final todayLogsMapProvider = Provider.family<HabitLog?, String>((ref, habitId) {
  final logs = ref.watch(habitLogsProvider(habitId)).value ?? [];
  final today = _todayString();
  final matches = logs.where((l) => l.date == today);
  return matches.isEmpty ? null : matches.first;
});

String _todayString() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}
