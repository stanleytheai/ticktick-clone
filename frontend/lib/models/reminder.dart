import 'package:cloud_firestore/cloud_firestore.dart';

enum ReminderType {
  atTime('at_time', 'At due time'),
  minutesBefore('minutes_before', 'minutes before'),
  hoursBefore('hours_before', 'hours before'),
  daysBefore('days_before', 'days before');

  const ReminderType(this.value, this.label);
  final String value;
  final String label;

  static ReminderType fromValue(String value) {
    return ReminderType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => ReminderType.atTime,
    );
  }
}

class Reminder {
  final String id;
  final ReminderType type;
  final int value;
  final DateTime? triggerAt;
  final DateTime? snoozedUntil;
  final bool dismissed;

  const Reminder({
    required this.id,
    required this.type,
    this.value = 0,
    this.triggerAt,
    this.snoozedUntil,
    this.dismissed = false,
  });

  Reminder copyWith({
    String? id,
    ReminderType? type,
    int? value,
    DateTime? triggerAt,
    bool clearTriggerAt = false,
    DateTime? snoozedUntil,
    bool clearSnoozedUntil = false,
    bool? dismissed,
  }) {
    return Reminder(
      id: id ?? this.id,
      type: type ?? this.type,
      value: value ?? this.value,
      triggerAt: clearTriggerAt ? null : (triggerAt ?? this.triggerAt),
      snoozedUntil:
          clearSnoozedUntil ? null : (snoozedUntil ?? this.snoozedUntil),
      dismissed: dismissed ?? this.dismissed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.value,
      'value': value,
      if (triggerAt != null) 'triggerAt': Timestamp.fromDate(triggerAt!),
      if (snoozedUntil != null)
        'snoozedUntil': Timestamp.fromDate(snoozedUntil!),
      'dismissed': dismissed,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as String? ?? '',
      type: ReminderType.fromValue(map['type'] as String? ?? 'at_time'),
      value: map['value'] as int? ?? 0,
      triggerAt: (map['triggerAt'] as Timestamp?)?.toDate(),
      snoozedUntil: (map['snoozedUntil'] as Timestamp?)?.toDate(),
      dismissed: map['dismissed'] as bool? ?? false,
    );
  }

  String get displayLabel {
    switch (type) {
      case ReminderType.atTime:
        return 'At due time';
      case ReminderType.minutesBefore:
        return '$value minute${value != 1 ? "s" : ""} before';
      case ReminderType.hoursBefore:
        return '$value hour${value != 1 ? "s" : ""} before';
      case ReminderType.daysBefore:
        return '$value day${value != 1 ? "s" : ""} before';
    }
  }
}
