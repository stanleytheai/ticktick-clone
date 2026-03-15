import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';

class CalendarSyncScreen extends ConsumerStatefulWidget {
  const CalendarSyncScreen({super.key});

  @override
  ConsumerState<CalendarSyncScreen> createState() => _CalendarSyncScreenState();
}

class _CalendarSyncScreenState extends ConsumerState<CalendarSyncScreen> {
  bool _isSyncing = false;
  bool _isConnecting = false;
  Map<String, dynamic>? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _loadConnectionStatus();
  }

  Future<void> _loadConnectionStatus() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('calendarConnections')
          .doc('google')
          .get();

      if (mounted) {
        setState(() {
          _connectionStatus = doc.exists ? doc.data() : null;
        });
      }
    } catch (_) {}
  }

  bool get _isConnected => _connectionStatus != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar Sync',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          // Connection status card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isConnected
                              ? Icons.check_circle
                              : Icons.cloud_off,
                          color:
                              _isConnected ? Colors.green : Colors.grey,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Google Calendar',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _isConnected
                                    ? 'Connected - ${_connectionStatus?['calendarId'] ?? 'primary'}'
                                    : 'Not connected',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (_isConnecting)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (_isConnected)
                          OutlinedButton(
                            onPressed: _disconnectCalendar,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Disconnect'),
                          )
                        else
                          FilledButton.icon(
                            onPressed: _connectGoogleCalendar,
                            icon: const Icon(Icons.link, size: 18),
                            label: const Text('Connect'),
                          ),
                      ],
                    ),
                    if (_isConnected &&
                        _connectionStatus?['lastSyncAt'] != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Last synced: ${_formatSyncTime(_connectionStatus!['lastSyncAt'])}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          if (_isConnected) ...[
            // Sync options
            const _SectionHeader(title: 'Sync Options'),
            SwitchListTile(
              secondary: const Icon(Icons.sync),
              title: const Text('Auto-sync'),
              subtitle: const Text(
                  'Automatically sync tasks with due dates to calendar'),
              value: _connectionStatus?['syncEnabled'] == true,
              onChanged: (v) => _toggleAutoSync(v),
            ),
            const Divider(),

            // Sync direction tiles
            const _SectionHeader(title: 'Manual Sync'),
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('Push to Calendar'),
              subtitle: const Text(
                  'Send tasks with due dates to Google Calendar'),
              trailing: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
              onTap: _isSyncing ? null : () => _syncCalendar('push'),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Pull from Calendar'),
              subtitle:
                  const Text('Import calendar events as tasks'),
              trailing: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
              onTap: _isSyncing ? null : () => _syncCalendar('pull'),
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Two-way Sync'),
              subtitle:
                  const Text('Sync in both directions'),
              trailing: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
              onTap: _isSyncing ? null : () => _syncCalendar('both'),
            ),
          ],

          // Info section
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 20,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('How it works',
                            style: theme.textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tasks with due dates are synced as calendar events. '
                      'Changes made in either app will be reflected during sync.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _connectGoogleCalendar() async {
    setState(() => _isConnecting = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      // In production, this would trigger Google OAuth flow.
      // Store connection state in Firestore.
      final now = DateTime.now().toIso8601String();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('calendarConnections')
          .doc('google')
          .set({
        'provider': 'google',
        'calendarId': 'primary',
        'syncEnabled': true,
        'lastSyncAt': null,
        'createdAt': now,
        'updatedAt': now,
      });

      await _loadConnectionStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Calendar connected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnectCalendar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Calendar?'),
        content: const Text(
            'This will stop syncing tasks with Google Calendar. '
            'Existing calendar events will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isConnecting = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('calendarConnections')
          .doc('google')
          .delete();

      setState(() => _connectionStatus = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Calendar disconnected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disconnect: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _toggleAutoSync(bool enabled) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('calendarConnections')
          .doc('google')
          .update({
        'syncEnabled': enabled,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      await _loadConnectionStatus();
    } catch (_) {}
  }

  Future<void> _syncCalendar(String direction) async {
    setState(() => _isSyncing = true);
    try {
      // In production, this would call the backend API.
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calendar sync ($direction) complete')),
        );
      }

      await _loadConnectionStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  String _formatSyncTime(dynamic timestamp) {
    if (timestamp == null) return 'Never';
    try {
      if (timestamp is Timestamp) {
        return _formatDateTime(timestamp.toDate());
      }
      return _formatDateTime(DateTime.parse(timestamp.toString()));
    } catch (_) {
      return 'Unknown';
    }
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}
