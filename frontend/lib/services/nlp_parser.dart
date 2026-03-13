import 'package:ticktick_clone/models/task.dart';

/// Result of parsing a natural language task input string.
class ParsedTaskInput {
  final String title;
  final DateTime? dueDate;
  final TaskPriority priority;
  final List<String> tags;
  final String? listName;
  final RecurrenceRule? recurrence;

  const ParsedTaskInput({
    required this.title,
    this.dueDate,
    this.priority = TaskPriority.none,
    this.tags = const [],
    this.listName,
    this.recurrence,
  });
}

/// Lightweight recurrence rule matching the backend schema.
class RecurrenceRule {
  final String frequency; // daily, weekly, monthly, yearly
  final int interval;
  final List<int>? daysOfWeek;

  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.daysOfWeek,
  });

  Map<String, dynamic> toMap() => {
        'frequency': frequency,
        'interval': interval,
        'afterCompletion': false,
        if (daysOfWeek != null) 'daysOfWeek': daysOfWeek,
      };
}

// Day name → Dart weekday (DateTime.monday=1 .. DateTime.sunday=7)
// But we store 0=Sun..6=Sat to match backend
const _dayMap = <String, int>{
  'sunday': 0, 'sun': 0,
  'monday': 1, 'mon': 1,
  'tuesday': 2, 'tue': 2, 'tues': 2,
  'wednesday': 3, 'wed': 3,
  'thursday': 4, 'thu': 4, 'thurs': 4,
  'friday': 5, 'fri': 5,
  'saturday': 6, 'sat': 6,
};

/// Parse a task title string and extract structured fields.
///
/// Supported syntax:
///   Dates/times: "tomorrow", "today", "tonight", "tomorrow at 3pm",
///                "next Monday", "next week", "in 2 hours", "in 3 days",
///                "Monday", "Friday at 5pm"
///   Priority:    "!!" = high, "!" = medium
///   Tags:        "#work", "#personal"
///   List:        "/projectname"
///   Recurrence:  "every day", "every Monday", "daily", "weekly", "monthly",
///                "every 3 days", "every 2 weeks"
ParsedTaskInput parseTaskInput(String input, {DateTime? now}) {
  final refDate = now ?? DateTime.now();
  var text = input;
  DateTime? dueDate;
  var priority = TaskPriority.none;
  final tags = <String>[];
  String? listName;
  RecurrenceRule? recurrence;

  // --- Extract tags (#word) ---
  text = text.replaceAllMapped(RegExp(r'#(\w[\w-]*)'), (m) {
    tags.add(m.group(1)!);
    return '';
  });

  // --- Extract list assignment (/listname) ---
  text = text.replaceAllMapped(RegExp(r'/(\w[\w-]*)'), (m) {
    listName = m.group(1)!;
    return '';
  });

  // --- Extract priority (!! or !) ---
  if (RegExp(r'\s!!(?:\s|$)').hasMatch(text) ||
      text.startsWith('!! ') ||
      text == '!!') {
    priority = TaskPriority.high;
    text = text.replaceAll('!!', '');
  } else if (RegExp(r'\s!(?:\s|$)').hasMatch(text) ||
      text.startsWith('! ') ||
      text == '!') {
    priority = TaskPriority.medium;
    text = text.replaceAllMapped(RegExp(r'(?<![!])!(?![!])'), (_) => '');
  }

  // --- Extract recurrence ---
  final recResult = _parseRecurrence(text);
  if (recResult != null) {
    recurrence = recResult.rule;
    text = recResult.remaining;
    if (recResult.initialDay != null) {
      dueDate = _getNextDayOfWeek(refDate, recResult.initialDay!);
    }
  }

  // --- Extract date/time ---
  final dateResult = _parseDate(text, refDate);
  if (dateResult != null) {
    dueDate = dateResult.date;
    text = dateResult.remaining;
  }

  // Clean up whitespace
  final title = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  return ParsedTaskInput(
    title: title,
    dueDate: dueDate,
    priority: priority,
    tags: tags,
    listName: listName,
    recurrence: recurrence,
  );
}

// --- Internal helpers ---

class _DateResult {
  final DateTime date;
  final String remaining;
  const _DateResult(this.date, this.remaining);
}

class _RecurrenceResult {
  final RecurrenceRule rule;
  final String remaining;
  final int? initialDay;
  const _RecurrenceResult(this.rule, this.remaining, [this.initialDay]);
}

_RecurrenceResult? _parseRecurrence(String text) {
  var remaining = text;

  // "every N days/weeks/months/years"
  final everyN = RegExp(
      r'\bevery\s+(\d+)\s+(day|days|week|weeks|month|months|year|years)\b',
      caseSensitive: false);
  final everyNMatch = everyN.firstMatch(remaining);
  if (everyNMatch != null) {
    final interval = int.parse(everyNMatch.group(1)!);
    final unit = everyNMatch.group(2)!.toLowerCase().replaceAll(RegExp(r's$'), '');
    const freqMap = {
      'day': 'daily',
      'week': 'weekly',
      'month': 'monthly',
      'year': 'yearly',
    };
    remaining = remaining.replaceFirst(everyN, '');
    return _RecurrenceResult(
      RecurrenceRule(frequency: freqMap[unit]!, interval: interval),
      remaining,
    );
  }

  // "every Monday", "every Monday and Wednesday"
  final everyDay = RegExp(
      r'\bevery\s+((?:(?:and|,)\s*)?(?:sun(?:day)?|mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:rs(?:day)?)?|fri(?:day)?|sat(?:urday)?)(?:\s*(?:,|and)\s*(?:sun(?:day)?|mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:rs(?:day)?)?|fri(?:day)?|sat(?:urday)?))*)\b',
      caseSensitive: false);
  final everyDayMatch = everyDay.firstMatch(remaining);
  if (everyDayMatch != null) {
    final days = _parseDayList(everyDayMatch.group(1)!);
    if (days.isNotEmpty) {
      remaining = remaining.replaceFirst(everyDay, '');
      return _RecurrenceResult(
        RecurrenceRule(frequency: 'weekly', interval: 1, daysOfWeek: days),
        remaining,
        days.first,
      );
    }
  }

  // "every day" / "daily"
  final daily = RegExp(r'\b(?:every\s+day|daily)\b', caseSensitive: false);
  if (daily.hasMatch(remaining)) {
    remaining = remaining.replaceFirst(daily, '');
    return _RecurrenceResult(
      const RecurrenceRule(frequency: 'daily'),
      remaining,
    );
  }

  // "weekly"
  final weekly = RegExp(r'\bweekly\b', caseSensitive: false);
  if (weekly.hasMatch(remaining)) {
    remaining = remaining.replaceFirst(weekly, '');
    return _RecurrenceResult(
      const RecurrenceRule(frequency: 'weekly'),
      remaining,
    );
  }

  // "monthly"
  final monthly = RegExp(r'\bmonthly\b', caseSensitive: false);
  if (monthly.hasMatch(remaining)) {
    remaining = remaining.replaceFirst(monthly, '');
    return _RecurrenceResult(
      const RecurrenceRule(frequency: 'monthly'),
      remaining,
    );
  }

  // "yearly"
  final yearly = RegExp(r'\byearly\b', caseSensitive: false);
  if (yearly.hasMatch(remaining)) {
    remaining = remaining.replaceFirst(yearly, '');
    return _RecurrenceResult(
      const RecurrenceRule(frequency: 'yearly'),
      remaining,
    );
  }

  return null;
}

List<int> _parseDayList(String text) {
  final days = <int>{};
  final parts = text.split(RegExp(r'\s*(?:,|and)\s*', caseSensitive: false));
  for (final part in parts) {
    final trimmed = part.trim().toLowerCase();
    if (trimmed.isNotEmpty && _dayMap.containsKey(trimmed)) {
      days.add(_dayMap[trimmed]!);
    }
  }
  return days.toList()..sort();
}

_DateResult? _parseDate(String text, DateTime refDate) {
  var remaining = text;

  // "today" / "today at HH:MM am/pm"
  final today = RegExp(
      r'\btoday(?:\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?)?',
      caseSensitive: false);
  final todayMatch = today.firstMatch(remaining);
  if (todayMatch != null) {
    var date = DateTime(refDate.year, refDate.month, refDate.day, 23, 59);
    if (todayMatch.group(1) != null) {
      date = _applyTime(
          date, todayMatch.group(1)!, todayMatch.group(2), todayMatch.group(3));
    }
    remaining = remaining.replaceFirst(today, '');
    return _DateResult(date, remaining);
  }

  // "tonight"
  final tonight = RegExp(r'\btonight\b', caseSensitive: false);
  if (tonight.hasMatch(remaining)) {
    final date = DateTime(refDate.year, refDate.month, refDate.day, 21, 0);
    remaining = remaining.replaceFirst(tonight, '');
    return _DateResult(date, remaining);
  }

  // "tomorrow" / "tomorrow at Hpm"
  final tomorrow = RegExp(
      r'\btomorrow(?:\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?)?',
      caseSensitive: false);
  final tomorrowMatch = tomorrow.firstMatch(remaining);
  if (tomorrowMatch != null) {
    final nextDay = refDate.add(const Duration(days: 1));
    var date = DateTime(nextDay.year, nextDay.month, nextDay.day, 23, 59);
    if (tomorrowMatch.group(1) != null) {
      date = _applyTime(date, tomorrowMatch.group(1)!, tomorrowMatch.group(2),
          tomorrowMatch.group(3));
    }
    remaining = remaining.replaceFirst(tomorrow, '');
    return _DateResult(date, remaining);
  }

  // "next week"
  final nextWeek = RegExp(r'\bnext\s+week\b', caseSensitive: false);
  if (nextWeek.hasMatch(remaining)) {
    final date = _getNextDayOfWeek(refDate, 1); // next Monday
    final dateWithTime = DateTime(date.year, date.month, date.day, 9, 0);
    remaining = remaining.replaceFirst(nextWeek, '');
    return _DateResult(dateWithTime, remaining);
  }

  // "next Monday", "next Friday at 5pm"
  final nextDay = RegExp(
      r'\bnext\s+(sunday|sun|monday|mon|tuesday|tue|tues|wednesday|wed|thursday|thu|thurs|friday|fri|saturday|sat)(?:\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?)?\b',
      caseSensitive: false);
  final nextDayMatch = nextDay.firstMatch(remaining);
  if (nextDayMatch != null) {
    final dayName = nextDayMatch.group(1)!.toLowerCase();
    final targetDay = _dayMap[dayName]!;
    final date = _getNextDayOfWeek(refDate, targetDay, forceNextWeek: true);
    var dateWithTime = DateTime(date.year, date.month, date.day, 9, 0);
    if (nextDayMatch.group(2) != null) {
      dateWithTime = _applyTime(dateWithTime, nextDayMatch.group(2)!,
          nextDayMatch.group(3), nextDayMatch.group(4));
    }
    remaining = remaining.replaceFirst(nextDay, '');
    return _DateResult(dateWithTime, remaining);
  }

  // "in N hours/minutes/days/weeks"
  final inN = RegExp(
      r'\bin\s+(\d+)\s+(hour|hours|minute|minutes|min|mins|day|days|week|weeks)\b',
      caseSensitive: false);
  final inNMatch = inN.firstMatch(remaining);
  if (inNMatch != null) {
    final n = int.parse(inNMatch.group(1)!);
    final unit = inNMatch.group(2)!.toLowerCase().replaceAll(RegExp(r's$'), '');
    DateTime date;
    switch (unit) {
      case 'hour':
        date = refDate.add(Duration(hours: n));
      case 'minute':
      case 'min':
        date = refDate.add(Duration(minutes: n));
      case 'day':
        date = refDate.add(Duration(days: n));
      case 'week':
        date = refDate.add(Duration(days: n * 7));
      default:
        date = refDate;
    }
    remaining = remaining.replaceFirst(inN, '');
    return _DateResult(date, remaining);
  }

  // Bare day name: "Monday", "Friday at 5pm"
  final bareDay = RegExp(
      r'\b(sunday|sun|monday|mon|tuesday|tue|tues|wednesday|wed|thursday|thu|thurs|friday|fri|saturday|sat)(?:\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?)?\b',
      caseSensitive: false);
  final bareDayMatch = bareDay.firstMatch(remaining);
  if (bareDayMatch != null) {
    final dayName = bareDayMatch.group(1)!.toLowerCase();
    final targetDay = _dayMap[dayName]!;
    final date = _getNextDayOfWeek(refDate, targetDay);
    var dateWithTime = DateTime(date.year, date.month, date.day, 9, 0);
    if (bareDayMatch.group(2) != null) {
      dateWithTime = _applyTime(dateWithTime, bareDayMatch.group(2)!,
          bareDayMatch.group(3), bareDayMatch.group(4));
    }
    remaining = remaining.replaceFirst(bareDay, '');
    return _DateResult(dateWithTime, remaining);
  }

  return null;
}

DateTime _applyTime(
    DateTime date, String hourStr, String? minuteStr, String? ampm) {
  var hour = int.parse(hourStr);
  final minute = minuteStr != null ? int.parse(minuteStr) : 0;
  if (ampm != null) {
    final isPm = ampm.toLowerCase() == 'pm';
    if (isPm && hour < 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;
  } else if (hour < 8) {
    // Assume PM for ambiguous small numbers
    hour += 12;
  }
  return DateTime(date.year, date.month, date.day, hour, minute);
}

DateTime _getNextDayOfWeek(DateTime refDate, int targetDay,
    {bool forceNextWeek = false}) {
  // Convert from 0=Sun..6=Sat to Dart's 1=Mon..7=Sun
  final dartTarget = targetDay == 0 ? 7 : targetDay;
  final currentDay = refDate.weekday; // 1=Mon..7=Sun
  var daysAhead = dartTarget - currentDay;
  if (daysAhead <= 0 || forceNextWeek) {
    daysAhead += 7;
  }
  return refDate.add(Duration(days: daysAhead));
}
