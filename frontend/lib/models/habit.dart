import 'package:cloud_firestore/cloud_firestore.dart';

enum HabitFrequency {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly');

  const HabitFrequency(this.label);
  final String label;

  static HabitFrequency fromString(String value) {
    return HabitFrequency.values.firstWhere(
      (f) => f.name == value,
      orElse: () => HabitFrequency.daily,
    );
  }
}

enum HabitGoalType {
  yesNo('Yes / No', 'yes_no'),
  count('Count', 'count');

  const HabitGoalType(this.label, this.value);
  final String label;
  final String value;

  static HabitGoalType fromString(String value) {
    return HabitGoalType.values.firstWhere(
      (g) => g.value == value || g.name == value,
      orElse: () => HabitGoalType.yesNo,
    );
  }
}

enum HabitSection {
  morning('Morning', 0),
  afternoon('Afternoon', 1),
  evening('Evening', 2),
  anytime('Anytime', 3);

  const HabitSection(this.label, this.sortValue);
  final String label;
  final int sortValue;

  static HabitSection fromString(String value) {
    return HabitSection.values.firstWhere(
      (s) => s.name == value,
      orElse: () => HabitSection.anytime,
    );
  }
}

class Habit {
  final String id;
  final String name;
  final String? icon;
  final HabitFrequency frequency;
  final List<int> frequencyDays;
  final int? frequencyCount;
  final HabitGoalType goalType;
  final int? goalCount;
  final String? reminderTime;
  final HabitSection section;
  final int sortOrder;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Habit({
    required this.id,
    required this.name,
    this.icon,
    this.frequency = HabitFrequency.daily,
    this.frequencyDays = const [],
    this.frequencyCount,
    this.goalType = HabitGoalType.yesNo,
    this.goalCount,
    this.reminderTime,
    this.section = HabitSection.anytime,
    this.sortOrder = 0,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Habit copyWith({
    String? id,
    String? name,
    String? icon,
    bool clearIcon = false,
    HabitFrequency? frequency,
    List<int>? frequencyDays,
    int? frequencyCount,
    bool clearFrequencyCount = false,
    HabitGoalType? goalType,
    int? goalCount,
    bool clearGoalCount = false,
    String? reminderTime,
    bool clearReminderTime = false,
    HabitSection? section,
    int? sortOrder,
    bool? archived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: clearIcon ? null : (icon ?? this.icon),
      frequency: frequency ?? this.frequency,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      frequencyCount: clearFrequencyCount ? null : (frequencyCount ?? this.frequencyCount),
      goalType: goalType ?? this.goalType,
      goalCount: clearGoalCount ? null : (goalCount ?? this.goalCount),
      reminderTime: clearReminderTime ? null : (reminderTime ?? this.reminderTime),
      section: section ?? this.section,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'frequency': frequency.name,
      'frequencyDays': frequencyDays,
      'frequencyCount': frequencyCount,
      'goalType': goalType.value,
      'goalCount': goalCount,
      'reminderTime': reminderTime,
      'section': section.name,
      'sortOrder': sortOrder,
      'archived': archived,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Habit.fromMap(String id, Map<String, dynamic> map) {
    return Habit(
      id: id,
      name: map['name'] as String? ?? '',
      icon: map['icon'] as String?,
      frequency: HabitFrequency.fromString(map['frequency'] as String? ?? 'daily'),
      frequencyDays: List<int>.from(map['frequencyDays'] as List? ?? []),
      frequencyCount: map['frequencyCount'] as int?,
      goalType: HabitGoalType.fromString(map['goalType'] as String? ?? 'yes_no'),
      goalCount: map['goalCount'] as int?,
      reminderTime: map['reminderTime'] as String?,
      section: HabitSection.fromString(map['section'] as String? ?? 'anytime'),
      sortOrder: map['sortOrder'] as int? ?? 0,
      archived: map['archived'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class HabitLog {
  final String id;
  final String date;
  final int value;
  final bool skipped;
  final DateTime createdAt;

  const HabitLog({
    required this.id,
    required this.date,
    this.value = 1,
    this.skipped = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'value': value,
      'skipped': skipped,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory HabitLog.fromMap(String id, Map<String, dynamic> map) {
    return HabitLog(
      id: id,
      date: map['date'] as String? ?? '',
      value: map['value'] as int? ?? 1,
      skipped: map['skipped'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
