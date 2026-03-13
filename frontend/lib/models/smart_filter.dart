import 'package:cloud_firestore/cloud_firestore.dart';

enum FilterCriterionType {
  dueDate('dueDate', 'Due Date'),
  priority('priority', 'Priority'),
  tag('tag', 'Tag'),
  list('list', 'List'),
  completed('completed', 'Completion'),
  keyword('keyword', 'Keyword'),
  createdDate('createdDate', 'Created Date');

  const FilterCriterionType(this.value, this.label);
  final String value;
  final String label;

  static FilterCriterionType fromValue(String value) {
    return FilterCriterionType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => FilterCriterionType.keyword,
    );
  }
}

enum FilterOperator {
  equals('equals', 'is'),
  notEquals('notEquals', 'is not'),
  before('before', 'before'),
  after('after', 'after'),
  between('between', 'between'),
  contains('contains', 'contains'),
  isSet('isSet', 'is set'),
  isNotSet('isNotSet', 'is not set');

  const FilterOperator(this.value, this.label);
  final String value;
  final String label;

  static FilterOperator fromValue(String value) {
    return FilterOperator.values.firstWhere(
      (o) => o.value == value,
      orElse: () => FilterOperator.equals,
    );
  }
}

enum FilterLogic {
  and('and', 'All criteria (AND)'),
  or('or', 'Any criteria (OR)');

  const FilterLogic(this.value, this.label);
  final String value;
  final String label;

  static FilterLogic fromValue(String value) {
    return FilterLogic.values.firstWhere(
      (l) => l.value == value,
      orElse: () => FilterLogic.and,
    );
  }
}

class FilterCriterion {
  final FilterCriterionType type;
  final FilterOperator operator;
  final dynamic value;
  final String? valueTo;

  const FilterCriterion({
    required this.type,
    required this.operator,
    this.value,
    this.valueTo,
  });

  FilterCriterion copyWith({
    FilterCriterionType? type,
    FilterOperator? operator,
    dynamic value,
    bool clearValue = false,
    String? valueTo,
    bool clearValueTo = false,
  }) {
    return FilterCriterion(
      type: type ?? this.type,
      operator: operator ?? this.operator,
      value: clearValue ? null : (value ?? this.value),
      valueTo: clearValueTo ? null : (valueTo ?? this.valueTo),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'operator': operator.value,
      if (value != null) 'value': value,
      if (valueTo != null) 'valueTo': valueTo,
    };
  }

  factory FilterCriterion.fromMap(Map<String, dynamic> map) {
    return FilterCriterion(
      type: FilterCriterionType.fromValue(map['type'] as String? ?? 'keyword'),
      operator: FilterOperator.fromValue(map['operator'] as String? ?? 'equals'),
      value: map['value'],
      valueTo: map['valueTo'] as String?,
    );
  }
}

class SmartFilter {
  final String id;
  final String name;
  final List<FilterCriterion> criteria;
  final FilterLogic logic;
  final String? icon;
  final int? colorValue;
  final bool pinned;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SmartFilter({
    required this.id,
    required this.name,
    required this.criteria,
    this.logic = FilterLogic.and,
    this.icon,
    this.colorValue,
    this.pinned = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  SmartFilter copyWith({
    String? id,
    String? name,
    List<FilterCriterion>? criteria,
    FilterLogic? logic,
    String? icon,
    int? colorValue,
    bool clearColor = false,
    bool? pinned,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SmartFilter(
      id: id ?? this.id,
      name: name ?? this.name,
      criteria: criteria ?? this.criteria,
      logic: logic ?? this.logic,
      icon: icon ?? this.icon,
      colorValue: clearColor ? null : (colorValue ?? this.colorValue),
      pinned: pinned ?? this.pinned,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'criteria': criteria.map((c) => c.toMap()).toList(),
      'logic': logic.value,
      if (icon != null) 'icon': icon,
      if (colorValue != null) 'color': '#${colorValue!.toRadixString(16).padLeft(8, '0').substring(2)}',
      'pinned': pinned,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory SmartFilter.fromMap(String id, Map<String, dynamic> map) {
    final colorStr = map['color'] as String?;
    int? colorValue;
    if (colorStr != null && colorStr.startsWith('#')) {
      colorValue = int.tryParse('FF${colorStr.substring(1)}', radix: 16);
    }

    return SmartFilter(
      id: id,
      name: map['name'] as String? ?? '',
      criteria: (map['criteria'] as List? ?? [])
          .map((c) => FilterCriterion.fromMap(c as Map<String, dynamic>))
          .toList(),
      logic: FilterLogic.fromValue(map['logic'] as String? ?? 'and'),
      icon: map['icon'] as String?,
      colorValue: colorValue,
      pinned: map['pinned'] as bool? ?? false,
      sortOrder: map['sortOrder'] as int? ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
