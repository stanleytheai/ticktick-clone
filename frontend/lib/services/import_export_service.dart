import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/models/task_list.dart';

enum ImportSource { todoist, microsoftTodo, appleReminders }

enum ExportFormat { csv, json, text }

class ImportResult {
  final int tasksImported;
  final int listsCreated;
  final List<String> errors;

  const ImportResult({
    required this.tasksImported,
    required this.listsCreated,
    this.errors = const [],
  });
}

class ImportExportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tasksRef(String userId) =>
      _db.collection('users').doc(userId).collection('tasks');

  CollectionReference<Map<String, dynamic>> _listsRef(String userId) =>
      _db.collection('users').doc(userId).collection('lists');

  // ---- IMPORT ----

  Future<ImportResult> importData(
      String userId, ImportSource source, String data) async {
    final parsed = _parseImportData(source, data);
    if (parsed.tasks.isEmpty) {
      return ImportResult(
        tasksImported: 0,
        listsCreated: 0,
        errors: parsed.errors.isEmpty
            ? ['No tasks found in import data']
            : parsed.errors,
      );
    }

    // Get existing lists
    final existingSnap = await _listsRef(userId).get();
    final existingLists = <String, String>{};
    for (final doc in existingSnap.docs) {
      existingLists[(doc.data()['name'] as String).toLowerCase()] = doc.id;
    }

    final batch = _db.batch();
    final listIdMap = <String, String>{};
    int listsCreated = 0;

    // Create missing lists
    for (final listName in parsed.listNames) {
      final key = listName.toLowerCase();
      if (existingLists.containsKey(key)) {
        listIdMap[listName] = existingLists[key]!;
      } else {
        final ref = _listsRef(userId).doc();
        batch.set(ref, {
          'name': listName,
          'colorValue': 0xFF2196F3,
          'userId': userId,
          'sortOrder': existingSnap.size + listsCreated,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
        listIdMap[listName] = ref.id;
        listsCreated++;
      }
    }

    // Create tasks
    int taskCount = 0;
    for (final task in parsed.tasks) {
      final ref = _tasksRef(userId).doc();
      final now = DateTime.now();
      batch.set(ref, {
        'title': task.title,
        'description': task.description ?? '',
        'listId': task.listName != null
            ? (listIdMap[task.listName] ?? '')
            : 'inbox',
        'dueDate': task.dueDate != null ? Timestamp.fromDate(task.dueDate!) : null,
        'priority': task.priority.value,
        'tags': <String>[],
        'subtasks': <Map<String, dynamic>>[],
        'isCompleted': task.isCompleted,
        'completedAt': task.isCompleted ? Timestamp.fromDate(now) : null,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'userId': userId,
        'sortOrder': taskCount,
      });
      taskCount++;
    }

    await batch.commit();
    return ImportResult(
      tasksImported: taskCount,
      listsCreated: listsCreated,
      errors: parsed.errors,
    );
  }

  // ---- EXPORT ----

  Future<String> exportData(
    String userId,
    ExportFormat format, {
    List<String>? listIds,
    bool includeCompleted = true,
  }) async {
    // Fetch tasks
    final tasksSnap = await _tasksRef(userId).get();
    var tasks = tasksSnap.docs.map((d) => Task.fromMap(d.id, d.data())).toList();

    if (!includeCompleted) {
      tasks = tasks.where((t) => !t.isCompleted).toList();
    }
    if (listIds != null && listIds.isNotEmpty) {
      final idSet = listIds.toSet();
      tasks = tasks.where((t) => idSet.contains(t.listId)).toList();
    }

    // Fetch lists
    final listsSnap = await _listsRef(userId).get();
    final lists =
        listsSnap.docs.map((d) => TaskList.fromMap(d.id, d.data())).toList();

    switch (format) {
      case ExportFormat.csv:
        return _exportCsv(tasks, lists);
      case ExportFormat.json:
        return _exportJson(tasks, lists);
      case ExportFormat.text:
        return _exportText(tasks, lists);
    }
  }

  String _exportCsv(List<Task> tasks, List<TaskList> lists) {
    final listMap = {for (final l in lists) l.id: l.name};
    final rows = <String>[
      'Title,Description,Due Date,Priority,List,Completed,Created'
    ];
    for (final t in tasks) {
      rows.add([
        _csvEscape(t.title),
        _csvEscape(t.description),
        t.dueDate?.toIso8601String() ?? '',
        t.priority.label,
        _csvEscape(listMap[t.listId] ?? ''),
        t.isCompleted ? 'Yes' : 'No',
        t.createdAt.toIso8601String(),
      ].join(','));
    }
    return rows.join('\n');
  }

  String _exportJson(List<Task> tasks, List<TaskList> lists) {
    return const JsonEncoder.withIndent('  ').convert({
      'exportedAt': DateTime.now().toIso8601String(),
      'version': '1.0',
      'lists': lists.map((l) => {'id': l.id, 'name': l.name}).toList(),
      'tasks': tasks
          .map((t) => {
                'id': t.id,
                'title': t.title,
                'description': t.description,
                'listId': t.listId,
                'dueDate': t.dueDate?.toIso8601String(),
                'priority': t.priority.label,
                'isCompleted': t.isCompleted,
                'createdAt': t.createdAt.toIso8601String(),
              })
          .toList(),
    });
  }

  String _exportText(List<Task> tasks, List<TaskList> lists) {
    final listMap = {for (final l in lists) l.id: l.name};
    final grouped = <String, List<Task>>{};
    for (final t in tasks) {
      final name = listMap[t.listId] ?? 'Inbox';
      grouped.putIfAbsent(name, () => []).add(t);
    }

    final buf = StringBuffer();
    for (final entry in grouped.entries) {
      buf.writeln('${entry.key}:');
      for (final t in entry.value) {
        final check = t.isCompleted ? '[x]' : '[ ]';
        final due = t.dueDate != null
            ? ' (due: ${t.dueDate!.toIso8601String().split('T')[0]})'
            : '';
        buf.writeln('  $check ${t.title}$due');
      }
      buf.writeln();
    }
    return buf.toString();
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ---- PARSING ----

  _ParsedImport _parseImportData(ImportSource source, String data) {
    switch (source) {
      case ImportSource.todoist:
        return _parseTodoistCsv(data);
      case ImportSource.microsoftTodo:
        return _parseMicrosoftTodo(data);
      case ImportSource.appleReminders:
        return _parseAppleReminders(data);
    }
  }

  _ParsedImport _parseTodoistCsv(String data) {
    final lines = data.split('\n');
    if (lines.length < 2) {
      return _ParsedImport(tasks: [], listNames: [], errors: ['Empty CSV']);
    }

    final headers = _parseCsvLine(lines[0]);
    final headerMap = <String, int>{};
    for (int i = 0; i < headers.length; i++) {
      headerMap[headers[i].toLowerCase().trim()] = i;
    }

    final tasks = <_ParsedTask>[];
    final listNames = <String>{};
    final errors = <String>[];

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final cols = _parseCsvLine(line);
        String? get(String name) {
          final idx = headerMap[name];
          return idx != null && idx < cols.length ? cols[idx].trim() : null;
        }

        final title =
            get('content') ?? get('task name') ?? get('title') ?? '';
        if (title.isEmpty) continue;

        final priorityRaw = get('priority');
        final priority = _mapTodoistPriority(priorityRaw);
        final dueDateStr = get('due date') ?? get('date');
        final listName = get('project') ?? get('list');
        final status = get('status') ?? get('completed');
        final completed =
            status == 'completed' || status == 'true' || status == '1';

        if (listName != null && listName.isNotEmpty) listNames.add(listName);

        tasks.add(_ParsedTask(
          title: title,
          description: get('description') ?? get('notes'),
          dueDate: dueDateStr != null ? DateTime.tryParse(dueDateStr) : null,
          priority: priority,
          listName: listName,
          isCompleted: completed,
        ));
      } catch (_) {
        errors.add('Line ${i + 1}: parse error');
      }
    }

    return _ParsedImport(
        tasks: tasks, listNames: listNames.toList(), errors: errors);
  }

  _ParsedImport _parseMicrosoftTodo(String data) {
    // Try JSON first
    try {
      final json = jsonDecode(data);
      return _parseMicrosoftTodoJson(json);
    } catch (_) {
      return _parseMicrosoftTodoText(data);
    }
  }

  _ParsedImport _parseMicrosoftTodoJson(dynamic json) {
    final tasks = <_ParsedTask>[];
    final listNames = <String>{};

    List items;
    if (json is List) {
      items = json;
    } else if (json is Map) {
      items = (json['value'] ?? json['tasks'] ?? json['items'] ?? []) as List;
    } else {
      return _ParsedImport(
          tasks: [], listNames: [], errors: ['Invalid JSON structure']);
    }

    for (final item in items) {
      if (item is! Map) continue;
      final title = (item['title'] ?? item['subject'] ?? '') as String;
      if (title.isEmpty) continue;

      final parentList = item['parentList'] as Map?;
      final listName = parentList?['displayName'] as String?;
      if (listName != null) listNames.add(listName);

      final completed =
          item['status'] == 'completed' || item['isCompleted'] == true;

      final dueDateTime = item['dueDateTime'] as Map?;
      final dueDateStr =
          dueDateTime?['dateTime'] as String? ?? item['dueDate'] as String?;

      final importance = item['importance'] as String?;
      TaskPriority priority;
      if (importance == 'high') {
        priority = TaskPriority.high;
      } else if (importance == 'normal') {
        priority = TaskPriority.medium;
      } else if (importance == 'low') {
        priority = TaskPriority.low;
      } else {
        priority = TaskPriority.none;
      }

      final body = item['body'] as Map?;
      final description =
          body?['content'] as String? ?? item['note'] as String?;

      tasks.add(_ParsedTask(
        title: title,
        description: description,
        dueDate: dueDateStr != null ? DateTime.tryParse(dueDateStr) : null,
        priority: priority,
        listName: listName,
        isCompleted: completed,
      ));
    }

    return _ParsedImport(
        tasks: tasks, listNames: listNames.toList(), errors: []);
  }

  _ParsedImport _parseMicrosoftTodoText(String data) {
    final tasks = <_ParsedTask>[];
    final listNames = <String>{};
    String? currentList;

    for (final line in data.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.endsWith(':') &&
          !trimmed.startsWith('-') &&
          !trimmed.startsWith('[')) {
        currentList = trimmed.substring(0, trimmed.length - 1).trim();
        if (currentList.isNotEmpty) listNames.add(currentList);
        continue;
      }

      final taskMatch =
          RegExp(r'^[-*]?\s*\[([xX ])\]\s*(.+)$').firstMatch(trimmed);
      if (taskMatch != null) {
        final completed =
            taskMatch.group(1) == 'x' || taskMatch.group(1) == 'X';
        final title = taskMatch.group(2)?.trim() ?? '';
        if (title.isNotEmpty) {
          tasks.add(_ParsedTask(
            title: title,
            listName: currentList,
            isCompleted: completed,
          ));
        }
      } else {
        tasks.add(_ParsedTask(title: trimmed, listName: currentList));
      }
    }

    return _ParsedImport(
        tasks: tasks, listNames: listNames.toList(), errors: []);
  }

  _ParsedImport _parseAppleReminders(String data) {
    final tasks = <_ParsedTask>[];
    final listNames = <String>{};
    final errors = <String>[];

    final blocks = data.split('BEGIN:VTODO');
    for (int i = 1; i < blocks.length; i++) {
      final block = blocks[i].split('END:VTODO')[0];
      try {
        final title = _extractIcsField(block, 'SUMMARY');
        if (title == null) continue;

        final description = _extractIcsField(block, 'DESCRIPTION');
        final due = _extractIcsField(block, 'DUE');
        final status = _extractIcsField(block, 'STATUS');
        final completed = status == 'COMPLETED';
        final priorityRaw = _extractIcsField(block, 'PRIORITY');
        final listName = _extractIcsField(block, 'X-APPLE-CALENDAR');

        if (listName != null) listNames.add(listName);

        TaskPriority priority = TaskPriority.none;
        if (priorityRaw != null) {
          final p = int.tryParse(priorityRaw) ?? 0;
          if (p >= 1 && p <= 4) {
            priority = TaskPriority.high;
          } else if (p == 5) {
            priority = TaskPriority.medium;
          } else if (p >= 6 && p <= 9) {
            priority = TaskPriority.low;
          }
        }

        tasks.add(_ParsedTask(
          title: title,
          description: description?.replaceAll('\\n', '\n'),
          dueDate: due != null ? _parseIcsDate(due) : null,
          priority: priority,
          listName: listName,
          isCompleted: completed,
        ));
      } catch (_) {
        errors.add('VTODO block $i: parse error');
      }
    }

    return _ParsedImport(
        tasks: tasks, listNames: listNames.toList(), errors: errors);
  }

  // Utility methods

  TaskPriority _mapTodoistPriority(String? raw) {
    if (raw == null) return TaskPriority.none;
    final p = raw.toLowerCase().trim();
    if (p == '1' || p == 'p1') return TaskPriority.high;
    if (p == '2' || p == 'p2') return TaskPriority.medium;
    if (p == '3' || p == 'p3') return TaskPriority.low;
    return TaskPriority.none;
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            current.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          current.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          result.add(current.toString());
          current = StringBuffer();
        } else {
          current.write(ch);
        }
      }
    }
    result.add(current.toString());
    return result;
  }

  String? _extractIcsField(String block, String field) {
    final unfolded = block.replaceAll(RegExp(r'\r?\n[ \t]'), '');
    final match =
        RegExp('^$field(?:;[^:]*)?:(.*)' '\$', multiLine: true)
            .firstMatch(unfolded);
    return match?.group(1)?.trim();
  }

  DateTime? _parseIcsDate(String value) {
    final clean = value.replaceAll(RegExp(r'^VALUE=DATE(-TIME)?:'), '');
    try {
      if (clean.length == 8) {
        return DateTime.parse(
            '${clean.substring(0, 4)}-${clean.substring(4, 6)}-${clean.substring(6, 8)}');
      }
      final y = clean.substring(0, 4);
      final m = clean.substring(4, 6);
      final d = clean.substring(6, 8);
      final h = clean.length > 9 ? clean.substring(9, 11) : '00';
      final mi = clean.length > 11 ? clean.substring(11, 13) : '00';
      final s = clean.length > 13 ? clean.substring(13, 15) : '00';
      return DateTime.parse('$y-$m-${d}T$h:$mi:${s}Z');
    } catch (_) {
      return null;
    }
  }
}

class _ParsedTask {
  final String title;
  final String? description;
  final DateTime? dueDate;
  final TaskPriority priority;
  final String? listName;
  final bool isCompleted;

  const _ParsedTask({
    required this.title,
    this.description,
    this.dueDate,
    this.priority = TaskPriority.none,
    this.listName,
    this.isCompleted = false,
  });
}

class _ParsedImport {
  final List<_ParsedTask> tasks;
  final List<String> listNames;
  final List<String> errors;

  const _ParsedImport({
    required this.tasks,
    required this.listNames,
    required this.errors,
  });
}
