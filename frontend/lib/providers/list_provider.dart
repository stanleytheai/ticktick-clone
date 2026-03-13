import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/task_list.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';

final listsStreamProvider = StreamProvider<List<TaskList>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchLists(user.uid);
});

final listByIdProvider =
    Provider.family<TaskList?, String>((ref, listId) {
  final lists = ref.watch(listsStreamProvider).value ?? [];
  try {
    return lists.firstWhere((l) => l.id == listId);
  } catch (_) {
    return null;
  }
});
