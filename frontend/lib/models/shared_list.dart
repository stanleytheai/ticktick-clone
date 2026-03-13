import 'package:cloud_firestore/cloud_firestore.dart';

enum ListPermission {
  view,
  edit,
  admin;

  static ListPermission fromString(String value) {
    return ListPermission.values.firstWhere(
      (p) => p.name == value,
      orElse: () => ListPermission.view,
    );
  }
}

class ListMember {
  final String uid;
  final ListPermission role;
  final String email;
  final String displayName;
  final DateTime addedAt;

  const ListMember({
    required this.uid,
    required this.role,
    required this.email,
    this.displayName = '',
    required this.addedAt,
  });

  factory ListMember.fromEntry(String uid, Map<String, dynamic> map) {
    return ListMember(
      uid: uid,
      role: ListPermission.fromString(map['role'] as String? ?? 'view'),
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      addedAt: map['addedAt'] is Timestamp
          ? (map['addedAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['addedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class SharedList {
  final String id;
  final String name;
  final int colorValue;
  final String? icon;
  final String ownerId;
  final Map<String, ListMember> members;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SharedList({
    required this.id,
    required this.name,
    this.colorValue = 0xFF2196F3,
    this.icon,
    required this.ownerId,
    required this.members,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool isMember(String uid) => members.containsKey(uid);

  ListPermission? getRole(String uid) => members[uid]?.role;

  bool canEdit(String uid) {
    final role = getRole(uid);
    return role == ListPermission.edit || role == ListPermission.admin;
  }

  bool isAdmin(String uid) => getRole(uid) == ListPermission.admin;

  Map<String, dynamic> toMap() {
    final membersMap = <String, dynamic>{};
    for (final entry in members.entries) {
      membersMap[entry.key] = {
        'role': entry.value.role.name,
        'email': entry.value.email,
        'displayName': entry.value.displayName,
        'addedAt': entry.value.addedAt.toIso8601String(),
      };
    }
    return {
      'name': name,
      'color': colorValue == 0xFF2196F3
          ? null
          : '#${colorValue.toRadixString(16).substring(2).toUpperCase()}',
      'icon': icon,
      'ownerId': ownerId,
      'members': membersMap,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory SharedList.fromMap(String id, Map<String, dynamic> map) {
    final membersRaw = map['members'] as Map<String, dynamic>? ?? {};
    final members = <String, ListMember>{};
    for (final entry in membersRaw.entries) {
      members[entry.key] = ListMember.fromEntry(
        entry.key,
        entry.value as Map<String, dynamic>,
      );
    }

    int colorValue = 0xFF2196F3;
    if (map['color'] is String) {
      final hex = (map['color'] as String).replaceFirst('#', '');
      colorValue = int.tryParse('FF$hex', radix: 16) ?? 0xFF2196F3;
    } else if (map['colorValue'] is int) {
      colorValue = map['colorValue'] as int;
    }

    return SharedList(
      id: id,
      name: map['name'] as String? ?? '',
      colorValue: colorValue,
      icon: map['icon'] as String?,
      ownerId: map['ownerId'] as String? ?? '',
      members: members,
      sortOrder: map['sortOrder'] as int? ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
