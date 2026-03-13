import 'package:cloud_firestore/cloud_firestore.dart';

class FocusSession {
  final String id;
  final String? taskId;
  final String? listId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final String userId;

  const FocusSession({
    required this.id,
    this.taskId,
    this.listId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'listId': listId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationMinutes': durationMinutes,
      'userId': userId,
    };
  }

  factory FocusSession.fromMap(String id, Map<String, dynamic> map) {
    return FocusSession(
      id: id,
      taskId: map['taskId'] as String?,
      listId: map['listId'] as String?,
      startTime: (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (map['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: map['durationMinutes'] as int? ?? 0,
      userId: map['userId'] as String? ?? '',
    );
  }
}
