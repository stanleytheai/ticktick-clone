import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/import_export_provider.dart';
import 'package:ticktick_clone/providers/list_provider.dart';
import 'package:ticktick_clone/services/import_export_service.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportFormat _selectedFormat = ExportFormat.json;
  bool _includeCompleted = true;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lists = ref.watch(listsStreamProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Export Data',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Choose export format:', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),

          SegmentedButton<ExportFormat>(
            segments: const [
              ButtonSegment(
                value: ExportFormat.json,
                label: Text('JSON'),
                icon: Icon(Icons.data_object, size: 18),
              ),
              ButtonSegment(
                value: ExportFormat.csv,
                label: Text('CSV'),
                icon: Icon(Icons.table_chart, size: 18),
              ),
              ButtonSegment(
                value: ExportFormat.text,
                label: Text('Text'),
                icon: Icon(Icons.text_snippet, size: 18),
              ),
            ],
            selected: {_selectedFormat},
            onSelectionChanged: (s) =>
                setState(() => _selectedFormat = s.first),
          ),

          const SizedBox(height: 24),

          // Options
          SwitchListTile(
            title: const Text('Include completed tasks'),
            value: _includeCompleted,
            onChanged: (v) => setState(() => _includeCompleted = v),
          ),

          const Divider(),
          const SizedBox(height: 8),

          Text('Your lists (${lists.length}):',
              style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text('All lists will be included in the export.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _isExporting ? null : _export,
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download),
            label: Text(_isExporting ? 'Exporting...' : 'Export & Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isExporting = true);

    try {
      final data = await ref.read(importExportServiceProvider).exportData(
            user.uid,
            _selectedFormat,
            includeCompleted: _includeCompleted,
          );

      // Write to temp file and share
      final dir = await getTemporaryDirectory();
      String ext;
      switch (_selectedFormat) {
        case ExportFormat.csv:
          ext = 'csv';
        case ExportFormat.json:
          ext = 'json';
        case ExportFormat.text:
          ext = 'txt';
      }
      final file = File('${dir.path}/ticktick-export.$ext');
      await file.writeAsString(data);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'TickTick Export',
        ),
      );
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
}
