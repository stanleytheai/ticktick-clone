class Subtask {
  final String id;
  final String title;
  final bool isCompleted;
  final int sortOrder;

  const Subtask({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.sortOrder = 0,
  });

  Subtask copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    int? sortOrder,
  }) {
    return Subtask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'sortOrder': sortOrder,
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }
}
