import 'package:cloud_firestore/cloud_firestore.dart';

class TaskList {
  final String id;
  final String name;
  final int colorValue;
  final String userId;
  final int sortOrder;
  final DateTime createdAt;

  const TaskList({
    required this.id,
    required this.name,
    this.colorValue = 0xFF2196F3,
    required this.userId,
    this.sortOrder = 0,
    required this.createdAt,
  });

  TaskList copyWith({
    String? id,
    String? name,
    int? colorValue,
    String? userId,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return TaskList(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      userId: userId ?? this.userId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'colorValue': colorValue,
      'userId': userId,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TaskList.fromMap(String id, Map<String, dynamic> map) {
    return TaskList(
      id: id,
      name: map['name'] as String? ?? '',
      colorValue: map['colorValue'] as int? ?? 0xFF2196F3,
      userId: map['userId'] as String? ?? '',
      sortOrder: map['sortOrder'] as int? ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
