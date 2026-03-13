import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:ticktick_clone/models/note.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/note_provider.dart';

class NoteEditScreen extends ConsumerStatefulWidget {
  final String noteId;

  const NoteEditScreen({super.key, required this.noteId});

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _initialized = false;
  bool _isPreview = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Note? _findNote(List<Note> notes) {
    try {
      return notes.firstWhere((n) => n.id == widget.noteId);
    } catch (_) {
      return null;
    }
  }

  void _initControllers(Note note) {
    if (!_initialized) {
      _titleController = TextEditingController(text: note.title);
      _contentController = TextEditingController(text: note.content);
      _initialized = true;
    }
  }

  Future<void> _saveNote(Note note) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(firestoreServiceProvider).updateNote(
          user.uid,
          note.copyWith(updatedAt: DateTime.now()),
        );
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesStreamProvider).value ?? [];
    final note = _findNote(notes);
    if (note == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Note not found')),
      );
    }

    _initControllers(note);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Note'),
        actions: [
          IconButton(
            icon: Icon(_isPreview ? Icons.edit : Icons.visibility),
            tooltip: _isPreview ? 'Edit' : 'Preview',
            onPressed: () => setState(() => _isPreview = !_isPreview),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                await ref
                    .read(firestoreServiceProvider)
                    .deleteNote(user.uid, note.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outlined, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _titleController,
              style: theme.textTheme.titleLarge,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Note title',
              ),
              onChanged: (v) => _saveNote(note.copyWith(title: v)),
            ),
          ),
          const Divider(),
          // Content — edit or preview
          Expanded(
            child: _isPreview
                ? _MarkdownPreview(content: _contentController.text)
                : _MarkdownEditor(
                    controller: _contentController,
                    onChanged: (v) => _saveNote(note.copyWith(content: v)),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _isPreview
          ? null
          : _MarkdownToolbar(controller: _contentController, onChanged: () {
              _saveNote(note.copyWith(content: _contentController.text));
            }),
    );
  }
}

class _MarkdownPreview extends StatelessWidget {
  final String content;
  const _MarkdownPreview({required this.content});

  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) {
      return Center(
        child: Text('Nothing to preview',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
    }
    return Markdown(
      data: content,
      selectable: true,
      padding: const EdgeInsets.all(16),
    );
  }
}

class _MarkdownEditor extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _MarkdownEditor({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Start writing... (supports Markdown)',
        ),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        onChanged: onChanged,
      ),
    );
  }
}

class _MarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _MarkdownToolbar({
    required this.controller,
    required this.onChanged,
  });

  void _insertMarkdown(String prefix, [String suffix = '']) {
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.start;
    final end = sel.end;

    if (start < 0) return;

    final selected = text.substring(start, end);
    final replacement = '$prefix$selected$suffix';
    controller.text = text.replaceRange(start, end, replacement);
    controller.selection = TextSelection.collapsed(
      offset: start + prefix.length + selected.length,
    );
    onChanged();
  }

  void _insertAtLineStart(String prefix) {
    final text = controller.text;
    final sel = controller.selection;
    final pos = sel.start;

    if (pos < 0) return;

    // Find start of current line
    final lineStart = text.lastIndexOf('\n', pos - 1) + 1;
    controller.text = text.substring(0, lineStart) + prefix + text.substring(lineStart);
    controller.selection = TextSelection.collapsed(
      offset: pos + prefix.length,
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            IconButton(
              icon: const Icon(Icons.format_bold, size: 20),
              tooltip: 'Bold',
              onPressed: () => _insertMarkdown('**', '**'),
            ),
            IconButton(
              icon: const Icon(Icons.format_italic, size: 20),
              tooltip: 'Italic',
              onPressed: () => _insertMarkdown('*', '*'),
            ),
            IconButton(
              icon: const Icon(Icons.format_strikethrough, size: 20),
              tooltip: 'Strikethrough',
              onPressed: () => _insertMarkdown('~~', '~~'),
            ),
            IconButton(
              icon: const Icon(Icons.title, size: 20),
              tooltip: 'Heading',
              onPressed: () => _insertAtLineStart('## '),
            ),
            IconButton(
              icon: const Icon(Icons.format_list_bulleted, size: 20),
              tooltip: 'Bullet List',
              onPressed: () => _insertAtLineStart('- '),
            ),
            IconButton(
              icon: const Icon(Icons.format_list_numbered, size: 20),
              tooltip: 'Numbered List',
              onPressed: () => _insertAtLineStart('1. '),
            ),
            IconButton(
              icon: const Icon(Icons.check_box_outlined, size: 20),
              tooltip: 'Checklist',
              onPressed: () => _insertAtLineStart('- [ ] '),
            ),
            IconButton(
              icon: const Icon(Icons.code, size: 20),
              tooltip: 'Code',
              onPressed: () => _insertMarkdown('`', '`'),
            ),
            IconButton(
              icon: const Icon(Icons.format_quote, size: 20),
              tooltip: 'Quote',
              onPressed: () => _insertAtLineStart('> '),
            ),
            IconButton(
              icon: const Icon(Icons.horizontal_rule, size: 20),
              tooltip: 'Divider',
              onPressed: () => _insertMarkdown('\n---\n'),
            ),
          ],
        ),
      ),
    );
  }
}
