import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/activity_entry.dart';
import 'package:ticktick_clone/models/comment.dart';
import 'package:ticktick_clone/models/shared_list.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';

final sharedListsStreamProvider = StreamProvider<List<SharedList>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchSharedLists(user.uid);
});

final sharedListByIdProvider =
    Provider.family<SharedList?, String>((ref, listId) {
  final lists = ref.watch(sharedListsStreamProvider).value ?? [];
  try {
    return lists.firstWhere((l) => l.id == listId);
  } catch (_) {
    return null;
  }
});

final sharedTasksProvider =
    StreamProvider.family<List<Task>, String>((ref, listId) {
  return ref.watch(firestoreServiceProvider).watchSharedTasks(listId);
});

final commentsProvider =
    StreamProvider.family<List<Comment>, ({String listId, String taskId})>(
        (ref, params) {
  return ref
      .watch(firestoreServiceProvider)
      .watchComments(params.listId, params.taskId);
});

final activityProvider =
    StreamProvider.family<List<ActivityEntry>, String>((ref, listId) {
  return ref.watch(firestoreServiceProvider).watchActivity(listId);
});
