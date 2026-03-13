import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';

final tasksStreamProvider = StreamProvider<List<Task>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchTasks(user.uid);
});

final tasksByListProvider =
    Provider.family<List<Task>, String>((ref, listId) {
  final tasks = ref.watch(tasksStreamProvider).value ?? [];
  return tasks.where((t) => t.listId == listId).toList();
});

final todayTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksStreamProvider).value ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  return tasks.where((t) {
    if (t.isCompleted) return false;
    if (t.dueDate == null) return false;
    return t.dueDate!.isAfter(today.subtract(const Duration(seconds: 1))) &&
        t.dueDate!.isBefore(tomorrow);
  }).toList();
});

final inboxTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksStreamProvider).value ?? [];
  return tasks.where((t) => t.listId == 'inbox' && !t.isCompleted).toList();
});
