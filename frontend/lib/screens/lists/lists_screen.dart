import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:ticktick_clone/models/task_list.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/list_provider.dart';
import 'package:ticktick_clone/providers/subscription_provider.dart';
import 'package:ticktick_clone/providers/task_provider.dart';
import 'package:ticktick_clone/screens/tasks/task_list_screen.dart';
import 'package:ticktick_clone/widgets/upgrade_prompt.dart';

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(listsStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Lists',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: listsAsync.when(
        data: (lists) {
          if (lists.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.list_alt,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No lists yet',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showCreateDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create List'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              final taskCount = ref
                  .watch(tasksByListProvider(list.id))
                  .where((t) => !t.isCompleted)
                  .length;
              return ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(list.colorValue).withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.list, color: Color(list.colorValue), size: 18),
                ),
                title: Text(list.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (taskCount > 0)
                      Text('$taskCount',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TaskListScreen(listId: list.id, title: list.name),
                  ),
                ),
                onLongPress: () => _showEditDialog(context, ref, list),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    // Check list limit
    final limits = ref.read(tierLimitsProvider);
    final lists = ref.read(listsStreamProvider).value ?? [];
    if (limits.maxLists != null && lists.length >= limits.maxLists!) {
      UpgradePromptDialog.show(
        context,
        feature: 'lists',
        currentCount: lists.length,
        limit: limits.maxLists!,
      );
      return;
    }

    final nameController = TextEditingController();
    int selectedColor = 0xFF2196F3;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New List'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'List name'),
              ),
              const SizedBox(height: 16),
              _ColorPicker(
                selectedColor: selectedColor,
                onColorSelected: (c) =>
                    setDialogState(() => selectedColor = c),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                final list = TaskList(
                  id: const Uuid().v4(),
                  name: name,
                  colorValue: selectedColor,
                  userId: user.uid,
                  createdAt: DateTime.now(),
                );
                ref.read(firestoreServiceProvider).addList(user.uid, list);
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, TaskList list) {
    final nameController = TextEditingController(text: list.name);
    int selectedColor = list.colorValue;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit List'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'List name'),
              ),
              const SizedBox(height: 16),
              _ColorPicker(
                selectedColor: selectedColor,
                onColorSelected: (c) =>
                    setDialogState(() => selectedColor = c),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                ref
                    .read(firestoreServiceProvider)
                    .deleteList(user.uid, list.id);
                Navigator.pop(ctx);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                ref.read(firestoreServiceProvider).updateList(
                      user.uid,
                      list.copyWith(name: name, colorValue: selectedColor),
                    );
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final int selectedColor;
  final ValueChanged<int> onColorSelected;

  const _ColorPicker({
    required this.selectedColor,
    required this.onColorSelected,
  });

  static const colors = [
    0xFFF44336, 0xFFE91E63, 0xFF9C27B0, 0xFF673AB7,
    0xFF3F51B5, 0xFF2196F3, 0xFF03A9F4, 0xFF00BCD4,
    0xFF009688, 0xFF4CAF50, 0xFF8BC34A, 0xFFCDDC39,
    0xFFFFEB3B, 0xFFFFC107, 0xFFFF9800, 0xFFFF5722,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors
          .map((c) => GestureDetector(
                onTap: () => onColorSelected(c),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: selectedColor == c
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 3)
                        : null,
                  ),
                ),
              ))
          .toList(),
    );
  }
}
