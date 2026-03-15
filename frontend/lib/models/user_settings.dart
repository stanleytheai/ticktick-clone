class UserSettings {
  final String theme;
  final String fontSize;
  final String? defaultListId;
  final int defaultReminderMinutes;
  final int weekStartDay; // 0=Sunday, 1=Monday
  final String dateFormat;
  final String timeFormat;
  final String language;
  final bool soundEnabled;
  final bool notificationsEnabled;
  final bool quietHoursEnabled;
  final String quietHoursStart; // HH:mm
  final String quietHoursEnd; // HH:mm

  const UserSettings({
    this.theme = 'system',
    this.fontSize = 'medium',
    this.defaultListId,
    this.defaultReminderMinutes = 0,
    this.weekStartDay = 0,
    this.dateFormat = 'MMM d, yyyy',
    this.timeFormat = '12h',
    this.language = 'en',
    this.soundEnabled = true,
    this.notificationsEnabled = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '07:00',
  });

  static const defaultSettings = UserSettings();

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      theme: map['theme'] as String? ?? 'system',
      fontSize: map['fontSize'] as String? ?? 'medium',
      defaultListId: map['defaultListId'] as String?,
      defaultReminderMinutes: map['defaultReminderMinutes'] as int? ?? 0,
      weekStartDay: map['weekStartDay'] as int? ?? 0,
      dateFormat: map['dateFormat'] as String? ?? 'MMM d, yyyy',
      timeFormat: map['timeFormat'] as String? ?? '12h',
      language: map['language'] as String? ?? 'en',
      soundEnabled: map['soundEnabled'] as bool? ?? true,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      quietHoursEnabled: map['quietHoursEnabled'] as bool? ?? false,
      quietHoursStart: map['quietHoursStart'] as String? ?? '22:00',
      quietHoursEnd: map['quietHoursEnd'] as String? ?? '07:00',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'theme': theme,
      'fontSize': fontSize,
      if (defaultListId != null) 'defaultListId': defaultListId,
      'defaultReminderMinutes': defaultReminderMinutes,
      'weekStartDay': weekStartDay,
      'dateFormat': dateFormat,
      'timeFormat': timeFormat,
      'language': language,
      'soundEnabled': soundEnabled,
      'notificationsEnabled': notificationsEnabled,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
    };
  }

  UserSettings copyWith({
    String? theme,
    String? fontSize,
    String? defaultListId,
    int? defaultReminderMinutes,
    int? weekStartDay,
    String? dateFormat,
    String? timeFormat,
    String? language,
    bool? soundEnabled,
    bool? notificationsEnabled,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) {
    return UserSettings(
      theme: theme ?? this.theme,
      fontSize: fontSize ?? this.fontSize,
      defaultListId: defaultListId ?? this.defaultListId,
      defaultReminderMinutes:
          defaultReminderMinutes ?? this.defaultReminderMinutes,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      language: language ?? this.language,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }
}
