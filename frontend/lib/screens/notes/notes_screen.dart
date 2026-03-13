import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:ticktick_clone/models/note.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/note_provider.dart';
import 'package:ticktick_clone/screens/notes/note_edit_screen.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(noteFoldersStreamProvider).value ?? [];
    final allNotes = ref.watch(notesStreamProvider).value ?? [];
    final unfiledNotes = allNotes.where((n) => n.folderId == null).toList();
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Notes',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.create_new_folder_outlined),
            onSelected: (value) {
              if (value == 'folder') {
                _createFolder(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'folder',
                child: ListTile(
                  leading: Icon(Icons.create_new_folder_outlined),
                  title: Text('New Folder'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: allNotes.isEmpty && folders.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.note_outlined,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No notes yet',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('Tap + to create a note',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Folders with their notes
                ...folders.map((folder) {
                  final folderNotes =
                      allNotes.where((n) => n.folderId == folder.id).toList();
                  return _FolderSection(
                    folder: folder,
                    notes: folderNotes,
                  );
                }),
                // Unfiled notes
                if (unfiledNotes.isNotEmpty) ...[
                  if (folders.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('Unfiled',
                          style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ),
                  ...unfiledNotes.map((note) => _NoteTile(note: note)),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'notes_fab',
        onPressed: () {
          if (user == null) return;
          final note = Note(
            id: const Uuid().v4(),
            title: 'Untitled Note',
            userId: user.uid,
            createdAt: DateTime.now(),
          );
          ref.read(firestoreServiceProvider).addNote(user.uid, note);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NoteEditScreen(noteId: note.id),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _createFolder(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final user = ref.read(currentUserProvider);
              if (user == null) return;
              final folders =
                  ref.read(noteFoldersStreamProvider).value ?? [];
              final folder = NoteFolder(
                id: const Uuid().v4(),
                name: name,
                sortOrder: folders.length,
                createdAt: DateTime.now(),
              );
              ref.read(firestoreServiceProvider).addNoteFolder(user.uid, folder);
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _FolderSection extends ConsumerStatefulWidget {
  final NoteFolder folder;
  final List<Note> notes;

  const _FolderSection({required this.folder, required this.notes});

  @override
  ConsumerState<_FolderSection> createState() => _FolderSectionState();
}

class _FolderSectionState extends ConsumerState<_FolderSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          onLongPress: () => _showFolderActions(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? Icons.folder_open_outlined
                      : Icons.folder_outlined,
                  color: widget.folder.colorValue != null
                      ? Color(widget.folder.colorValue!)
                      : theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.folder.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text('${widget.notes.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.notes.map((note) => _NoteTile(note: note)),
      ],
    );
  }

  void _showFolderActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename Folder'),
              onTap: () {
                Navigator.pop(ctx);
                _renameFolder(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outlined, color: Colors.red),
              title: const Text('Delete Folder',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                ref
                    .read(firestoreServiceProvider)
                    .deleteNoteFolder(user.uid, widget.folder.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _renameFolder(BuildContext context) {
    final controller = TextEditingController(text: widget.folder.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final user = ref.read(currentUserProvider);
              if (user == null) return;
              ref.read(firestoreServiceProvider).updateNoteFolder(
                    user.uid,
                    widget.folder.copyWith(
                        name: name, updatedAt: DateTime.now()),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends ConsumerWidget {
  final Note note;
  const _NoteTile({required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.MMMd();
    final preview = note.content.length > 80
        ? '${note.content.substring(0, 80)}...'
        : note.content;

    return ListTile(
      leading: const Icon(Icons.note_outlined),
      title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview.isNotEmpty)
            Text(preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          Text(dateFormat.format(note.updatedAt),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
      isThreeLine: preview.isNotEmpty,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NoteEditScreen(noteId: note.id),
        ),
      ),
      onLongPress: () => _showNoteActions(context, ref),
    );
  }

  void _showNoteActions(BuildContext context, WidgetRef ref) {
    final folders = ref.read(noteFoldersStreamProvider).value ?? [];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (folders.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('Move to Folder'),
                onTap: () {
                  Navigator.pop(ctx);
                  _moveToFolder(context, ref, folders);
                },
              ),
            if (note.folderId != null)
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('Remove from Folder'),
                onTap: () {
                  Navigator.pop(ctx);
                  final user = ref.read(currentUserProvider);
                  if (user == null) return;
                  ref.read(firestoreServiceProvider).updateNote(
                        user.uid,
                        note.copyWith(
                            clearFolder: true, updatedAt: DateTime.now()),
                      );
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outlined, color: Colors.red),
              title:
                  const Text('Delete Note', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                ref.read(firestoreServiceProvider).deleteNote(user.uid, note.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _moveToFolder(
      BuildContext context, WidgetRef ref, List<NoteFolder> folders) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Move to Folder'),
        children: folders
            .map((folder) => SimpleDialogOption(
                  onPressed: () {
                    final user = ref.read(currentUserProvider);
                    if (user == null) return;
                    ref.read(firestoreServiceProvider).updateNote(
                          user.uid,
                          note.copyWith(
                              folderId: folder.id, updatedAt: DateTime.now()),
                        );
                    Navigator.pop(ctx);
                  },
                  child: Row(
                    children: [
                      Icon(Icons.folder_outlined,
                          color: folder.colorValue != null
                              ? Color(folder.colorValue!)
                              : null),
                      const SizedBox(width: 12),
                      Text(folder.name),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}
