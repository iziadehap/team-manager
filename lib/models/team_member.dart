import 'package:cloud_firestore/cloud_firestore.dart';

import 'team_role.dart';

class TeamMember {
  const TeamMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  final String userId;
  final TeamRole role;
  final DateTime joinedAt;

  factory TeamMember.fromMap(Map<String, dynamic> map) {
    return TeamMember(
      userId: map['userId'] as String,
      role: TeamRole.fromString(map['role'] as String? ?? 'member'),
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'role': role.value,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }
}
