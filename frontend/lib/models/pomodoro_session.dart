import 'package:cloud_firestore/cloud_firestore.dart';

enum PomodoroSessionType {
  work('work', 'Work'),
  shortBreak('short_break', 'Short Break'),
  longBreak('long_break', 'Long Break');

  const PomodoroSessionType(this.value, this.label);
  final String value;
  final String label;

  static PomodoroSessionType fromValue(String value) {
    return PomodoroSessionType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => PomodoroSessionType.work,
    );
  }
}

enum AmbientSound {
  rain('rain', 'Rain'),
  forest('forest', 'Forest'),
  cafe('cafe', 'Cafe'),
  ocean('ocean', 'Ocean'),
  fireplace('fireplace', 'Fireplace');

  const AmbientSound(this.value, this.label);
  final String value;
  final String label;

  static AmbientSound fromValue(String value) {
    return AmbientSound.values.firstWhere(
      (s) => s.value == value,
      orElse: () => AmbientSound.rain,
    );
  }
}

class PomodoroSession {
  final String id;
  final String? taskId;
  final PomodoroSessionType sessionType;
  final int durationMinutes;
  final DateTime startTime;
  final DateTime? endTime;
  final bool completed;
  final List<String> ambientSounds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PomodoroSession({
    required this.id,
    this.taskId,
    this.sessionType = PomodoroSessionType.work,
    this.durationMinutes = 25,
    required this.startTime,
    this.endTime,
    this.completed = false,
    this.ambientSounds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  PomodoroSession copyWith({
    String? id,
    String? taskId,
    bool clearTaskId = false,
    PomodoroSessionType? sessionType,
    int? durationMinutes,
    DateTime? startTime,
    DateTime? endTime,
    bool setEndTime = false,
    bool? completed,
    List<String>? ambientSounds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PomodoroSession(
      id: id ?? this.id,
      taskId: clearTaskId ? null : (taskId ?? this.taskId),
      sessionType: sessionType ?? this.sessionType,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      startTime: startTime ?? this.startTime,
      endTime: setEndTime ? endTime : (endTime ?? this.endTime),
      completed: completed ?? this.completed,
      ambientSounds: ambientSounds ?? this.ambientSounds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'sessionType': sessionType.value,
      'durationMinutes': durationMinutes,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'completed': completed,
      'ambientSounds': ambientSounds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory PomodoroSession.fromMap(String id, Map<String, dynamic> map) {
    return PomodoroSession(
      id: id,
      taskId: map['taskId'] as String?,
      sessionType:
          PomodoroSessionType.fromValue(map['sessionType'] as String? ?? 'work'),
      durationMinutes: map['durationMinutes'] as int? ?? 25,
      startTime:
          (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (map['endTime'] as Timestamp?)?.toDate(),
      completed: map['completed'] as bool? ?? false,
      ambientSounds:
          List<String>.from(map['ambientSounds'] as List? ?? []),
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class PomodoroSettings {
  final int workMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int sessionsUntilLongBreak;
  final bool autoStartNext;

  const PomodoroSettings({
    this.workMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.sessionsUntilLongBreak = 4,
    this.autoStartNext = false,
  });

  PomodoroSettings copyWith({
    int? workMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? sessionsUntilLongBreak,
    bool? autoStartNext,
  }) {
    return PomodoroSettings(
      workMinutes: workMinutes ?? this.workMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      sessionsUntilLongBreak:
          sessionsUntilLongBreak ?? this.sessionsUntilLongBreak,
      autoStartNext: autoStartNext ?? this.autoStartNext,
    );
  }
}
