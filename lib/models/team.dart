import 'package:cloud_firestore/cloud_firestore.dart';

import 'team_member.dart';

class Team {
  const Team({
    required this.id,
    required this.name,
    required this.icon,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    this.description,
    this.members = const [],
  });

  final String id;
  final String name;
  final String? description;
  final String icon;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;
  final List<TeamMember> members;

  int get memberCount => members.length;

  factory Team.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final membersRaw = data['members'] as List<dynamic>? ?? [];
    return Team(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      icon: data['icon'] as String? ?? '📁',
      inviteCode: data['inviteCode'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      members: membersRaw
          .map((e) => TeamMember.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
      'inviteCode': inviteCode,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'members': members.map((m) => m.toMap()).toList(),
    };
  }

  bool isAdmin(String userId) {
    return members.any(
      (m) => m.userId == userId && m.role.name == 'admin',
    );
  }

  bool isMember(String userId) {
    return members.any((m) => m.userId == userId);
  }
}
