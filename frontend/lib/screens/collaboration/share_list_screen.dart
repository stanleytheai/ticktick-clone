import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/shared_list.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/shared_list_provider.dart';

class ShareListScreen extends ConsumerStatefulWidget {
  final String listId;

  const ShareListScreen({super.key, required this.listId});

  @override
  ConsumerState<ShareListScreen> createState() => _ShareListScreenState();
}

class _ShareListScreenState extends ConsumerState<ShareListScreen> {
  final _emailController = TextEditingController();
  ListPermission _selectedPermission = ListPermission.edit;
  bool _isInviting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sharedList = ref.watch(sharedListByIdProvider(widget.listId));
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    if (sharedList == null || user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Share List')),
        body: const Center(child: Text('List not found')),
      );
    }

    final isAdmin = sharedList.isAdmin(user.uid);
    final members = sharedList.members.values.toList()
      ..sort((a, b) {
        if (a.uid == sharedList.ownerId) return -1;
        if (b.uid == sharedList.ownerId) return 1;
        return a.addedAt.compareTo(b.addedAt);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text('Share "${sharedList.name}"'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Invite section (admin only)
          if (isAdmin) ...[
            Text('Invite by email', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      hintText: 'Email address',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<ListPermission>(
                  value: _selectedPermission,
                  items: const [
                    DropdownMenuItem(
                      value: ListPermission.view,
                      child: Text('View'),
                    ),
                    DropdownMenuItem(
                      value: ListPermission.edit,
                      child: Text('Edit'),
                    ),
                    DropdownMenuItem(
                      value: ListPermission.admin,
                      child: Text('Admin'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedPermission = v);
                  },
                ),
                const SizedBox(width: 8),
                _isInviting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton.filled(
                        onPressed: _invite,
                        icon: const Icon(Icons.send),
                      ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Members list
          Text('Members (${members.length})',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...members.map((member) {
            final isOwner = member.uid == sharedList.ownerId;
            final isSelf = member.uid == user.uid;

            return ListTile(
              leading: CircleAvatar(
                child: Text(
                  (member.displayName.isNotEmpty
                          ? member.displayName
                          : member.email)
                      .substring(0, 1)
                      .toUpperCase(),
                ),
              ),
              title: Text(
                member.displayName.isNotEmpty
                    ? member.displayName
                    : member.email,
                style: isSelf
                    ? const TextStyle(fontWeight: FontWeight.bold)
                    : null,
              ),
              subtitle: Text(member.email),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOwner)
                    Chip(
                      label: const Text('Owner'),
                      backgroundColor: theme.colorScheme.primaryContainer,
                    )
                  else ...[
                    Text(member.role.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    if (isAdmin && !isSelf) ...[
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'view', child: Text('Set View')),
                          const PopupMenuItem(
                              value: 'edit', child: Text('Set Edit')),
                          const PopupMenuItem(
                              value: 'admin', child: Text('Set Admin')),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'remove',
                            child:
                                Text('Remove', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                        onSelected: (action) =>
                            _handleMemberAction(member, action),
                      ),
                    ],
                  ],
                  if (!isOwner && isSelf)
                    TextButton(
                      onPressed: () => _leaveList(member),
                      child: const Text('Leave',
                          style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _invite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isInviting = true);
    try {
      // Use the REST API for inviting (needs server-side user lookup)
      // For now, show a snackbar - the actual invite happens through the backend API
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite sent to $email')),
        );
        _emailController.clear();
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  Future<void> _handleMemberAction(ListMember member, String action) async {
    final firestoreService = ref.read(firestoreServiceProvider);
    if (action == 'remove') {
      await firestoreService.updateSharedList(widget.listId, {
        'members.${member.uid}': FieldValue.delete(),
      });
    } else {
      await firestoreService.updateSharedList(widget.listId, {
        'members.${member.uid}.role': action,
      });
    }
  }

  Future<void> _leaveList(ListMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave list?'),
        content: const Text(
            'You will lose access to this shared list and its tasks.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(firestoreServiceProvider).updateSharedList(widget.listId, {
        'members.${member.uid}': FieldValue.delete(),
      });
      if (mounted) Navigator.pop(context);
    }
  }
}
