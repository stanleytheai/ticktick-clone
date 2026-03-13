import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ticktick_clone/models/focus_session.dart';
import 'package:ticktick_clone/models/habit.dart';
import 'package:ticktick_clone/models/pomodoro_session.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/models/task_list.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirestoreService() {
    _db.settings = const Settings(persistenceEnabled: true);
  }

  // Tasks
  CollectionReference<Map<String, dynamic>> _tasksRef(String userId) =>
      _db.collection('users').doc(userId).collection('tasks');

  Stream<List<Task>> watchTasks(String userId) {
    return _tasksRef(userId)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Task.fromMap(d.id, d.data())).toList());
  }

  Future<void> addTask(String userId, Task task) {
    return _tasksRef(userId).doc(task.id).set(task.toMap());
  }

  Future<void> updateTask(String userId, Task task) {
    return _tasksRef(userId).doc(task.id).update(task.toMap());
  }

  Future<void> deleteTask(String userId, String taskId) {
    return _tasksRef(userId).doc(taskId).delete();
  }

  // Lists
  CollectionReference<Map<String, dynamic>> _listsRef(String userId) =>
      _db.collection('users').doc(userId).collection('lists');

  Stream<List<TaskList>> watchLists(String userId) {
    return _listsRef(userId)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => TaskList.fromMap(d.id, d.data())).toList());
  }

  Future<void> addList(String userId, TaskList list) {
    return _listsRef(userId).doc(list.id).set(list.toMap());
  }

  Future<void> updateList(String userId, TaskList list) {
    return _listsRef(userId).doc(list.id).update(list.toMap());
  }

  Future<void> deleteList(String userId, String listId) async {
    // Delete all tasks in this list first
    final tasks = await _tasksRef(userId)
        .where('listId', isEqualTo: listId)
        .get();
    final batch = _db.batch();
    for (final doc in tasks.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_listsRef(userId).doc(listId));
    await batch.commit();
  }

  // Focus Sessions
  CollectionReference<Map<String, dynamic>> _focusSessionsRef(String userId) =>
      _db.collection('users').doc(userId).collection('focusSessions');

  Stream<List<FocusSession>> watchFocusSessions(String userId) {
    return _focusSessionsRef(userId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FocusSession.fromMap(d.id, d.data())).toList());
  }

  Future<void> addFocusSession(String userId, FocusSession session) {
    return _focusSessionsRef(userId).doc(session.id).set(session.toMap());
  }

  // Habits
  CollectionReference<Map<String, dynamic>> _habitsRef(String userId) =>
      _db.collection('users').doc(userId).collection('habits');

  CollectionReference<Map<String, dynamic>> _habitLogsRef(
          String userId, String habitId) =>
      _habitsRef(userId).doc(habitId).collection('logs');

  Stream<List<Habit>> watchHabits(String userId) {
    return _habitsRef(userId)
        .where('archived', isEqualTo: false)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Habit.fromMap(d.id, d.data())).toList());
  }

  Future<void> addHabit(String userId, Habit habit) {
    return _habitsRef(userId).doc(habit.id).set(habit.toMap());
  }

  Future<void> updateHabit(String userId, Habit habit) {
    return _habitsRef(userId).doc(habit.id).update(habit.toMap());
  }

  Future<void> deleteHabit(String userId, String habitId) async {
    final logs = await _habitLogsRef(userId, habitId).get();
    final batch = _db.batch();
    for (final doc in logs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_habitsRef(userId).doc(habitId));
    await batch.commit();
  }

  Stream<List<HabitLog>> watchHabitLogs(String userId, String habitId) {
    return _habitLogsRef(userId, habitId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => HabitLog.fromMap(d.id, d.data())).toList());
  }

  Future<void> logHabit(
      String userId, String habitId, String date, int value,
      {bool skipped = false}) {
    return _habitLogsRef(userId, habitId).doc(date).set({
      'date': date,
      'value': value,
      'skipped': skipped,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteHabitLog(
      String userId, String habitId, String date) {
    return _habitLogsRef(userId, habitId).doc(date).delete();
  }

  // Pomodoro Sessions
  CollectionReference<Map<String, dynamic>> _pomodoroRef(String userId) =>
      _db.collection('users').doc(userId).collection('pomodoroSessions');

  Stream<List<PomodoroSession>> watchPomodoroSessions(String userId) {
    return _pomodoroRef(userId)
        .orderBy('startTime', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PomodoroSession.fromMap(d.id, d.data()))
            .toList());
  }

  Future<PomodoroSession> startPomodoroSession(
      String userId, PomodoroSession session) async {
    final docRef = await _pomodoroRef(userId).add(session.toMap());
    return session.copyWith(id: docRef.id);
  }

  Future<void> stopPomodoroSession(
      String userId, String sessionId, bool completed) {
    return _pomodoroRef(userId).doc(sessionId).update({
      'endTime': Timestamp.fromDate(DateTime.now()),
      'completed': completed,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> updatePomodoroSession(
      String userId, PomodoroSession session) {
    return _pomodoroRef(userId).doc(session.id).update(session.toMap());
  }

  Stream<List<PomodoroSession>> watchTodayPomodoroSessions(String userId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _pomodoroRef(userId)
        .where('startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PomodoroSession.fromMap(d.id, d.data()))
            .toList());
  }

  // Create default Inbox list for new users
  Future<void> createDefaultList(String userId) async {
    final existingLists = await _listsRef(userId).limit(1).get();
    if (existingLists.docs.isEmpty) {
      final inbox = TaskList(
        id: 'inbox',
        name: 'Inbox',
        colorValue: 0xFF2196F3,
        userId: userId,
        sortOrder: 0,
        createdAt: DateTime.now(),
      );
      await addList(userId, inbox);
    }
  }
}
