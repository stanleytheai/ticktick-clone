import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/list_provider.dart';
import 'package:ticktick_clone/providers/timeline_provider.dart';
import 'package:ticktick_clone/screens/tasks/task_detail_screen.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  late ScrollController _horizontalController;
  late ScrollController _verticalController;
  late ScrollController _headerScrollController;

  static const double _rowHeight = 44.0;
  static const double _headerHeight = 52.0;
  static const double _labelWidth = 180.0;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
    _verticalController = ScrollController();
    _headerScrollController = ScrollController();

    // Sync horizontal scroll between header and body
    _horizontalController.addListener(() {
      if (_headerScrollController.hasClients) {
        _headerScrollController.jumpTo(_horizontalController.offset);
      }
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _headerScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = ref.watch(timelineTasksProvider);
    final zoom = ref.watch(timelineZoomProvider);
    final filter = ref.watch(timelineFilterProvider);
    final lists = ref.watch(listsStreamProvider).value ?? [];
    final ppd = pixelsPerDay(zoom);

    // Calculate timeline range from tasks
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime rangeStart;
    DateTime rangeEnd;
    if (tasks.isEmpty) {
      rangeStart = today.subtract(const Duration(days: 7));
      rangeEnd = today.add(const Duration(days: 30));
    } else {
      rangeStart = tasks
          .map((t) => t.startDate ?? t.dueDate!)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      rangeEnd = tasks.map((t) {
        final start = t.startDate ?? t.dueDate!;
        if (t.duration != null && t.duration! > 0) {
          return start.add(Duration(minutes: t.duration!));
        }
        return t.dueDate ?? start.add(const Duration(days: 1));
      }).reduce((a, b) => a.isAfter(b) ? a : b);
      // Add padding
      rangeStart = rangeStart.subtract(const Duration(days: 7));
      rangeEnd = rangeEnd.add(const Duration(days: 14));
    }

    final totalDays = rangeEnd.difference(rangeStart).inDays + 1;
    final totalWidth = totalDays * ppd;

    return Scaffold(
      appBar: AppBar(
        title: Text('Timeline',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          // Zoom controls
          SegmentedButton<TimelineZoom>(
            segments: const [
              ButtonSegment(value: TimelineZoom.day, label: Text('Day')),
              ButtonSegment(value: TimelineZoom.week, label: Text('Week')),
              ButtonSegment(value: TimelineZoom.month, label: Text('Month')),
            ],
            selected: {zoom},
            onSelectionChanged: (v) =>
                ref.read(timelineZoomProvider.notifier).state = v.first,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          // Today button
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Go to today',
            onPressed: () {
              final dayOffset = today.difference(rangeStart).inDays;
              final targetOffset = dayOffset * ppd - 200;
              _horizontalController.animateTo(
                targetOffset.clamp(0, max(0, totalWidth - 400)),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
          ),
          // Filter
          PopupMenuButton<String>(
            icon: Badge(
              isLabelVisible: filter.listId != null || filter.tag != null,
              child: const Icon(Icons.filter_list),
            ),
            onSelected: (value) {
              if (value == 'clear') {
                ref.read(timelineFilterProvider.notifier).state =
                    const TimelineFilter();
              } else if (value == 'toggle_completed') {
                final current = ref.read(timelineFilterProvider);
                ref.read(timelineFilterProvider.notifier).state =
                    current.copyWith(showCompleted: !current.showCompleted);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_completed',
                child: Row(
                  children: [
                    Icon(
                      filter.showCompleted
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Show completed'),
                  ],
                ),
              ),
              if (lists.isNotEmpty) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  enabled: false,
                  child: Text('Filter by List',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                ),
                ...lists.map((list) => PopupMenuItem(
                      value: 'list:${list.id}',
                      onTap: () {
                        final current = ref.read(timelineFilterProvider);
                        ref.read(timelineFilterProvider.notifier).state =
                            current.listId == list.id
                                ? current.copyWith(clearListId: true)
                                : current.copyWith(listId: list.id);
                      },
                      child: Row(
                        children: [
                          Icon(Icons.circle,
                              size: 12, color: Color(list.colorValue)),
                          const SizedBox(width: 8),
                          Text(list.name),
                          if (filter.listId == list.id) ...[
                            const Spacer(),
                            const Icon(Icons.check, size: 18),
                          ],
                        ],
                      ),
                    )),
              ],
              if (filter.listId != null || filter.tag != null) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, size: 18),
                      SizedBox(width: 8),
                      Text('Clear Filters'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      body: tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.view_timeline_outlined,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No tasks with dates',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(
                      'Add start dates to tasks to see them on the timeline',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline)),
                ],
              ),
            )
          : Column(
              children: [
                // Active filter chips
                if (filter.listId != null || filter.tag != null)
                  _ActiveFiltersBar(filter: filter, lists: lists),
                // Timeline content
                Expanded(
                  child: Row(
                    children: [
                      // Task labels (left panel)
                      SizedBox(
                        width: _labelWidth,
                        child: Column(
                          children: [
                            // Corner header
                            Container(
                              height: _headerHeight,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                      color: theme.colorScheme.outlineVariant),
                                  right: BorderSide(
                                      color: theme.colorScheme.outlineVariant),
                                ),
                              ),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 12),
                              child: Text('Tasks',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold)),
                            ),
                            // Task name rows
                            Expanded(
                              child: ListView.builder(
                                controller: _verticalController,
                                itemCount: tasks.length,
                                itemExtent: _rowHeight,
                                itemBuilder: (context, index) {
                                  final task = tasks[index];
                                  final listColor = _getListColor(task, lists);
                                  return Container(
                                    height: _rowHeight,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                            color: theme.colorScheme
                                                .outlineVariant
                                                .withValues(alpha: 0.3)),
                                        right: BorderSide(
                                            color: theme
                                                .colorScheme.outlineVariant),
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => TaskDetailScreen(
                                                taskId: task.id)),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 4,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: listColor,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                task.title,
                                                style: theme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  decoration: task.isCompleted
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                                  color: task.isCompleted
                                                      ? theme
                                                          .colorScheme.outline
                                                      : null,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (task.priority.value > 0)
                                              Icon(Icons.flag,
                                                  size: 12,
                                                  color: Color(
                                                      task.priority.colorValue)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Timeline chart (right panel, scrollable)
                      Expanded(
                        child: Column(
                          children: [
                            // Date header
                            SizedBox(
                              height: _headerHeight,
                              child: _TimelineHeader(
                                scrollController: _headerScrollController,
                                rangeStart: rangeStart,
                                totalDays: totalDays,
                                ppd: ppd,
                                zoom: zoom,
                                today: today,
                              ),
                            ),
                            // Task bars
                            Expanded(
                              child: _TimelineBody(
                                horizontalController: _horizontalController,
                                verticalController: _verticalController,
                                tasks: tasks,
                                rangeStart: rangeStart,
                                totalDays: totalDays,
                                totalWidth: totalWidth,
                                ppd: ppd,
                                rowHeight: _rowHeight,
                                today: today,
                                lists: lists,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Color _getListColor(Task task, List<dynamic> lists) {
    try {
      final list = lists.firstWhere((l) => l.id == task.listId);
      return Color(list.colorValue);
    } catch (_) {
      return Colors.grey;
    }
  }
}

class _ActiveFiltersBar extends ConsumerWidget {
  final TimelineFilter filter;
  final List<dynamic> lists;

  const _ActiveFiltersBar({required this.filter, required this.lists});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 8,
        children: [
          if (filter.listId != null)
            Chip(
              label: Text(_listName(filter.listId!)),
              onDeleted: () => ref
                  .read(timelineFilterProvider.notifier)
                  .state = filter.copyWith(clearListId: true),
              visualDensity: VisualDensity.compact,
            ),
          if (filter.tag != null)
            Chip(
              label: Text('#${filter.tag}'),
              onDeleted: () => ref
                  .read(timelineFilterProvider.notifier)
                  .state = filter.copyWith(clearTag: true),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  String _listName(String listId) {
    try {
      final list = lists.firstWhere((l) => l.id == listId);
      return list.name;
    } catch (_) {
      return listId;
    }
  }
}

class _TimelineHeader extends StatelessWidget {
  final ScrollController scrollController;
  final DateTime rangeStart;
  final int totalDays;
  final double ppd;
  final TimelineZoom zoom;
  final DateTime today;

  const _TimelineHeader({
    required this.scrollController,
    required this.rangeStart,
    required this.totalDays,
    required this.ppd,
    required this.zoom,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          width: totalDays * ppd,
          child: CustomPaint(
            size: Size(totalDays * ppd, 52),
            painter: _HeaderPainter(
              rangeStart: rangeStart,
              totalDays: totalDays,
              ppd: ppd,
              zoom: zoom,
              today: today,
              theme: theme,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderPainter extends CustomPainter {
  final DateTime rangeStart;
  final int totalDays;
  final double ppd;
  final TimelineZoom zoom;
  final DateTime today;
  final ThemeData theme;

  _HeaderPainter({
    required this.rangeStart,
    required this.totalDays,
    required this.ppd,
    required this.zoom,
    required this.today,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final labelStyle = TextStyle(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 10,
    );
    final monthStyle = TextStyle(
      color: theme.colorScheme.onSurface,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    final todayStyle = TextStyle(
      color: theme.colorScheme.primary,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    final linePaint = Paint()
      ..color = theme.colorScheme.outlineVariant.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;

    String? lastMonth;

    for (int i = 0; i < totalDays; i++) {
      final date = rangeStart.add(Duration(days: i));
      final x = i * ppd;
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;

      // Draw vertical grid line
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);

      // Draw month label at month boundaries or first visible day
      final monthLabel = DateFormat.yMMM().format(date);
      if (monthLabel != lastMonth) {
        lastMonth = monthLabel;
        _drawText(canvas, monthLabel, Offset(x + 4, 4), monthStyle);
      }

      // Draw day labels based on zoom
      bool showLabel;
      switch (zoom) {
        case TimelineZoom.day:
          showLabel = true;
        case TimelineZoom.week:
          showLabel = date.weekday == DateTime.monday || isToday;
        case TimelineZoom.month:
          showLabel = date.day == 1 || date.day == 15;
      }

      if (showLabel) {
        final dayLabel = isToday
            ? 'Today'
            : DateFormat.MMMd().format(date);
        _drawText(
          canvas,
          dayLabel,
          Offset(x + 2, 24),
          isToday ? todayStyle : labelStyle,
        );
      }

      // Highlight today
      if (isToday) {
        final todayPaint = Paint()
          ..color = theme.colorScheme.primary.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTWH(x, 0, ppd, size.height),
          todayPaint,
        );
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _HeaderPainter old) {
    return old.rangeStart != rangeStart ||
        old.totalDays != totalDays ||
        old.ppd != ppd ||
        old.zoom != zoom;
  }
}

class _TimelineBody extends ConsumerWidget {
  final ScrollController horizontalController;
  final ScrollController verticalController;
  final List<Task> tasks;
  final DateTime rangeStart;
  final int totalDays;
  final double totalWidth;
  final double ppd;
  final double rowHeight;
  final DateTime today;
  final List<dynamic> lists;

  const _TimelineBody({
    required this.horizontalController,
    required this.verticalController,
    required this.tasks,
    required this.rangeStart,
    required this.totalDays,
    required this.totalWidth,
    required this.ppd,
    required this.rowHeight,
    required this.today,
    required this.lists,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    // Build dependency index for arrow drawing
    final taskIndex = <String, int>{};
    for (int i = 0; i < tasks.length; i++) {
      taskIndex[tasks[i].id] = i;
    }

    return SingleChildScrollView(
      controller: horizontalController,
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalWidth,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // Sync vertical scroll with label panel
            if (notification is ScrollUpdateNotification) {
              if (verticalController.hasClients) {
                verticalController
                    .jumpTo(notification.metrics.pixels);
              }
            }
            return false;
          },
          child: Stack(
            children: [
              // Grid background + task bars
              ListView.builder(
                itemCount: tasks.length,
                itemExtent: rowHeight,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return _TimelineRow(
                    task: task,
                    rangeStart: rangeStart,
                    totalDays: totalDays,
                    totalWidth: totalWidth,
                    ppd: ppd,
                    rowHeight: rowHeight,
                    today: today,
                    lists: lists,
                    user: user,
                    theme: theme,
                  );
                },
              ),
              // Today indicator line
              Positioned(
                left: today.difference(rangeStart).inDays * ppd,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
              // Dependency arrows
              CustomPaint(
                size: Size(totalWidth, tasks.length * rowHeight),
                painter: _DependencyPainter(
                  tasks: tasks,
                  taskIndex: taskIndex,
                  rangeStart: rangeStart,
                  ppd: ppd,
                  rowHeight: rowHeight,
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineRow extends ConsumerWidget {
  final Task task;
  final DateTime rangeStart;
  final int totalDays;
  final double totalWidth;
  final double ppd;
  final double rowHeight;
  final DateTime today;
  final List<dynamic> lists;
  final dynamic user;
  final ThemeData theme;

  const _TimelineRow({
    required this.task,
    required this.rangeStart,
    required this.totalDays,
    required this.totalWidth,
    required this.ppd,
    required this.rowHeight,
    required this.today,
    required this.lists,
    required this.user,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskStart = task.startDate ?? task.dueDate!;
    final taskEnd = _taskEndDate(task);

    final startOffset =
        taskStart.difference(rangeStart).inHours / 24.0 * ppd;
    final barWidth = max(
      ppd * 0.5, // minimum width: half a day
      taskEnd.difference(taskStart).inHours / 24.0 * ppd,
    );

    final listColor = _getListColor(task);
    final barColor = task.isCompleted
        ? theme.colorScheme.outline.withValues(alpha: 0.3)
        : listColor;

    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Stack(
        children: [
          // Grid lines for each day
          ...List.generate(totalDays, (i) {
            final date = rangeStart.add(Duration(days: i));
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
            return Positioned(
              left: i * ppd,
              top: 0,
              bottom: 0,
              child: Container(
                width: isToday ? ppd : 0.5,
                color: isToday
                    ? theme.colorScheme.primary.withValues(alpha: 0.04)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            );
          }),
          // Task bar
          Positioned(
            left: startOffset,
            top: 6,
            child: _DraggableTaskBar(
              task: task,
              barWidth: barWidth,
              barColor: barColor,
              rowHeight: rowHeight,
              ppd: ppd,
              rangeStart: rangeStart,
            ),
          ),
        ],
      ),
    );
  }

  DateTime _taskEndDate(Task task) {
    final start = task.startDate ?? task.dueDate!;
    if (task.dueDate != null && task.startDate != null) {
      return task.dueDate!;
    }
    if (task.duration != null && task.duration! > 0) {
      return start.add(Duration(minutes: task.duration!));
    }
    // Default: 1 day duration
    return start.add(const Duration(days: 1));
  }

  Color _getListColor(Task task) {
    try {
      final list = lists.firstWhere((l) => l.id == task.listId);
      return Color(list.colorValue);
    } catch (_) {
      return theme.colorScheme.primary;
    }
  }
}

class _DraggableTaskBar extends ConsumerStatefulWidget {
  final Task task;
  final double barWidth;
  final Color barColor;
  final double rowHeight;
  final double ppd;
  final DateTime rangeStart;

  const _DraggableTaskBar({
    required this.task,
    required this.barWidth,
    required this.barColor,
    required this.rowHeight,
    required this.ppd,
    required this.rangeStart,
  });

  @override
  ConsumerState<_DraggableTaskBar> createState() => _DraggableTaskBarState();
}

class _DraggableTaskBarState extends ConsumerState<_DraggableTaskBar> {
  double _dragDeltaX = 0;
  bool _isDragging = false;
  double _resizeDelta = 0;
  bool _isResizing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final currentWidth = widget.barWidth + _resizeDelta;
    final effectiveWidth = max(widget.ppd * 0.5, currentWidth);

    return Transform.translate(
      offset: Offset(_dragDeltaX, 0),
      child: SizedBox(
        width: effectiveWidth,
        height: widget.rowHeight - 12,
        child: Stack(
          children: [
            // Main bar — draggable to move start date
            GestureDetector(
              onHorizontalDragStart: (_) {
                setState(() {
                  _isDragging = true;
                  _dragDeltaX = 0;
                });
              },
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragDeltaX += details.delta.dx;
                });
              },
              onHorizontalDragEnd: (_) {
                if (user == null) return;
                final daysDelta = (_dragDeltaX / widget.ppd).round();
                if (daysDelta != 0) {
                  final task = widget.task;
                  final newStart = (task.startDate ?? task.dueDate!)
                      .add(Duration(days: daysDelta));
                  final newDue = task.dueDate?.add(Duration(days: daysDelta));
                  ref.read(firestoreServiceProvider).updateTask(
                        user.uid,
                        task.copyWith(
                          startDate: newStart,
                          dueDate: newDue,
                          updatedAt: DateTime.now(),
                        ),
                      );
                }
                setState(() {
                  _isDragging = false;
                  _dragDeltaX = 0;
                });
              },
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        TaskDetailScreen(taskId: widget.task.id)),
              ),
              child: AnimatedContainer(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: widget.barColor.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                  border: _isDragging || _isResizing
                      ? Border.all(
                          color: theme.colorScheme.primary, width: 1.5)
                      : null,
                  boxShadow: _isDragging
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.task.title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _contrastColor(widget.barColor),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Right edge resize handle
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onHorizontalDragStart: (_) {
                  setState(() {
                    _isResizing = true;
                    _resizeDelta = 0;
                  });
                },
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _resizeDelta += details.delta.dx;
                  });
                },
                onHorizontalDragEnd: (_) {
                  if (user == null) return;
                  final daysDelta = (_resizeDelta / widget.ppd).round();
                  if (daysDelta != 0) {
                    final task = widget.task;
                    final start = task.startDate ?? task.dueDate!;
                    final currentEnd = task.dueDate ?? start.add(const Duration(days: 1));
                    final newEnd = currentEnd.add(Duration(days: daysDelta));
                    // Don't allow end before start
                    if (newEnd.isAfter(start)) {
                      ref.read(firestoreServiceProvider).updateTask(
                            user.uid,
                            task.copyWith(
                              dueDate: newEnd,
                              updatedAt: DateTime.now(),
                            ),
                          );
                    }
                  }
                  setState(() {
                    _isResizing = false;
                    _resizeDelta = 0;
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: Container(
                    width: 8,
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _contrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}

class _DependencyPainter extends CustomPainter {
  final List<Task> tasks;
  final Map<String, int> taskIndex;
  final DateTime rangeStart;
  final double ppd;
  final double rowHeight;
  final Color color;

  _DependencyPainter({
    required this.tasks,
    required this.taskIndex,
    required this.rangeStart,
    required this.ppd,
    required this.rowHeight,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      for (final depId in task.dependsOn) {
        final depIndex = taskIndex[depId];
        if (depIndex == null) continue;

        final depTask = tasks[depIndex];
        final depEnd = _taskEndX(depTask);
        final taskStartX = _taskStartX(task);

        final fromY = depIndex * rowHeight + rowHeight / 2;
        final toY = i * rowHeight + rowHeight / 2;

        // Draw path: horizontal from dep end, then vertical, then horizontal to task start
        final path = Path();
        path.moveTo(depEnd, fromY);

        final midX = (depEnd + taskStartX) / 2;
        path.lineTo(midX, fromY);
        path.lineTo(midX, toY);
        path.lineTo(taskStartX, toY);

        canvas.drawPath(path, paint);

        // Arrow head
        final arrowPath = Path();
        arrowPath.moveTo(taskStartX, toY);
        arrowPath.lineTo(taskStartX - 6, toY - 3);
        arrowPath.lineTo(taskStartX - 6, toY + 3);
        arrowPath.close();
        canvas.drawPath(arrowPath, arrowPaint);
      }
    }
  }

  double _taskStartX(Task task) {
    final start = task.startDate ?? task.dueDate!;
    return start.difference(rangeStart).inHours / 24.0 * ppd;
  }

  double _taskEndX(Task task) {
    final start = task.startDate ?? task.dueDate!;
    DateTime end;
    if (task.dueDate != null && task.startDate != null) {
      end = task.dueDate!;
    } else if (task.duration != null && task.duration! > 0) {
      end = start.add(Duration(minutes: task.duration!));
    } else {
      end = start.add(const Duration(days: 1));
    }
    return end.difference(rangeStart).inHours / 24.0 * ppd;
  }

  @override
  bool shouldRepaint(covariant _DependencyPainter old) => true;
}
