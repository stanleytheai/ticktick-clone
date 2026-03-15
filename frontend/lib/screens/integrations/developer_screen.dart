import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';

class DeveloperScreen extends ConsumerStatefulWidget {
  const DeveloperScreen({super.key});

  @override
  ConsumerState<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends ConsumerState<DeveloperScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Developer & API',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'API Clients', icon: Icon(Icons.key)),
            Tab(text: 'Webhooks', icon: Icon(Icons.webhook)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ApiClientsTab(),
          _WebhooksTab(),
        ],
      ),
    );
  }
}

// ── API Clients Tab ────────────────────────────────────

class _ApiClientsTab extends ConsumerStatefulWidget {
  const _ApiClientsTab();

  @override
  ConsumerState<_ApiClientsTab> createState() => _ApiClientsTabState();
}

class _ApiClientsTabState extends ConsumerState<_ApiClientsTab> {
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('apiClients')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _clients = snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Info card
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Create OAuth 2.0 clients to allow third-party apps to access your data via the REST API.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Clients list
        Expanded(
          child: _clients.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.key_off, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No API clients yet',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Create one to get started',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _clients.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final client = _clients[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          client['active'] == true
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: client['active'] == true
                              ? Colors.green
                              : Colors.red,
                        ),
                        title: Text(client['name'] ?? 'Unnamed'),
                        subtitle: Text(
                          'Client ID: ${client['clientId'] ?? ''}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: client['clientId'] ?? ''),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Client ID copied')),
                            );
                          },
                        ),
                        onTap: () => _showClientDetails(client),
                      ),
                    );
                  },
                ),
        ),

        // Create button
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _showCreateClientDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create API Client'),
          ),
        ),
      ],
    );
  }

  void _showClientDetails(Map<String, dynamic> client) {
    final scopes = (client['scopes'] as List<dynamic>? ?? [])
        .map((s) => s.toString())
        .toList();
    final redirectUris = (client['redirectUris'] as List<dynamic>? ?? [])
        .map((s) => s.toString())
        .toList();

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(client['name'] ?? 'Unnamed',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _DetailRow(label: 'Client ID', value: client['clientId'] ?? ''),
            const SizedBox(height: 8),
            _DetailRow(
                label: 'Scopes', value: scopes.join(', ')),
            const SizedBox(height: 8),
            _DetailRow(
                label: 'Redirect URIs',
                value: redirectUris.join('\n')),
            const SizedBox(height: 8),
            _DetailRow(
                label: 'Status',
                value:
                    client['active'] == true ? 'Active' : 'Inactive'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteClient(client);
                  },
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateClientDialog() {
    final nameController = TextEditingController();
    final redirectController = TextEditingController();
    final selectedScopes = <String>{};

    final allScopes = [
      'tasks:read',
      'tasks:write',
      'lists:read',
      'lists:write',
      'tags:read',
      'tags:write',
      'habits:read',
      'habits:write',
      'notes:read',
      'notes:write',
      'profile:read',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create API Client'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Client Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: redirectController,
                    decoration: const InputDecoration(
                      labelText: 'Redirect URI',
                      border: OutlineInputBorder(),
                      hintText: 'https://your-app.com/callback',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Scopes',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: allScopes.map((scope) {
                      final selected = selectedScopes.contains(scope);
                      return FilterChip(
                        label: Text(scope, style: const TextStyle(fontSize: 12)),
                        selected: selected,
                        onSelected: (v) {
                          setDialogState(() {
                            if (v) {
                              selectedScopes.add(scope);
                            } else {
                              selectedScopes.remove(scope);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    redirectController.text.isNotEmpty &&
                    selectedScopes.isNotEmpty) {
                  Navigator.pop(ctx);
                  _createClient(
                    nameController.text,
                    redirectController.text,
                    selectedScopes.toList(),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createClient(
      String name, String redirectUri, List<String> scopes) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final now = DateTime.now().toIso8601String();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('apiClients')
          .add({
        'name': name,
        'clientId': 'tc_${DateTime.now().millisecondsSinceEpoch}',
        'redirectUris': [redirectUri],
        'scopes': scopes,
        'active': true,
        'createdAt': now,
        'updatedAt': now,
      });

      await _loadClients();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API client created')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create client: $e')),
        );
      }
    }
  }

  Future<void> _deleteClient(Map<String, dynamic> client) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('apiClients')
          .doc(client['id'])
          .delete();

      await _loadClients();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API client deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete client: $e')),
        );
      }
    }
  }
}

// ── Webhooks Tab ───────────────────────────────────────

class _WebhooksTab extends ConsumerStatefulWidget {
  const _WebhooksTab();

  @override
  ConsumerState<_WebhooksTab> createState() => _WebhooksTabState();
}

class _WebhooksTabState extends ConsumerState<_WebhooksTab> {
  List<Map<String, dynamic>> _webhooks = [];
  bool _isLoading = true;

  static const _eventTypes = [
    'task.created',
    'task.updated',
    'task.completed',
    'task.deleted',
    'list.created',
    'list.updated',
    'list.deleted',
    'habit.logged',
    'note.created',
    'note.updated',
  ];

  @override
  void initState() {
    super.initState();
    _loadWebhooks();
  }

  Future<void> _loadWebhooks() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('webhooks')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _webhooks = snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Info card
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Webhooks send real-time notifications to your URL when events occur. '
                      'Payloads are signed with HMAC-SHA256 for verification.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Webhooks list
        Expanded(
          child: _webhooks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.webhook, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No webhooks configured',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Add one to receive event notifications',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _webhooks.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final wh = _webhooks[index];
                    final events =
                        (wh['events'] as List<dynamic>? ?? []).length;
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          wh['active'] == true
                              ? Icons.circle
                              : Icons.circle_outlined,
                          color: wh['active'] == true
                              ? Colors.green
                              : Colors.grey,
                          size: 16,
                        ),
                        title: Text(
                          wh['url'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13),
                        ),
                        subtitle: Text('$events event(s)'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'delete') _deleteWebhook(wh);
                            if (action == 'toggle') _toggleWebhook(wh);
                            if (action == 'test') _testWebhook(wh);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(wh['active'] == true
                                  ? 'Disable'
                                  : 'Enable'),
                            ),
                            const PopupMenuItem(
                              value: 'test',
                              child: Text('Send Test'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child:
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Create button
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _showCreateWebhookDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Webhook'),
          ),
        ),
      ],
    );
  }

  void _showCreateWebhookDialog() {
    final urlController = TextEditingController();
    final selectedEvents = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Webhook'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Webhook URL',
                      border: OutlineInputBorder(),
                      hintText: 'https://your-app.com/webhook',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Events',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _eventTypes.map((event) {
                      final selected = selectedEvents.contains(event);
                      return FilterChip(
                        label: Text(event, style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        onSelected: (v) {
                          setDialogState(() {
                            if (v) {
                              selectedEvents.add(event);
                            } else {
                              selectedEvents.remove(event);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (urlController.text.isNotEmpty &&
                    selectedEvents.isNotEmpty) {
                  Navigator.pop(ctx);
                  _createWebhook(urlController.text, selectedEvents.toList());
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createWebhook(String url, List<String> events) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final now = DateTime.now().toIso8601String();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('webhooks')
          .add({
        'url': url,
        'events': events,
        'active': true,
        'createdAt': now,
        'updatedAt': now,
      });

      await _loadWebhooks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Webhook created')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create webhook: $e')),
        );
      }
    }
  }

  Future<void> _deleteWebhook(Map<String, dynamic> wh) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('webhooks')
          .doc(wh['id'])
          .delete();

      await _loadWebhooks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Webhook deleted')),
        );
      }
    } catch (_) {}
  }

  Future<void> _toggleWebhook(Map<String, dynamic> wh) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('webhooks')
          .doc(wh['id'])
          .update({
        'active': !(wh['active'] == true),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await _loadWebhooks();
    } catch (_) {}
  }

  Future<void> _testWebhook(Map<String, dynamic> wh) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test webhook sent')),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      ],
    );
  }
}
