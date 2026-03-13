import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:ticktick_clone/models/comment.dart';
import 'package:ticktick_clone/models/shared_list.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/shared_list_provider.dart';

class CommentThreadScreen extends ConsumerStatefulWidget {
  final String listId;
  final String taskId;
  final String taskTitle;
  final Map<String, ListMember> members;

  const CommentThreadScreen({
    super.key,
    required this.listId,
    required this.taskId,
    required this.taskTitle,
    required this.members,
  });

  @override
  ConsumerState<CommentThreadScreen> createState() =>
      _CommentThreadScreenState();
}

class _CommentThreadScreenState extends ConsumerState<CommentThreadScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _showMentionSuggestions = false;
  String _mentionQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(
        (listId: widget.listId, taskId: widget.taskId)));
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Comments', style: TextStyle(fontSize: 16)),
            Text(widget.taskTitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: commentsAsync.when(
              data: (comments) {
                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No comments yet',
                            style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) => _CommentBubble(
                    comment: comments[index],
                    isOwn: comments[index].authorId == user?.uid,
                    members: widget.members,
                    onDelete: () => _deleteComment(comments[index]),
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),

          // Mention suggestions
          if (_showMentionSuggestions) _buildMentionSuggestions(),

          // Input area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.alternate_email),
                    onPressed: _insertAtSymbol,
                    tooltip: 'Mention someone',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onChanged: _onTextChanged,
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sendComment,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMentionSuggestions() {
    final filteredMembers = widget.members.values
        .where((m) {
          final query = _mentionQuery.toLowerCase();
          return m.displayName.toLowerCase().contains(query) ||
              m.email.toLowerCase().contains(query);
        })
        .toList();

    if (filteredMembers.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: filteredMembers.length,
        itemBuilder: (context, index) {
          final member = filteredMembers[index];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              child: Text(
                (member.displayName.isNotEmpty
                        ? member.displayName
                        : member.email)
                    .substring(0, 1)
                    .toUpperCase(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            title: Text(member.displayName.isNotEmpty
                ? member.displayName
                : member.email),
            onTap: () => _insertMention(member),
          );
        },
      ),
    );
  }

  void _onTextChanged(String text) {
    // Check for @ mentions
    final cursorPos = _controller.selection.baseOffset;
    if (cursorPos <= 0) {
      setState(() => _showMentionSuggestions = false);
      return;
    }

    final textBeforeCursor = text.substring(0, cursorPos);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex >= 0) {
      final query = textBeforeCursor.substring(lastAtIndex + 1);
      if (!query.contains(' ')) {
        setState(() {
          _showMentionSuggestions = true;
          _mentionQuery = query;
        });
        return;
      }
    }
    setState(() => _showMentionSuggestions = false);
  }

  void _insertAtSymbol() {
    final text = _controller.text;
    final selection = _controller.selection;
    final newText =
        text.replaceRange(selection.start, selection.end, '@');
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + 1),
    );
    setState(() {
      _showMentionSuggestions = true;
      _mentionQuery = '';
    });
  }

  void _insertMention(ListMember member) {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPos);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');
    final textAfterCursor = text.substring(cursorPos);

    final mentionName =
        member.displayName.isNotEmpty ? member.displayName : member.email;
    final newText =
        '${text.substring(0, lastAtIndex)}@$mentionName $textAfterCursor';
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset: lastAtIndex + mentionName.length + 2),
    );
    setState(() => _showMentionSuggestions = false);
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Extract mentions from text
    final mentionRegex = RegExp(r'@(\S+)');
    final mentions = <String>[];
    for (final match in mentionRegex.allMatches(text)) {
      final mentionName = match.group(1)!;
      for (final member in widget.members.values) {
        if (member.displayName == mentionName ||
            member.email == mentionName) {
          mentions.add(member.uid);
          break;
        }
      }
    }

    final comment = Comment(
      id: const Uuid().v4(),
      text: text,
      authorId: user.uid,
      authorName: user.displayName ?? user.email ?? '',
      mentions: mentions,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ref
        .read(firestoreServiceProvider)
        .addComment(widget.listId, widget.taskId, comment);

    _controller.clear();
    setState(() => _showMentionSuggestions = false);

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _deleteComment(Comment comment) async {
    await ref
        .read(firestoreServiceProvider)
        .deleteComment(widget.listId, widget.taskId, comment.id);
  }
}

class _CommentBubble extends StatelessWidget {
  final Comment comment;
  final bool isOwn;
  final Map<String, ListMember> members;
  final VoidCallback onDelete;

  const _CommentBubble({
    required this.comment,
    required this.isOwn,
    required this.members,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.MMMd().add_jm();

    // Highlight @mentions in text
    final styledText = _buildMentionText(comment.text, theme);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            child: Text(
              (comment.authorName.isNotEmpty ? comment.authorName : '?')
                  .substring(0, 1)
                  .toUpperCase(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName.isNotEmpty
                          ? comment.authorName
                          : 'Unknown',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(dateFormat.format(comment.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isOwn
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: styledText,
                ),
              ],
            ),
          ),
          if (isOwn)
            IconButton(
              icon: Icon(Icons.close, size: 16,
                  color: theme.colorScheme.outline),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }

  Widget _buildMentionText(String text, ThemeData theme) {
    final mentionRegex = RegExp(r'@(\S+)');
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in mentionRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium,
        children: spans,
      ),
    );
  }
}
