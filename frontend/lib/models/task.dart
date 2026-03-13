import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ticktick_clone/models/subtask.dart';

enum TaskPriority {
  none(0, 'None', 0x00000000),
  low(1, 'Low', 0xFF4CAF50),
  medium(2, 'Medium', 0xFFFF9800),
  high(3, 'High', 0xFFF44336);

  const TaskPriority(this.value, this.label, this.colorValue);
  final int value;
  final String label;
  final int colorValue;

  static TaskPriority fromValue(int value) {
    return TaskPriority.values.firstWhere(
      (p) => p.value == value,
      orElse: () => TaskPriority.none,
    );
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final String listId;
  final DateTime? dueDate;
  final TaskPriority priority;
  final List<String> tags;
  final List<Subtask> subtasks;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;
  final int sortOrder;

  const Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.listId,
    this.dueDate,
    this.priority = TaskPriority.none,
    this.tags = const [],
    this.subtasks = const [],
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    this.sortOrder = 0,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? listId,
    DateTime? dueDate,
    bool clearDueDate = false,
    TaskPriority? priority,
    List<String>? tags,
    List<Subtask>? subtasks,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    int? sortOrder,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      listId: listId ?? this.listId,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      subtasks: subtasks ?? this.subtasks,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'listId': listId,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'priority': priority.value,
      'tags': tags,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'userId': userId,
      'sortOrder': sortOrder,
    };
  }

  factory Task.fromMap(String id, Map<String, dynamic> map) {
    return Task(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      listId: map['listId'] as String? ?? '',
      dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
      priority: TaskPriority.fromValue(map['priority'] as int? ?? 0),
      tags: List<String>.from(map['tags'] as List? ?? []),
      subtasks: (map['subtasks'] as List? ?? [])
          .map((s) => Subtask.fromMap(s as Map<String, dynamic>))
          .toList(),
      isCompleted: map['isCompleted'] as bool? ?? false,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: map['userId'] as String? ?? '',
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }
}
