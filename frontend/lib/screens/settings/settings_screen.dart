import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/settings_provider.dart';
import 'package:ticktick_clone/screens/integrations/import_screen.dart';
import 'package:ticktick_clone/screens/integrations/export_screen.dart';
import 'package:ticktick_clone/screens/integrations/webhooks_screen.dart';
import 'package:ticktick_clone/screens/integrations/calendar_sync_screen.dart';
import 'package:ticktick_clone/screens/integrations/api_keys_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          // Account section
          _SectionHeader(title: 'Account'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                (user?.email?.substring(0, 1) ?? '?').toUpperCase(),
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            title: Text(user?.displayName ?? 'User'),
            subtitle: Text(user?.email ?? ''),
          ),
          const Divider(),

          // Theme section
          _SectionHeader(title: 'Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode, size: 18)),
                ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.settings_brightness, size: 18)),
                ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode, size: 18)),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).setThemeMode(s.first),
              showSelectedIcon: false,
            ),
          ),
          const Divider(),

          // Data section
          _SectionHeader(title: 'Data'),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Import Tasks'),
            subtitle: const Text('From Todoist, Microsoft To Do, Apple Reminders'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ImportScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export Data'),
            subtitle: const Text('CSV, JSON, or text backup'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExportScreen()),
            ),
          ),
          const Divider(),

          // Integrations section
          _SectionHeader(title: 'Integrations'),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Calendar Sync'),
            subtitle: const Text('Google, Outlook, Apple Calendar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalendarSyncScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.webhook_outlined),
            title: const Text('Webhooks'),
            subtitle: const Text('Real-time event notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WebhooksScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.api_outlined),
            title: const Text('API & OAuth'),
            subtitle: const Text('REST API access for third-party apps'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ApiKeysScreen()),
            ),
          ),
          const Divider(),

          // About section
          _SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outlined),
            title: const Text('Version'),
            trailing: Text('1.0.0',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          const Divider(),

          // Sign out
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
          ),
        ],
      ),
    );
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
