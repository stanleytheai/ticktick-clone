import 'package:cloud_firestore/cloud_firestore.dart';
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
