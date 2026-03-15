import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/user_settings.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/settings_provider.dart';
import 'package:ticktick_clone/screens/settings/profile_screen.dart';
import 'package:ticktick_clone/providers/subscription_provider.dart';
import 'package:ticktick_clone/screens/subscription/paywall_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(userSettingsProvider);
    final subscription = ref.watch(subscriptionProvider);
    final isPremium = subscription.value?.isPremium ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          // Account section
          const _SectionHeader(title: 'Account'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage:
                  user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null
                  ? Text(
                      (user?.email?.substring(0, 1) ?? '?').toUpperCase(),
                      style:
                          TextStyle(color: theme.colorScheme.onPrimaryContainer),
                    )
                  : null,
            ),
            title: Text(user?.displayName ?? 'User'),
            subtitle: Text(user?.email ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          const Divider(),

          // Subscription section
          const _SectionHeader(title: 'Subscription'),
          ListTile(
            leading: Icon(
              isPremium ? Icons.workspace_premium : Icons.star_outline,
              color: isPremium ? Colors.amber : null,
            ),
            title: Text(isPremium ? 'Premium' : 'Free Plan'),
            subtitle: Text(isPremium
                ? 'Unlimited access to all features'
                : 'Upgrade for unlimited lists, tasks, and more'),
            trailing: isPremium
                ? Chip(
                    label: const Text('Active'),
                    backgroundColor: Colors.green.withAlpha(30),
                    labelStyle: const TextStyle(color: Colors.green),
                    side: BorderSide.none,
                  )
                : FilledButton.tonal(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PaywallScreen()),
                    ),
                    child: const Text('Upgrade'),
                  ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaywallScreen()),
            ),
          ),
          const Divider(),

          // Appearance section
          const _SectionHeader(title: 'Appearance'),
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
              onSelectionChanged: (s) {
                ref.read(themeModeProvider.notifier).setThemeMode(s.first);
                _updateSetting(ref, settings,
                    theme: s.first.name);
              },
              showSelectedIcon: false,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('Font Size'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'small', label: Text('S')),
                ButtonSegment(value: 'medium', label: Text('M')),
                ButtonSegment(value: 'large', label: Text('L')),
              ],
              selected: {settings.fontSize},
              onSelectionChanged: (s) =>
                  _updateSetting(ref, settings, fontSize: s.first),
              showSelectedIcon: false,
            ),
          ),
          const Divider(),

          // General section
          const _SectionHeader(title: 'General'),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Week Starts On'),
            trailing: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Sun')),
                ButtonSegment(value: 1, label: Text('Mon')),
              ],
              selected: {settings.weekStartDay},
              onSelectionChanged: (s) =>
                  _updateSetting(ref, settings, weekStartDay: s.first),
              showSelectedIcon: false,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('Date Format'),
            trailing: DropdownButton<String>(
              value: settings.dateFormat,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(
                    value: 'MMM d, yyyy', child: Text('Mar 13, 2026')),
                DropdownMenuItem(
                    value: 'dd/MM/yyyy', child: Text('13/03/2026')),
                DropdownMenuItem(
                    value: 'yyyy-MM-dd', child: Text('2026-03-13')),
                DropdownMenuItem(
                    value: 'MM/dd/yyyy', child: Text('03/13/2026')),
              ],
              onChanged: (v) {
                if (v != null) _updateSetting(ref, settings, dateFormat: v);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Time Format'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '12h', label: Text('12h')),
                ButtonSegment(value: '24h', label: Text('24h')),
              ],
              selected: {settings.timeFormat},
              onSelectionChanged: (s) =>
                  _updateSetting(ref, settings, timeFormat: s.first),
              showSelectedIcon: false,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('Default List'),
            subtitle: Text(settings.defaultListId ?? 'Inbox'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDefaultListPicker(context, ref, settings),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Default Reminder'),
            subtitle: Text(_reminderLabel(settings.defaultReminderMinutes)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showReminderPicker(context, ref, settings),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            trailing: DropdownButton<String>(
              value: settings.language,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'es', child: Text('Español')),
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                DropdownMenuItem(value: 'ja', child: Text('日本語')),
                DropdownMenuItem(value: 'zh', child: Text('中文')),
                DropdownMenuItem(value: 'pt', child: Text('Português')),
                DropdownMenuItem(value: 'ko', child: Text('한국어')),
              ],
              onChanged: (v) {
                if (v != null) _updateSetting(ref, settings, language: v);
              },
            ),
          ),
          const Divider(),

          // Notifications section
          const _SectionHeader(title: 'Notifications & Sound'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            value: settings.notificationsEnabled,
            onChanged: (v) =>
                _updateSetting(ref, settings, notificationsEnabled: v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up),
            title: const Text('Sound'),
            value: settings.soundEnabled,
            onChanged: (v) =>
                _updateSetting(ref, settings, soundEnabled: v),
          ),
          const Divider(),

          // Quiet Hours / Do Not Disturb
          const _SectionHeader(title: 'Quiet Hours'),
          SwitchListTile(
            secondary: const Icon(Icons.do_not_disturb_on),
            title: const Text('Do Not Disturb'),
            subtitle: Text(settings.quietHoursEnabled
                ? '${settings.quietHoursStart} – ${settings.quietHoursEnd}'
                : 'No notifications during quiet hours'),
            value: settings.quietHoursEnabled,
            onChanged: (v) =>
                _updateSetting(ref, settings, quietHoursEnabled: v),
          ),
          if (settings.quietHoursEnabled) ...[
            ListTile(
              leading: const Icon(Icons.nightlight_round),
              title: const Text('Start Time'),
              trailing: Text(settings.quietHoursStart,
                  style: TextStyle(color: theme.colorScheme.primary)),
              onTap: () => _pickQuietHourTime(
                  context, ref, settings, isStart: true),
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('End Time'),
              trailing: Text(settings.quietHoursEnd,
                  style: TextStyle(color: theme.colorScheme.primary)),
              onTap: () => _pickQuietHourTime(
                  context, ref, settings, isStart: false),
            ),
          ],
          const Divider(),

          // Data section
          const _SectionHeader(title: 'Data'),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export Data'),
            subtitle: const Text('Download all your data as JSON'),
            onTap: () => _exportData(context, ref),
          ),
          const Divider(),

          // About section
          const _SectionHeader(title: 'About'),
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

  void _updateSetting(
    WidgetRef ref,
    UserSettings current, {
    String? theme,
    String? fontSize,
    String? defaultListId,
    int? defaultReminderMinutes,
    int? weekStartDay,
    String? dateFormat,
    String? timeFormat,
    String? language,
    bool? soundEnabled,
    bool? notificationsEnabled,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final updated = current.copyWith(
      theme: theme,
      fontSize: fontSize,
      defaultListId: defaultListId,
      defaultReminderMinutes: defaultReminderMinutes,
      weekStartDay: weekStartDay,
      dateFormat: dateFormat,
      timeFormat: timeFormat,
      language: language,
      soundEnabled: soundEnabled,
      notificationsEnabled: notificationsEnabled,
      quietHoursEnabled: quietHoursEnabled,
      quietHoursStart: quietHoursStart,
      quietHoursEnd: quietHoursEnd,
    );

    ref.read(firestoreServiceProvider).updateSettings(user.uid, updated);
  }

  void _pickQuietHourTime(
    BuildContext context,
    WidgetRef ref,
    UserSettings settings, {
    required bool isStart,
  }) async {
    final current = isStart ? settings.quietHoursStart : settings.quietHoursEnd;
    final parts = current.split(':').map(int.parse).toList();
    final initialTime = TimeOfDay(hour: parts[0], minute: parts[1]);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked == null) return;

    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

    if (isStart) {
      _updateSetting(ref, settings, quietHoursStart: formatted);
    } else {
      _updateSetting(ref, settings, quietHoursEnd: formatted);
    }
  }

  String _reminderLabel(int minutes) {
    if (minutes == 0) return 'None';
    if (minutes < 60) return '$minutes minutes before';
    if (minutes == 60) return '1 hour before';
    if (minutes < 1440) return '${minutes ~/ 60} hours before';
    if (minutes == 1440) return '1 day before';
    return '${minutes ~/ 1440} days before';
  }

  void _showDefaultListPicker(
      BuildContext context, WidgetRef ref, UserSettings settings) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final listsAsync = ref.read(firestoreServiceProvider).watchLists(user.uid);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => StreamBuilder(
        stream: listsAsync,
        builder: (context, snapshot) {
          final lists = snapshot.data ?? [];
          return ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Select Default List',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              ...lists.map((list) => ListTile(
                    title: Text(list.name),
                    trailing: settings.defaultListId == list.id
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () {
                      _updateSetting(ref, settings, defaultListId: list.id);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          );
        },
      ),
    );
  }

  void _showReminderPicker(
      BuildContext context, WidgetRef ref, UserSettings settings) {
    final options = [
      (0, 'None'),
      (5, '5 minutes before'),
      (10, '10 minutes before'),
      (15, '15 minutes before'),
      (30, '30 minutes before'),
      (60, '1 hour before'),
      (120, '2 hours before'),
      (1440, '1 day before'),
      (2880, '2 days before'),
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Default Reminder',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          ...options.map((opt) => ListTile(
                title: Text(opt.$2),
                trailing: settings.defaultReminderMinutes == opt.$1
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  _updateSetting(ref, settings,
                      defaultReminderMinutes: opt.$1);
                  Navigator.pop(ctx);
                },
              )),
        ],
      ),
    );
  }

  void _exportData(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final data =
          await ref.read(firestoreServiceProvider).exportUserData(user.uid);
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      if (context.mounted) {
        Navigator.pop(context); // dismiss loading
        await Clipboard.setData(ClipboardData(text: jsonString));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data exported and copied to clipboard')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
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
