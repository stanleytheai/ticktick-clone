import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityEntry {
  final String id;
  final String type;
  final String actorId;
  final String actorName;
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const ActivityEntry({
    required this.id,
    required this.type,
    required this.actorId,
    this.actorName = '',
    required this.description,
    this.metadata,
    required this.createdAt,
  });

  factory ActivityEntry.fromMap(String id, Map<String, dynamic> map) {
    return ActivityEntry(
      id: id,
      type: map['type'] as String? ?? '',
      actorId: map['actorId'] as String? ?? '',
      actorName: map['actorName'] as String? ?? '',
      description: map['description'] as String? ?? '',
      metadata: map['metadata'] as Map<String, dynamic>?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
