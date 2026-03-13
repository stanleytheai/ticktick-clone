import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:ticktick_clone/models/smart_filter.dart';
import 'package:ticktick_clone/models/task.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';
import 'package:ticktick_clone/providers/list_provider.dart';

class FilterBuilderScreen extends ConsumerStatefulWidget {
  final SmartFilter? existingFilter;

  const FilterBuilderScreen({super.key, this.existingFilter});

  @override
  ConsumerState<FilterBuilderScreen> createState() =>
      _FilterBuilderScreenState();
}

class _FilterBuilderScreenState extends ConsumerState<FilterBuilderScreen> {
  late TextEditingController _nameController;
  late FilterLogic _logic;
  late List<FilterCriterion> _criteria;
  late bool _pinned;

  bool get _isEditing => widget.existingFilter != null;

  @override
  void initState() {
    super.initState();
    final f = widget.existingFilter;
    _nameController = TextEditingController(text: f?.name ?? '');
    _logic = f?.logic ?? FilterLogic.and;
    _criteria = f != null ? List.from(f.criteria) : [];
    _pinned = f?.pinned ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addCriterion() {
    setState(() {
      _criteria.add(const FilterCriterion(
        type: FilterCriterionType.dueDate,
        operator: FilterOperator.isSet,
      ));
    });
  }

  void _removeCriterion(int index) {
    setState(() => _criteria.removeAt(index));
  }

  void _updateCriterion(int index, FilterCriterion criterion) {
    setState(() => _criteria[index] = criterion);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }
    if (_criteria.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one criterion')),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final now = DateTime.now();
    final filter = SmartFilter(
      id: widget.existingFilter?.id ?? const Uuid().v4(),
      name: name,
      criteria: _criteria,
      logic: _logic,
      pinned: _pinned,
      sortOrder: widget.existingFilter?.sortOrder ?? 0,
      createdAt: widget.existingFilter?.createdAt ?? now,
      updatedAt: now,
    );

    final service = ref.read(firestoreServiceProvider);
    if (_isEditing) {
      await service.updateFilter(user.uid, filter);
    } else {
      await service.addFilter(user.uid, filter);
    }

    if (mounted) Navigator.pop(context, filter);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Smart List' : 'New Smart List'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Name field
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Logic selector
          Row(
            children: [
              Text('Match:', style: theme.textTheme.titleSmall),
              const SizedBox(width: 12),
              SegmentedButton<FilterLogic>(
                segments: FilterLogic.values
                    .map((l) => ButtonSegment(value: l, label: Text(l.label)))
                    .toList(),
                selected: {_logic},
                onSelectionChanged: (v) => setState(() => _logic = v.first),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pin to sidebar toggle
          SwitchListTile(
            title: const Text('Pin to sidebar'),
            subtitle: const Text('Show in navigation drawer'),
            value: _pinned,
            onChanged: (v) => setState(() => _pinned = v),
          ),
          const Divider(height: 32),

          // Criteria list
          Text('Criteria', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._criteria.asMap().entries.map((entry) {
            return _CriterionCard(
              key: ValueKey(entry.key),
              criterion: entry.value,
              index: entry.key,
              onChanged: (c) => _updateCriterion(entry.key, c),
              onRemove: () => _removeCriterion(entry.key),
              ref: ref,
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addCriterion,
            icon: const Icon(Icons.add),
            label: const Text('Add Criterion'),
          ),
        ],
      ),
    );
  }
}

class _CriterionCard extends StatelessWidget {
  final FilterCriterion criterion;
  final int index;
  final ValueChanged<FilterCriterion> onChanged;
  final VoidCallback onRemove;
  final WidgetRef ref;

  const _CriterionCard({
    super.key,
    required this.criterion,
    required this.index,
    required this.onChanged,
    required this.onRemove,
    required this.ref,
  });

  List<FilterOperator> _operatorsForType(FilterCriterionType type) {
    switch (type) {
      case FilterCriterionType.dueDate:
      case FilterCriterionType.createdDate:
        return [
          FilterOperator.equals,
          FilterOperator.before,
          FilterOperator.after,
          FilterOperator.between,
          FilterOperator.isSet,
          FilterOperator.isNotSet,
        ];
      case FilterCriterionType.priority:
        return [FilterOperator.equals, FilterOperator.notEquals];
      case FilterCriterionType.tag:
        return [
          FilterOperator.contains,
          FilterOperator.isSet,
          FilterOperator.isNotSet,
        ];
      case FilterCriterionType.list:
        return [FilterOperator.equals, FilterOperator.notEquals];
      case FilterCriterionType.completed:
        return [FilterOperator.equals];
      case FilterCriterionType.keyword:
        return [FilterOperator.contains, FilterOperator.notEquals];
    }
  }

  @override
  Widget build(BuildContext context) {
    final operators = _operatorsForType(criterion.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<FilterCriterionType>(
                    initialValue: criterion.type,
                    decoration: const InputDecoration(
                      labelText: 'Field',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: FilterCriterionType.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.label),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final newOps = _operatorsForType(v);
                      onChanged(FilterCriterion(
                        type: v,
                        operator: newOps.first,
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<FilterOperator>(
              initialValue: operators.contains(criterion.operator)
                  ? criterion.operator
                  : operators.first,
              decoration: const InputDecoration(
                labelText: 'Operator',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: operators
                  .map((o) => DropdownMenuItem(
                        value: o,
                        child: Text(o.label),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                onChanged(criterion.copyWith(operator: v));
              },
            ),
            const SizedBox(height: 8),
            _buildValueInput(context),
          ],
        ),
      ),
    );
  }

  Widget _buildValueInput(BuildContext context) {
    // No value needed for isSet/isNotSet
    if (criterion.operator == FilterOperator.isSet ||
        criterion.operator == FilterOperator.isNotSet) {
      return const SizedBox.shrink();
    }

    switch (criterion.type) {
      case FilterCriterionType.dueDate:
      case FilterCriterionType.createdDate:
        return _DateValueInput(
          criterion: criterion,
          onChanged: onChanged,
        );
      case FilterCriterionType.priority:
        return _PriorityValueInput(
          criterion: criterion,
          onChanged: onChanged,
        );
      case FilterCriterionType.tag:
        return _TextValueInput(
          criterion: criterion,
          onChanged: onChanged,
          label: 'Tag name',
        );
      case FilterCriterionType.list:
        return _ListValueInput(
          criterion: criterion,
          onChanged: onChanged,
          ref: ref,
        );
      case FilterCriterionType.completed:
        return _CompletedValueInput(
          criterion: criterion,
          onChanged: onChanged,
        );
      case FilterCriterionType.keyword:
        return _TextValueInput(
          criterion: criterion,
          onChanged: onChanged,
          label: 'Search text',
        );
    }
  }
}

class _DateValueInput extends StatelessWidget {
  final FilterCriterion criterion;
  final ValueChanged<FilterCriterion> onChanged;

  const _DateValueInput({required this.criterion, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              onChanged(criterion.copyWith(value: date.toIso8601String()));
            }
          },
          icon: const Icon(Icons.calendar_today, size: 18),
          label: Text(
            criterion.value != null
                ? DateTime.parse(criterion.value as String)
                    .toLocal()
                    .toString()
                    .split(' ')
                    .first
                : 'Select date',
          ),
        ),
        if (criterion.operator == FilterOperator.between) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                onChanged(
                    criterion.copyWith(valueTo: date.toIso8601String()));
              }
            },
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(
              criterion.valueTo != null
                  ? DateTime.parse(criterion.valueTo!)
                      .toLocal()
                      .toString()
                      .split(' ')
                      .first
                  : 'Select end date',
            ),
          ),
        ],
      ],
    );
  }
}

class _PriorityValueInput extends StatelessWidget {
  final FilterCriterion criterion;
  final ValueChanged<FilterCriterion> onChanged;

  const _PriorityValueInput(
      {required this.criterion, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final selected = criterion.value is int
        ? criterion.value as int
        : int.tryParse(criterion.value?.toString() ?? '') ?? 0;

    return SegmentedButton<int>(
      segments: TaskPriority.values
          .map((p) => ButtonSegment(
                value: p.value,
                label: Text(p.label),
                icon: p.value > 0
                    ? Icon(Icons.flag, color: Color(p.colorValue), size: 16)
                    : null,
              ))
          .toList(),
      selected: {selected},
      onSelectionChanged: (v) =>
          onChanged(criterion.copyWith(value: v.first)),
    );
  }
}

class _TextValueInput extends StatelessWidget {
  final FilterCriterion criterion;
  final ValueChanged<FilterCriterion> onChanged;
  final String label;

  const _TextValueInput({
    required this.criterion,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      controller: TextEditingController(
          text: criterion.value?.toString() ?? ''),
      onChanged: (v) => onChanged(criterion.copyWith(value: v)),
    );
  }
}

class _ListValueInput extends StatelessWidget {
  final FilterCriterion criterion;
  final ValueChanged<FilterCriterion> onChanged;
  final WidgetRef ref;

  const _ListValueInput({
    required this.criterion,
    required this.onChanged,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsStreamProvider).value ?? [];
    final currentValue = criterion.value?.toString();

    return DropdownButtonFormField<String>(
      initialValue: lists.any((l) => l.id == currentValue) ? currentValue : null,
      decoration: const InputDecoration(
        labelText: 'List',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      items: lists
          .map((l) => DropdownMenuItem(
                value: l.id,
                child: Text(l.name),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(criterion.copyWith(value: v));
      },
    );
  }
}

class _CompletedValueInput extends StatelessWidget {
  final FilterCriterion criterion;
  final ValueChanged<FilterCriterion> onChanged;

  const _CompletedValueInput(
      {required this.criterion, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final value = criterion.value == true ||
        criterion.value?.toString() == 'true';

    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('Incomplete')),
        ButtonSegment(value: true, label: Text('Completed')),
      ],
      selected: {value},
      onSelectionChanged: (v) =>
          onChanged(criterion.copyWith(value: v.first)),
    );
  }
}
