import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  reminder('reminder'),
  sharedList('shared_list'),
  comment('comment'),
  assignment('assignment'),
  system('system');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromValue(String value) {
    return NotificationType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => NotificationType.system,
    );
  }
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String? taskId;
  final String? listId;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.taskId,
    this.listId,
    this.read = false,
    required this.createdAt,
  });

  AppNotification copyWith({
    bool? read,
  }) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      taskId: taskId,
      listId: listId,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'title': title,
      'body': body,
      if (taskId != null) 'taskId': taskId,
      if (listId != null) 'listId': listId,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      type: NotificationType.fromValue(map['type'] as String? ?? 'system'),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      taskId: map['taskId'] as String?,
      listId: map['listId'] as String?,
      read: map['read'] as bool? ?? false,
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
