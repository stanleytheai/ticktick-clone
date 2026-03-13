import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';

class ApiKeysScreen extends ConsumerStatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  ConsumerState<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends ConsumerState<ApiKeysScreen> {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _clientsRef(String uid) =>
      _db.collection('users').doc(uid).collection('oauthClients');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Text('API & OAuth',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(user.uid),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _clientsRef(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.api,
                              color: theme.colorScheme.onPrimaryContainer),
                          const SizedBox(width: 8),
                          Text('REST API',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use the REST API to integrate with third-party services. '
                        'Create OAuth 2.0 clients below to authenticate API requests.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Base URL: /api/v1',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text('OAuth Clients',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              if (docs.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.key_off,
                            size: 48, color: theme.colorScheme.outline),
                        const SizedBox(height: 8),
                        Text('No OAuth clients',
                            style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(
                          'Create a client to get API credentials.',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...docs.map((doc) {
                  final data = doc.data();
                  final name = data['name'] as String? ?? 'Unnamed';
                  final scopes = List<String>.from(data['scopes'] ?? []);
                  final createdAt = data['createdAt'] as String? ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      leading: const Icon(Icons.key),
                      title: Text(name),
                      subtitle: Text('${scopes.length} scope(s)'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InfoRow(label: 'Client ID', value: doc.id),
                              _InfoRow(
                                  label: 'Scopes',
                                  value: scopes.join(', ')),
                              _InfoRow(label: 'Created', value: createdAt.split('T')[0]),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => Clipboard.setData(
                                        ClipboardData(text: doc.id)),
                                    icon:
                                        const Icon(Icons.copy, size: 16),
                                    label: const Text('Copy ID'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _confirmDelete(doc.reference),
                                    icon: const Icon(Icons.delete_outline,
                                        size: 16),
                                    label: const Text('Revoke'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  void _showCreateDialog(String uid) {
    final nameController = TextEditingController();
    final redirectController = TextEditingController();
    final scopes = <String>{'tasks.read', 'tasks.write'};
    final allScopes = [
      'tasks.read',
      'tasks.write',
      'lists.read',
      'lists.write',
      'webhooks.manage',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create OAuth Client'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Client Name',
                    hintText: 'My Integration',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: redirectController,
                  decoration: const InputDecoration(
                    labelText: 'Redirect URI',
                    hintText: 'https://myapp.com/callback',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                const Text('Scopes:'),
                ...allScopes.map((s) => CheckboxListTile(
                      title: Text(s, style: const TextStyle(fontSize: 13)),
                      value: scopes.contains(s),
                      dense: true,
                      onChanged: (v) => setDialogState(() {
                        if (v == true) {
                          scopes.add(s);
                        } else {
                          scopes.remove(s);
                        }
                      }),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final redirect = redirectController.text.trim();
                if (name.isEmpty || scopes.isEmpty) return;

                final now = DateTime.now().toIso8601String();
                final secret = _generateSecret();
                await _clientsRef(uid).add({
                  'name': name,
                  'clientSecret': secret,
                  'redirectUris':
                      redirect.isNotEmpty ? [redirect] : <String>[],
                  'scopes': scopes.toList(),
                  'ownerId': uid,
                  'createdAt': now,
                  'updatedAt': now,
                });

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  // Show the secret once
                  _showSecretDialog(secret);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSecretDialog(String secret) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Client Secret'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Save this secret now. It will not be shown again.',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            SelectableText(
              secret,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: secret)),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(DocumentReference ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Client?'),
        content: const Text(
            'This will permanently revoke the client credentials. '
            'Any integrations using this client will stop working.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.delete();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }

  String _generateSecret() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(64, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          Expanded(
            child: SelectableText(value,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
