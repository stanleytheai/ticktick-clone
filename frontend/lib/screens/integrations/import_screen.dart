import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/import_export_provider.dart';
import 'package:ticktick_clone/services/import_export_service.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  ImportSource? _selectedSource;
  bool _isImporting = false;
  ImportResult? _result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Import Tasks',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Select a source to import tasks from:',
              style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),

          _SourceCard(
            icon: Icons.check_circle_outline,
            title: 'Todoist',
            subtitle: 'Import from Todoist CSV export',
            selected: _selectedSource == ImportSource.todoist,
            onTap: () => setState(() => _selectedSource = ImportSource.todoist),
          ),
          const SizedBox(height: 8),
          _SourceCard(
            icon: Icons.task_outlined,
            title: 'Microsoft To Do',
            subtitle: 'Import from Microsoft To Do export (JSON or text)',
            selected: _selectedSource == ImportSource.microsoftTodo,
            onTap: () =>
                setState(() => _selectedSource = ImportSource.microsoftTodo),
          ),
          const SizedBox(height: 8),
          _SourceCard(
            icon: Icons.apple,
            title: 'Apple Reminders',
            subtitle: 'Import from Apple Reminders ICS export',
            selected: _selectedSource == ImportSource.appleReminders,
            onTap: () =>
                setState(() => _selectedSource = ImportSource.appleReminders),
          ),

          const SizedBox(height: 24),

          if (_selectedSource != null)
            FilledButton.icon(
              onPressed: _isImporting ? null : _pickAndImport,
              icon: _isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_upload_outlined),
              label: Text(_isImporting ? 'Importing...' : 'Choose File'),
            ),

          if (_result != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Import Complete',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Tasks imported: ${_result!.tasksImported}'),
                    Text('Lists created: ${_result!.listsCreated}'),
                    if (_result!.errors.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Warnings:',
                          style: TextStyle(color: theme.colorScheme.error)),
                      ...(_result!.errors.take(5).map((e) => Text(
                            '  - $e',
                            style:
                                TextStyle(color: theme.colorScheme.error, fontSize: 12),
                          ))),
                      if (_result!.errors.length > 5)
                        Text(
                          '  ... and ${_result!.errors.length - 5} more',
                          style: TextStyle(
                              color: theme.colorScheme.error, fontSize: 12),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndImport() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json', 'txt', 'ics'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    final data = String.fromCharCodes(bytes);

    setState(() {
      _isImporting = true;
      _result = null;
    });

    try {
      final importResult = await ref
          .read(importExportServiceProvider)
          .importData(user.uid, _selectedSource!, data);
      setState(() => _result = importResult);
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
}

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: selected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon,
                  size: 32,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
