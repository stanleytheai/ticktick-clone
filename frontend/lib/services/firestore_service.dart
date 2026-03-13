import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ticktick_clone/models/focus_session.dart';
import 'package:ticktick_clone/models/habit.dart';
import 'package:ticktick_clone/models/note.dart';
import 'package:ticktick_clone/models/pomodoro_session.dart';
import 'package:ticktick_clone/models/smart_filter.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/models/task_list.dart';
import 'package:ticktick_clone/models/user_settings.dart';

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

  Future<void> batchUpdateTaskSortOrders(
      String userId, List<Task> tasks) async {
    final batch = _db.batch();
    for (final task in tasks) {
      batch.update(_tasksRef(userId).doc(task.id), {
        'sortOrder': task.sortOrder,
        'listId': task.listId,
        'updatedAt': Timestamp.fromDate(task.updatedAt),
      });
    }
    await batch.commit();
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

  Future<void> batchUpdateListSortOrders(
      String userId, List<TaskList> lists) async {
    final batch = _db.batch();
    for (final list in lists) {
      batch.update(_listsRef(userId).doc(list.id), {
        'sortOrder': list.sortOrder,
      });
    }
    await batch.commit();
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

  // Filters
  CollectionReference<Map<String, dynamic>> _filtersRef(String userId) =>
      _db.collection('users').doc(userId).collection('filters');

  Stream<List<SmartFilter>> watchFilters(String userId) {
    return _filtersRef(userId)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => SmartFilter.fromMap(d.id, d.data())).toList());
  }

  Future<void> addFilter(String userId, SmartFilter filter) {
    return _filtersRef(userId).doc(filter.id).set(filter.toMap());
  }

  Future<void> updateFilter(String userId, SmartFilter filter) {
    return _filtersRef(userId).doc(filter.id).update(filter.toMap());
  }

  Future<void> deleteFilter(String userId, String filterId) {
    return _filtersRef(userId).doc(filterId).delete();
  }

  // Notes
  CollectionReference<Map<String, dynamic>> _notesRef(String userId) =>
      _db.collection('users').doc(userId).collection('notes');

  CollectionReference<Map<String, dynamic>> _noteFoldersRef(String userId) =>
      _db.collection('users').doc(userId).collection('noteFolders');

  Stream<List<Note>> watchNotes(String userId) {
    return _notesRef(userId)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Note.fromMap(d.id, d.data())).toList());
  }

  Future<void> addNote(String userId, Note note) {
    return _notesRef(userId).doc(note.id).set(note.toMap());
  }

  Future<void> updateNote(String userId, Note note) {
    return _notesRef(userId).doc(note.id).update(note.toMap());
  }

  Future<void> deleteNote(String userId, String noteId) {
    return _notesRef(userId).doc(noteId).delete();
  }

  // Note Folders
  Stream<List<NoteFolder>> watchNoteFolders(String userId) {
    return _noteFoldersRef(userId)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => NoteFolder.fromMap(d.id, d.data())).toList());
  }

  Future<void> addNoteFolder(String userId, NoteFolder folder) {
    return _noteFoldersRef(userId).doc(folder.id).set(folder.toMap());
  }

  Future<void> updateNoteFolder(String userId, NoteFolder folder) {
    return _noteFoldersRef(userId).doc(folder.id).update(folder.toMap());
  }

  Future<void> deleteNoteFolder(String userId, String folderId) async {
    // Move notes in this folder to unfiled
    final notes = await _notesRef(userId)
        .where('folderId', isEqualTo: folderId)
        .get();
    final batch = _db.batch();
    for (final doc in notes.docs) {
      batch.update(doc.reference, {
        'folderId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.delete(_noteFoldersRef(userId).doc(folderId));
    await batch.commit();
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

  // Settings
  DocumentReference<Map<String, dynamic>> _settingsRef(String userId) =>
      _db.collection('users').doc(userId).collection('settings').doc('preferences');

  Stream<UserSettings> watchSettings(String userId) {
    return _settingsRef(userId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return UserSettings.defaultSettings;
      }
      return UserSettings.fromMap(snap.data()!);
    });
  }

  Future<UserSettings> getSettings(String userId) async {
    final snap = await _settingsRef(userId).get();
    if (!snap.exists || snap.data() == null) {
      return UserSettings.defaultSettings;
    }
    return UserSettings.fromMap(snap.data()!);
  }

  Future<void> updateSettings(String userId, UserSettings settings) {
    return _settingsRef(userId).set(settings.toMap(), SetOptions(merge: true));
  }

  // Data export - gather all user data
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    final tasksSnap = await _tasksRef(userId).get();
    final listsSnap = await _listsRef(userId).get();

    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': tasksSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
      'lists': listsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    };
  }

  // Delete all user data (for account deletion)
  Future<void> deleteAllUserData(String userId) async {
    final batch = _db.batch();

    final tasks = await _tasksRef(userId).get();
    for (final doc in tasks.docs) {
      batch.delete(doc.reference);
    }

    final lists = await _listsRef(userId).get();
    for (final doc in lists.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_settingsRef(userId));
    await batch.commit();
  }

  // Ensure user profile doc exists with default free tier
  Future<void> ensureUserProfile(String userId) async {
    final userDoc = _db.collection('users').doc(userId);
    final snap = await userDoc.get();
    if (!snap.exists) {
      await userDoc.set({
        'subscriptionTier': 'free',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
