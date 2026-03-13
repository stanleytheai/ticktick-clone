class Tag {
  final String id;
  final String name;
  final int colorValue;
  final String userId;

  const Tag({
    required this.id,
    required this.name,
    this.colorValue = 0xFF9E9E9E,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'colorValue': colorValue,
      'userId': userId,
    };
  }

  factory Tag.fromMap(String id, Map<String, dynamic> map) {
    return Tag(
      id: id,
      name: map['name'] as String? ?? '',
      colorValue: map['colorValue'] as int? ?? 0xFF9E9E9E,
      userId: map['userId'] as String? ?? '',
    );
  }
}
