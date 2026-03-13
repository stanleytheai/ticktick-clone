import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/note.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';

final notesStreamProvider = StreamProvider<List<Note>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchNotes(user.uid);
});

final noteFoldersStreamProvider = StreamProvider<List<NoteFolder>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchNoteFolders(user.uid);
});

final notesByFolderProvider =
    Provider.family<List<Note>, String?>((ref, folderId) {
  final notes = ref.watch(notesStreamProvider).value ?? [];
  if (folderId == null) {
    return notes.where((n) => n.folderId == null).toList();
  }
  return notes.where((n) => n.folderId == folderId).toList();
});
