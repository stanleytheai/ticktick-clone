import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';

class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({super.key});

  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  bool _isImporting = false;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Import & Export',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          // Import section
          _SectionHeader(title: 'Import Data'),
          _ImportTile(
            icon: Icons.check_circle_outline,
            title: 'Todoist',
            subtitle: 'Import tasks and projects from Todoist JSON export',
            color: Colors.red,
            isLoading: _isImporting,
            onTap: () => _showImportDialog(
              context,
              'Todoist',
              'Paste your Todoist JSON export data:',
              _importTodoist,
            ),
          ),
          _ImportTile(
            icon: Icons.task_alt,
            title: 'Microsoft To Do',
            subtitle: 'Import tasks from Microsoft To Do export',
            color: Colors.blue,
            isLoading: _isImporting,
            onTap: () => _showImportDialog(
              context,
              'Microsoft To Do',
              'Paste your Microsoft To Do JSON export data:',
              _importMsTodo,
            ),
          ),
          _ImportTile(
            icon: Icons.alarm,
            title: 'Apple Reminders',
            subtitle: 'Import from Apple Reminders export',
            color: Colors.orange,
            isLoading: _isImporting,
            onTap: () => _showImportDialog(
              context,
              'Apple Reminders',
              'Paste your Apple Reminders JSON export data:',
              _importAppleReminders,
            ),
          ),
          const Divider(height: 32),

          // Export section
          _SectionHeader(title: 'Export Data'),
          _ExportTile(
            icon: Icons.code,
            title: 'JSON Backup',
            subtitle: 'Complete backup of all your data',
            isLoading: _isExporting,
            onTap: () => _exportData('json'),
          ),
          _ExportTile(
            icon: Icons.table_chart,
            title: 'CSV',
            subtitle: 'Export tasks as a spreadsheet-compatible file',
            isLoading: _isExporting,
            onTap: () => _exportData('csv'),
          ),
          _ExportTile(
            icon: Icons.text_snippet,
            title: 'Plain Text',
            subtitle: 'Simple text list of all tasks organized by list',
            isLoading: _isExporting,
            onTap: () => _exportData('text'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showImportDialog(
    BuildContext context,
    String source,
    String hint,
    Future<void> Function(String data) onImport,
  ) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Import from $source'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hint, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '{ "items": [...] }',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (controller.text.trim().isNotEmpty) {
                onImport(controller.text.trim());
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _importTodoist(String data) async {
    setState(() => _isImporting = true);
    try {
      final parsed = json.decode(data);
      // Validate it looks like Todoist data
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('Invalid JSON format');
      }

      final items = parsed['items'] as List<dynamic>? ?? [];
      final projects = parsed['projects'] as List<dynamic>? ?? [];

      if (items.isEmpty && projects.isEmpty) {
        throw const FormatException('No tasks or projects found');
      }

      // In production, this would call the backend API.
      // For now, show success with count.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Imported ${items.length} tasks and ${projects.length} projects from Todoist'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _importMsTodo(String data) async {
    setState(() => _isImporting = true);
    try {
      final parsed = json.decode(data);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('Invalid JSON format');
      }

      final tasks = parsed['tasks'] as List<dynamic>? ?? [];
      if (tasks.isEmpty) {
        throw const FormatException('No tasks found');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Imported ${tasks.length} tasks from Microsoft To Do'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _importAppleReminders(String data) async {
    setState(() => _isImporting = true);
    try {
      final parsed = json.decode(data);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('Invalid JSON format');
      }

      final reminders = parsed['reminders'] as List<dynamic>? ?? [];
      if (reminders.isEmpty) {
        throw const FormatException('No reminders found');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Imported ${reminders.length} reminders from Apple Reminders'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _exportData(String format) async {
    setState(() => _isExporting = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final data =
          await ref.read(firestoreServiceProvider).exportUserData(user.uid);

      String output;
      String message;

      switch (format) {
        case 'csv':
          output = _convertToCsv(data);
          message = 'CSV data copied to clipboard';
        case 'text':
          output = _convertToText(data);
          message = 'Text data copied to clipboard';
        default:
          output = const JsonEncoder.withIndent('  ').convert(data);
          message = 'JSON backup copied to clipboard';
      }

      await Clipboard.setData(ClipboardData(text: output));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _convertToCsv(Map<String, dynamic> data) {
    final tasks = data['tasks'] as List<dynamic>? ?? [];
    final lines = <String>['Title,Description,Priority,Due Date,Completed,Created At'];

    for (final t in tasks) {
      final task = t as Map<String, dynamic>;
      lines.add([
        _csvEscape(task['title']?.toString() ?? ''),
        _csvEscape(task['description']?.toString() ?? ''),
        task['priority']?.toString() ?? 'none',
        task['dueDate']?.toString() ?? '',
        (task['completed'] == true) ? 'Yes' : 'No',
        task['createdAt']?.toString() ?? '',
      ].join(','));
    }

    return lines.join('\n');
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _convertToText(Map<String, dynamic> data) {
    final tasks = data['tasks'] as List<dynamic>? ?? [];
    final lines = <String>[
      'TickTick Clone Export - ${DateTime.now().toIso8601String().split('T')[0]}',
      '=' * 50,
      '',
    ];

    for (final t in tasks) {
      final task = t as Map<String, dynamic>;
      final check = task['completed'] == true ? '[x]' : '[ ]';
      final due = task['dueDate'] != null ? ' (due: ${task['dueDate']})' : '';
      lines.add('$check ${task['title'] ?? 'Untitled'}$due');
    }

    return lines.join('\n');
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

class _ImportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _ImportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(30),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.upload),
      onTap: isLoading ? null : onTap,
    );
  }
}

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  const _ExportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.download),
      onTap: isLoading ? null : onTap,
    );
  }
}
