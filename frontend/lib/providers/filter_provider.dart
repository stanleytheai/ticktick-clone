import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/smart_filter.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/task_provider.dart';

// Stream of user's custom filters from Firestore
final filtersStreamProvider = StreamProvider<List<SmartFilter>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchFilters(user.uid);
});

// Only pinned filters (for sidebar display)
final pinnedFiltersProvider = Provider<List<SmartFilter>>((ref) {
  final filters = ref.watch(filtersStreamProvider).value ?? [];
  return filters.where((f) => f.pinned).toList();
});

// Apply a SmartFilter's criteria to the full task list
final filteredTasksProvider =
    Provider.family<List<Task>, SmartFilter>((ref, filter) {
  final tasks = ref.watch(tasksStreamProvider).value ?? [];
  return tasks.where((task) => _matchesFilter(task, filter)).toList();
});

// Built-in smart list definitions
enum BuiltInSmartList {
  today('today', 'Today', 'today'),
  tomorrow('tomorrow', 'Tomorrow', 'next_plan'),
  next7Days('next7days', 'Next 7 Days', 'date_range'),
  all('all', 'All', 'all_inclusive'),
  completed('completed', 'Completed', 'task_alt'),
  trash('trash', 'Trash', 'delete');

  const BuiltInSmartList(this.id, this.label, this.iconName);
  final String id;
  final String label;
  final String iconName;
}

// Provider for built-in smart list tasks
final builtInSmartListTasksProvider =
    Provider.family<List<Task>, BuiltInSmartList>((ref, smartList) {
  final tasks = ref.watch(tasksStreamProvider).value ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  switch (smartList) {
    case BuiltInSmartList.today:
      final tomorrow = today.add(const Duration(days: 1));
      return tasks.where((t) {
        if (t.isCompleted) return false;
        if (t.dueDate == null) return false;
        return t.dueDate!.isAfter(today.subtract(const Duration(seconds: 1))) &&
            t.dueDate!.isBefore(tomorrow);
      }).toList();
    case BuiltInSmartList.tomorrow:
      final tomorrowStart = today.add(const Duration(days: 1));
      final dayAfter = today.add(const Duration(days: 2));
      return tasks.where((t) {
        if (t.isCompleted) return false;
        if (t.dueDate == null) return false;
        return t.dueDate!.isAfter(tomorrowStart.subtract(const Duration(seconds: 1))) &&
            t.dueDate!.isBefore(dayAfter);
      }).toList();
    case BuiltInSmartList.next7Days:
      final weekEnd = today.add(const Duration(days: 7));
      return tasks.where((t) {
        if (t.isCompleted) return false;
        if (t.dueDate == null) return false;
        return t.dueDate!.isAfter(today.subtract(const Duration(seconds: 1))) &&
            t.dueDate!.isBefore(weekEnd);
      }).toList();
    case BuiltInSmartList.all:
      return tasks.where((t) => !t.isCompleted).toList();
    case BuiltInSmartList.completed:
      return tasks.where((t) => t.isCompleted).toList();
    case BuiltInSmartList.trash:
      // Trash would require a soft-delete field; for now return empty
      return [];
  }
});

// Filter matching logic
bool _matchesFilter(Task task, SmartFilter filter) {
  if (filter.logic == FilterLogic.and) {
    return filter.criteria.every((c) => _matchesCriterion(task, c));
  } else {
    return filter.criteria.any((c) => _matchesCriterion(task, c));
  }
}

bool _matchesCriterion(Task task, FilterCriterion criterion) {
  switch (criterion.type) {
    case FilterCriterionType.dueDate:
      return _matchDateCriterion(task.dueDate, criterion);
    case FilterCriterionType.priority:
      return _matchPriorityCriterion(task.priority, criterion);
    case FilterCriterionType.tag:
      return _matchTagCriterion(task.tags, criterion);
    case FilterCriterionType.list:
      return _matchListCriterion(task.listId, criterion);
    case FilterCriterionType.completed:
      return _matchCompletedCriterion(task.isCompleted, criterion);
    case FilterCriterionType.keyword:
      return _matchKeywordCriterion(task, criterion);
    case FilterCriterionType.createdDate:
      return _matchDateCriterion(task.createdAt, criterion);
  }
}

bool _matchDateCriterion(DateTime? date, FilterCriterion criterion) {
  switch (criterion.operator) {
    case FilterOperator.isSet:
      return date != null;
    case FilterOperator.isNotSet:
      return date == null;
    case FilterOperator.before:
      if (date == null || criterion.value == null) return false;
      return date.isBefore(DateTime.parse(criterion.value as String));
    case FilterOperator.after:
      if (date == null || criterion.value == null) return false;
      return date.isAfter(DateTime.parse(criterion.value as String));
    case FilterOperator.between:
      if (date == null || criterion.value == null || criterion.valueTo == null) {
        return false;
      }
      final from = DateTime.parse(criterion.value as String);
      final to = DateTime.parse(criterion.valueTo!);
      return date.isAfter(from.subtract(const Duration(seconds: 1))) &&
          date.isBefore(to.add(const Duration(days: 1)));
    case FilterOperator.equals:
      if (date == null || criterion.value == null) return false;
      final target = DateTime.parse(criterion.value as String);
      return date.year == target.year &&
          date.month == target.month &&
          date.day == target.day;
    default:
      return true;
  }
}

bool _matchPriorityCriterion(TaskPriority priority, FilterCriterion criterion) {
  final value = criterion.value;
  if (value == null) return true;
  final targetValue = value is int ? value : int.tryParse(value.toString()) ?? 0;
  switch (criterion.operator) {
    case FilterOperator.equals:
      return priority.value == targetValue;
    case FilterOperator.notEquals:
      return priority.value != targetValue;
    default:
      return true;
  }
}

bool _matchTagCriterion(List<String> tags, FilterCriterion criterion) {
  final value = criterion.value;
  switch (criterion.operator) {
    case FilterOperator.contains:
      if (value is String) return tags.contains(value);
      if (value is List) return value.any((v) => tags.contains(v));
      return false;
    case FilterOperator.isSet:
      return tags.isNotEmpty;
    case FilterOperator.isNotSet:
      return tags.isEmpty;
    default:
      return true;
  }
}

bool _matchListCriterion(String listId, FilterCriterion criterion) {
  final value = criterion.value;
  if (value == null) return true;
  switch (criterion.operator) {
    case FilterOperator.equals:
      return listId == value.toString();
    case FilterOperator.notEquals:
      return listId != value.toString();
    default:
      return true;
  }
}

bool _matchCompletedCriterion(bool isCompleted, FilterCriterion criterion) {
  final value = criterion.value;
  if (value == null) return true;
  final target = value is bool ? value : value.toString() == 'true';
  switch (criterion.operator) {
    case FilterOperator.equals:
      return isCompleted == target;
    case FilterOperator.notEquals:
      return isCompleted != target;
    default:
      return true;
  }
}

bool _matchKeywordCriterion(Task task, FilterCriterion criterion) {
  final value = criterion.value;
  if (value == null || value.toString().isEmpty) return true;
  final keyword = value.toString().toLowerCase();
  switch (criterion.operator) {
    case FilterOperator.contains:
      return task.title.toLowerCase().contains(keyword) ||
          task.description.toLowerCase().contains(keyword);
    case FilterOperator.notEquals:
      return !task.title.toLowerCase().contains(keyword) &&
          !task.description.toLowerCase().contains(keyword);
    default:
      return task.title.toLowerCase().contains(keyword) ||
          task.description.toLowerCase().contains(keyword);
  }
}
