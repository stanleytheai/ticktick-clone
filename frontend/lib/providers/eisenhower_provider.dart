import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/task_provider.dart';

enum EisenhowerQuadrant {
  urgentImportant,
  notUrgentImportant,
  urgentNotImportant,
  notUrgentNotImportant,
}

class EisenhowerFilter {
  final String? listId;
  final String? tag;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const EisenhowerFilter({this.listId, this.tag, this.dateFrom, this.dateTo});

  EisenhowerFilter copyWith({
    String? listId,
    bool clearListId = false,
    String? tag,
    bool clearTag = false,
    DateTime? dateFrom,
    bool clearDateFrom = false,
    DateTime? dateTo,
    bool clearDateTo = false,
  }) {
    return EisenhowerFilter(
      listId: clearListId ? null : (listId ?? this.listId),
      tag: clearTag ? null : (tag ?? this.tag),
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
    );
  }
}

final eisenhowerFilterProvider =
    StateProvider<EisenhowerFilter>((ref) => const EisenhowerFilter());

bool _isImportant(TaskPriority priority) {
  return priority == TaskPriority.high || priority == TaskPriority.medium;
}

bool _isUrgent(DateTime? dueDate) {
  if (dueDate == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final urgentThreshold = today.add(const Duration(days: 2));
  return dueDate.isBefore(urgentThreshold);
}

EisenhowerQuadrant classifyTask(Task task) {
  final important = _isImportant(task.priority);
  final urgent = _isUrgent(task.dueDate);

  if (urgent && important) return EisenhowerQuadrant.urgentImportant;
  if (!urgent && important) return EisenhowerQuadrant.notUrgentImportant;
  if (urgent && !important) return EisenhowerQuadrant.urgentNotImportant;
  return EisenhowerQuadrant.notUrgentNotImportant;
}

final _filteredTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksStreamProvider).value ?? [];
  final filter = ref.watch(eisenhowerFilterProvider);

  return tasks.where((t) {
    if (t.isCompleted) return false;
    if (filter.listId != null && t.listId != filter.listId) return false;
    if (filter.tag != null && !t.tags.contains(filter.tag)) return false;
    if (filter.dateFrom != null && t.dueDate != null) {
      if (t.dueDate!.isBefore(filter.dateFrom!)) return false;
    }
    if (filter.dateTo != null && t.dueDate != null) {
      if (t.dueDate!.isAfter(filter.dateTo!)) return false;
    }
    return true;
  }).toList();
});

final eisenhowerTasksProvider =
    Provider.family<List<Task>, EisenhowerQuadrant>((ref, quadrant) {
  final tasks = ref.watch(_filteredTasksProvider);
  return tasks.where((t) => classifyTask(t) == quadrant).toList();
});

final allTagsProvider = Provider<List<String>>((ref) {
  final tasks = ref.watch(tasksStreamProvider).value ?? [];
  final tags = <String>{};
  for (final task in tasks) {
    tags.addAll(task.tags);
  }
  final sorted = tags.toList()..sort();
  return sorted;
});
