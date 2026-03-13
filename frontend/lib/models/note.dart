import 'package:cloud_firestore/cloud_firestore.dart';

class NoteFolder {
  final String id;
  final String name;
  final int? colorValue;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteFolder({
    required this.id,
    required this.name,
    this.colorValue,
    this.sortOrder = 0,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  NoteFolder copyWith({
    String? id,
    String? name,
    int? colorValue,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'colorValue': colorValue,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory NoteFolder.fromMap(String id, Map<String, dynamic> map) {
    return NoteFolder(
      id: id,
      name: map['name'] as String? ?? '',
      colorValue: map['colorValue'] as int?,
      sortOrder: map['sortOrder'] as int? ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class Note {
  final String id;
  final String title;
  final String content;
  final String? folderId;
  final int sortOrder;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.title,
    this.content = '',
    this.folderId,
    this.sortOrder = 0,
    required this.userId,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? folderId,
    bool clearFolder = false,
    int? sortOrder,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      sortOrder: sortOrder ?? this.sortOrder,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'folderId': folderId,
      'sortOrder': sortOrder,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Note.fromMap(String id, Map<String, dynamic> map) {
    return Note(
      id: id,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      folderId: map['folderId'] as String?,
      sortOrder: map['sortOrder'] as int? ?? 0,
      userId: map['userId'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
