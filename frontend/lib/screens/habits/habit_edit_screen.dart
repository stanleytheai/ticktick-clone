import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:ticktick_clone/models/habit.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';

class HabitEditScreen extends ConsumerStatefulWidget {
  final Habit? habit;

  const HabitEditScreen({super.key, this.habit});

  @override
  ConsumerState<HabitEditScreen> createState() => _HabitEditScreenState();
}

class _HabitEditScreenState extends ConsumerState<HabitEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _iconController;
  late TextEditingController _goalCountController;
  late HabitFrequency _frequency;
  late HabitGoalType _goalType;
  late HabitSection _section;
  late List<int> _frequencyDays;

  bool get _isEditing => widget.habit != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.habit?.name ?? '');
    _iconController = TextEditingController(text: widget.habit?.icon ?? '');
    _goalCountController = TextEditingController(
        text: widget.habit?.goalCount?.toString() ?? '');
    _frequency = widget.habit?.frequency ?? HabitFrequency.daily;
    _goalType = widget.habit?.goalType ?? HabitGoalType.yesNo;
    _section = widget.habit?.section ?? HabitSection.anytime;
    _frequencyDays = List.from(widget.habit?.frequencyDays ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    _goalCountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final now = DateTime.now();
    final habit = Habit(
      id: widget.habit?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      icon: _iconController.text.trim().isEmpty
          ? null
          : _iconController.text.trim(),
      frequency: _frequency,
      frequencyDays: _frequencyDays,
      goalType: _goalType,
      goalCount: _goalType == HabitGoalType.count
          ? int.tryParse(_goalCountController.text)
          : null,
      section: _section,
      sortOrder: widget.habit?.sortOrder ?? 0,
      archived: false,
      createdAt: widget.habit?.createdAt ?? now,
      updatedAt: now,
    );

    final service = ref.read(firestoreServiceProvider);
    if (_isEditing) {
      await service.updateHabit(user.uid, habit);
    } else {
      await service.addHabit(user.uid, habit);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Habit' : 'New Habit'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Habit Name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
              autofocus: !_isEditing,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _iconController,
              decoration: const InputDecoration(
                labelText: 'Icon (emoji)',
                border: OutlineInputBorder(),
                hintText: 'e.g. 💪',
              ),
            ),
            const SizedBox(height: 24),
            Text('Frequency', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<HabitFrequency>(
              segments: HabitFrequency.values
                  .map((f) =>
                      ButtonSegment(value: f, label: Text(f.label)))
                  .toList(),
              selected: {_frequency},
              onSelectionChanged: (v) =>
                  setState(() => _frequency = v.first),
            ),
            if (_frequency == HabitFrequency.weekly) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: List.generate(7, (i) {
                  final selected = _frequencyDays.contains(i);
                  return FilterChip(
                    label: Text(dayLabels[i]),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _frequencyDays.add(i);
                        } else {
                          _frequencyDays.remove(i);
                        }
                      });
                    },
                  );
                }),
              ),
            ],
            const SizedBox(height: 24),
            Text('Goal Type', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<HabitGoalType>(
              segments: HabitGoalType.values
                  .map((g) =>
                      ButtonSegment(value: g, label: Text(g.label)))
                  .toList(),
              selected: {_goalType},
              onSelectionChanged: (v) =>
                  setState(() => _goalType = v.first),
            ),
            if (_goalType == HabitGoalType.count) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _goalCountController,
                decoration: const InputDecoration(
                  labelText: 'Target Count',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. 8',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (_goalType != HabitGoalType.count) return null;
                  if (v == null || v.isEmpty) return 'Target is required';
                  final n = int.tryParse(v);
                  if (n == null || n < 1) return 'Enter a positive number';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),
            Text('Section', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<HabitSection>(
              segments: HabitSection.values
                  .map((s) =>
                      ButtonSegment(value: s, label: Text(s.label)))
                  .toList(),
              selected: {_section},
              onSelectionChanged: (v) =>
                  setState(() => _section = v.first),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save Changes' : 'Create Habit'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Habit'),
        content: const Text(
            'This will permanently delete this habit and all its logs. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final user = ref.read(currentUserProvider);
              if (user != null) {
                await ref
                    .read(firestoreServiceProvider)
                    .deleteHabit(user.uid, widget.habit!.id);
              }
              if (mounted) {
                nav.pop(); // close dialog
                nav.pop(); // close edit screen
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
