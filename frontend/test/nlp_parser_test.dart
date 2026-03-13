import 'package:flutter_test/flutter_test.dart';
import 'package:ticktick_clone/services/nlp_parser.dart';
import 'package:ticktick_clone/models/task.dart';

void main() {
  // Wednesday March 11, 2026, 10:00 AM
  final ref = DateTime(2026, 3, 11, 10, 0);

  group('basic title', () {
    test('returns title unchanged when no tokens', () {
      final r = parseTaskInput('Buy groceries', now: ref);
      expect(r.title, 'Buy groceries');
      expect(r.priority, TaskPriority.none);
      expect(r.tags, isEmpty);
      expect(r.dueDate, isNull);
    });
  });

  group('priority', () {
    test('!! = high', () {
      final r = parseTaskInput('Fix bug !! now', now: ref);
      expect(r.priority, TaskPriority.high);
      expect(r.title, 'Fix bug now');
    });

    test('! = medium', () {
      final r = parseTaskInput('Review PR ! soon', now: ref);
      expect(r.priority, TaskPriority.medium);
      expect(r.title, 'Review PR soon');
    });
  });

  group('tags', () {
    test('extracts single tag', () {
      final r = parseTaskInput('Report #work', now: ref);
      expect(r.tags, ['work']);
      expect(r.title, 'Report');
    });

    test('extracts multiple tags', () {
      final r = parseTaskInput('#urgent Review #work docs', now: ref);
      expect(r.tags, ['urgent', 'work']);
      expect(r.title, 'Review docs');
    });
  });

  group('list', () {
    test('extracts /listname', () {
      final r = parseTaskInput('Call dentist /personal', now: ref);
      expect(r.listName, 'personal');
      expect(r.title, 'Call dentist');
    });
  });

  group('dates', () {
    test('today', () {
      final r = parseTaskInput('Laundry today', now: ref);
      expect(r.dueDate, isNotNull);
      expect(r.dueDate!.day, 11);
    });

    test('today at 3pm', () {
      final r = parseTaskInput('Meeting today at 3pm', now: ref);
      expect(r.dueDate!.day, 11);
      expect(r.dueDate!.hour, 15);
    });

    test('tonight', () {
      final r = parseTaskInput('Read tonight', now: ref);
      expect(r.dueDate!.day, 11);
      expect(r.dueDate!.hour, 21);
    });

    test('tomorrow', () {
      final r = parseTaskInput('Dentist tomorrow', now: ref);
      expect(r.dueDate!.day, 12);
    });

    test('tomorrow at 2pm', () {
      final r = parseTaskInput('Call tomorrow at 2pm', now: ref);
      expect(r.dueDate!.day, 12);
      expect(r.dueDate!.hour, 14);
    });

    test('in 2 hours', () {
      final r = parseTaskInput('Check in 2 hours', now: ref);
      expect(r.dueDate!.hour, 12);
    });

    test('in 3 days', () {
      final r = parseTaskInput('Follow up in 3 days', now: ref);
      expect(r.dueDate!.day, 14);
    });

    test('Friday (from Wednesday)', () {
      final r = parseTaskInput('Submit Friday', now: ref);
      expect(r.dueDate!.weekday, DateTime.friday);
      expect(r.dueDate!.day, 13);
    });

    test('next Monday', () {
      final r = parseTaskInput('Plan next Monday', now: ref);
      expect(r.dueDate!.weekday, DateTime.monday);
      expect(r.dueDate!.day, 16);
    });

    test('next week', () {
      final r = parseTaskInput('Review next week', now: ref);
      expect(r.dueDate!.weekday, DateTime.monday);
      expect(r.dueDate!.day, 16);
    });
  });

  group('recurrence', () {
    test('daily', () {
      final r = parseTaskInput('Standup daily', now: ref);
      expect(r.recurrence, isNotNull);
      expect(r.recurrence!.frequency, 'daily');
      expect(r.recurrence!.interval, 1);
    });

    test('every 3 days', () {
      final r = parseTaskInput('Water plants every 3 days', now: ref);
      expect(r.recurrence!.frequency, 'daily');
      expect(r.recurrence!.interval, 3);
    });

    test('every Monday', () {
      final r = parseTaskInput('Standup every Monday', now: ref);
      expect(r.recurrence!.frequency, 'weekly');
      expect(r.recurrence!.daysOfWeek, [1]);
      expect(r.dueDate, isNotNull); // should set initial due date
    });

    test('weekly', () {
      final r = parseTaskInput('Review weekly', now: ref);
      expect(r.recurrence!.frequency, 'weekly');
    });

    test('monthly', () {
      final r = parseTaskInput('Rent monthly', now: ref);
      expect(r.recurrence!.frequency, 'monthly');
    });
  });

  group('combined', () {
    test('title + date + priority + tag + list', () {
      final r = parseTaskInput(
        'Review PR tomorrow at 3pm !! #work /engineering',
        now: ref,
      );
      expect(r.title, 'Review PR');
      expect(r.priority, TaskPriority.high);
      expect(r.tags, ['work']);
      expect(r.listName, 'engineering');
      expect(r.dueDate!.day, 12);
      expect(r.dueDate!.hour, 15);
    });
  });
}
