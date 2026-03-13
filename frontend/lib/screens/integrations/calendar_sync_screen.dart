import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';

class CalendarSyncScreen extends ConsumerStatefulWidget {
  const CalendarSyncScreen({super.key});

  @override
  ConsumerState<CalendarSyncScreen> createState() => _CalendarSyncScreenState();
}

class _CalendarSyncScreenState extends ConsumerState<CalendarSyncScreen> {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _syncsRef(String uid) =>
      _db.collection('users').doc(uid).collection('calendarSyncs');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar Sync',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _syncsRef(user.uid).snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Connected calendars
              if (docs.isNotEmpty) ...[
                Text('Connected Calendars',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...docs.map((doc) {
                  final data = doc.data();
                  final provider = data['provider'] as String? ?? 'unknown';
                  final enabled = data['syncEnabled'] as bool? ?? true;
                  final lastSync = data['lastSyncAt'] as String?;

                  return Card(
                    child: ListTile(
                      leading: Icon(_providerIcon(provider),
                          color: _providerColor(provider)),
                      title: Text(_providerLabel(provider)),
                      subtitle: Text(lastSync != null
                          ? 'Last sync: ${lastSync.split('T')[0]}'
                          : 'Never synced'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: enabled,
                            onChanged: (v) =>
                                doc.reference.update({'syncEnabled': v}),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmDisconnect(doc.reference),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],

              // Add calendar providers
              Text('Connect a Calendar',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Sync your tasks with external calendar services for two-way synchronization.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              _CalendarProviderCard(
                icon: Icons.event,
                title: 'Google Calendar',
                subtitle: 'Two-way sync with Google Calendar',
                color: const Color(0xFF4285F4),
                onConnect: () => _connectProvider(user.uid, 'google'),
              ),
              const SizedBox(height: 8),
              _CalendarProviderCard(
                icon: Icons.calendar_month,
                title: 'Outlook Calendar',
                subtitle: 'Sync with Microsoft Outlook',
                color: const Color(0xFF0078D4),
                onConnect: () => _connectProvider(user.uid, 'outlook'),
              ),
              const SizedBox(height: 8),
              _CalendarProviderCard(
                icon: Icons.apple,
                title: 'Apple Calendar',
                subtitle: 'Sync with Apple Calendar via CalDAV',
                color: const Color(0xFF555555),
                onConnect: () => _connectProvider(user.uid, 'apple'),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _providerIcon(String provider) {
    switch (provider) {
      case 'google':
        return Icons.event;
      case 'outlook':
        return Icons.calendar_month;
      case 'apple':
        return Icons.apple;
      default:
        return Icons.calendar_today;
    }
  }

  Color _providerColor(String provider) {
    switch (provider) {
      case 'google':
        return const Color(0xFF4285F4);
      case 'outlook':
        return const Color(0xFF0078D4);
      case 'apple':
        return const Color(0xFF555555);
      default:
        return Colors.grey;
    }
  }

  String _providerLabel(String provider) {
    switch (provider) {
      case 'google':
        return 'Google Calendar';
      case 'outlook':
        return 'Outlook Calendar';
      case 'apple':
        return 'Apple Calendar';
      default:
        return provider;
    }
  }

  Future<void> _connectProvider(String uid, String provider) async {
    // In a real app, this would initiate OAuth flow.
    // For now, create a placeholder sync config.
    final now = DateTime.now().toIso8601String();
    await _syncsRef(uid).add({
      'provider': provider,
      'calendarId': 'primary',
      'syncEnabled': true,
      'createdAt': now,
      'updatedAt': now,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${_providerLabel(provider)} connected')),
      );
    }
  }

  void _confirmDisconnect(DocumentReference ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Calendar?'),
        content: const Text(
            'This will stop syncing and remove synced events. Your tasks will not be affected.'),
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
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}

class _CalendarProviderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onConnect;

  const _CalendarProviderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: OutlinedButton(
          onPressed: onConnect,
          child: const Text('Connect'),
        ),
      ),
    );
  }
}
