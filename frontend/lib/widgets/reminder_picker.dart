import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:ticktick_clone/models/reminder.dart';

class ReminderPicker extends StatelessWidget {
  final List<Reminder> reminders;
  final int maxReminders;
  final ValueChanged<List<Reminder>> onChanged;

  const ReminderPicker({
    super.key,
    required this.reminders,
    required this.maxReminders,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeReminders = reminders.where((r) => !r.dismissed).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing reminders
        ...activeReminders.map((reminder) => ListTile(
              leading: const Icon(Icons.alarm, size: 20),
              title: Text(reminder.displayLabel),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  final updated = List<Reminder>.from(reminders)
                    ..removeWhere((r) => r.id == reminder.id);
                  onChanged(updated);
                },
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
            )),

        // Add reminder button
        if (activeReminders.length < maxReminders)
          TextButton.icon(
            onPressed: () => _showAddReminderSheet(context),
            icon: const Icon(Icons.add_alarm, size: 20),
            label: const Text('Add Reminder'),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Maximum $maxReminders reminders reached',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
      ],
    );
  }

  void _showAddReminderSheet(BuildContext context) {
    final presets = [
      (ReminderType.atTime, 0, 'At due time'),
      (ReminderType.minutesBefore, 5, '5 minutes before'),
      (ReminderType.minutesBefore, 10, '10 minutes before'),
      (ReminderType.minutesBefore, 15, '15 minutes before'),
      (ReminderType.minutesBefore, 30, '30 minutes before'),
      (ReminderType.hoursBefore, 1, '1 hour before'),
      (ReminderType.hoursBefore, 2, '2 hours before'),
      (ReminderType.daysBefore, 1, '1 day before'),
      (ReminderType.daysBefore, 2, '2 days before'),
      (ReminderType.daysBefore, 7, '1 week before'),
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Add Reminder',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          ...presets.map((preset) => ListTile(
                leading: const Icon(Icons.alarm),
                title: Text(preset.$3),
                onTap: () {
                  final reminder = Reminder(
                    id: const Uuid().v4(),
                    type: preset.$1,
                    value: preset.$2,
                  );
                  final updated = List<Reminder>.from(reminders)
                    ..add(reminder);
                  onChanged(updated);
                  Navigator.pop(ctx);
                },
              )),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Custom...'),
            onTap: () {
              Navigator.pop(ctx);
              _showCustomReminderDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showCustomReminderDialog(BuildContext context) {
    ReminderType selectedType = ReminderType.minutesBefore;
    final valueController = TextEditingController(text: '15');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Custom Reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ReminderType>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: ReminderType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t == ReminderType.atTime
                              ? 'At due time'
                              : t.label),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => selectedType = v);
                },
              ),
              if (selectedType != ReminderType.atTime) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: valueController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Value',
                    suffixText: selectedType.label,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = selectedType == ReminderType.atTime
                    ? 0
                    : int.tryParse(valueController.text) ?? 0;
                if (selectedType != ReminderType.atTime && value <= 0) return;

                final reminder = Reminder(
                  id: const Uuid().v4(),
                  type: selectedType,
                  value: value,
                );
                final updated = List<Reminder>.from(reminders)..add(reminder);
                onChanged(updated);
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
