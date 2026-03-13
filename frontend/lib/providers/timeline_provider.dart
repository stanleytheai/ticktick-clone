import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/task_provider.dart';

enum TimelineZoom { day, week, month }

class TimelineFilter {
  final String? listId;
  final String? tag;
  final bool showCompleted;

  const TimelineFilter({this.listId, this.tag, this.showCompleted = false});

  TimelineFilter copyWith({
    String? listId,
    bool clearListId = false,
    String? tag,
    bool clearTag = false,
    bool? showCompleted,
  }) {
    return TimelineFilter(
      listId: clearListId ? null : (listId ?? this.listId),
      tag: clearTag ? null : (tag ?? this.tag),
      showCompleted: showCompleted ?? this.showCompleted,
    );
  }
}

final timelineZoomProvider =
    StateProvider<TimelineZoom>((ref) => TimelineZoom.week);

final timelineFilterProvider =
    StateProvider<TimelineFilter>((ref) => const TimelineFilter());

final timelineScrollDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Tasks that have date information suitable for timeline display.
final timelineTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksStreamProvider).value ?? [];
  final filter = ref.watch(timelineFilterProvider);

  return tasks.where((t) {
    // Must have at least a start date or due date to show on timeline
    if (t.startDate == null && t.dueDate == null) return false;
    if (!filter.showCompleted && t.isCompleted) return false;
    if (filter.listId != null && t.listId != filter.listId) return false;
    if (filter.tag != null && !t.tags.contains(filter.tag)) return false;
    return true;
  }).toList()
    ..sort((a, b) {
      final aStart = a.startDate ?? a.dueDate!;
      final bStart = b.startDate ?? b.dueDate!;
      return aStart.compareTo(bStart);
    });
});

/// Pixels per day for each zoom level.
double pixelsPerDay(TimelineZoom zoom) {
  switch (zoom) {
    case TimelineZoom.day:
      return 120.0;
    case TimelineZoom.week:
      return 40.0;
    case TimelineZoom.month:
      return 12.0;
  }
}
