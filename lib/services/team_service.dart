import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/invite_code_generator.dart';
import '../models/team.dart';
import '../models/team_member.dart';
import '../models/team_role.dart';

class TeamService {
  TeamService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  Stream<List<Team>> watchUserTeams(List<String> teamIds) {
    try {
      if (teamIds.isEmpty) {
        print('✅ Success: Empty teamIds list, returning empty stream');
        return Stream.value([]);
      }

      print('📡 Watching teams for ${teamIds.length} team IDs');
      return _firestore
          .collection(FirestorePaths.teams)
          .where(FieldPath.documentId, whereIn: _chunkIds(teamIds))
          .snapshots()
          .map((snapshot) {
            final teams = snapshot.docs.map(Team.fromFirestore).toList();
            print('✅ Success: Retrieved ${teams.length} teams');
            return teams;
          });
    } catch (e, stackTrace) {
      print('❌ Error in watchUserTeams: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<int> pendingTaskCount(String teamId) async {
    try {
      print('📊 Fetching pending task count for team: $teamId');
      final snapshot = await _firestore
          .collection(FirestorePaths.teamTasks(teamId))
          .get();

      var count = 0;
      for (final doc in snapshot.docs) {
        final status = doc.data()['assigneeStatus'] as Map<String, dynamic>?;
        if (status == null || status.values.any((v) => v != 'done')) {
          count++;
        }
      }

      print('✅ Success: Found $count pending tasks for team $teamId');
      return count;
    } catch (e, stackTrace) {
      print('❌ Error in pendingTaskCount for team $teamId: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<Team> createTeam({
    required String userId,
    required String name,
    String? description,
    String icon = '📁',
  }) async {
    try {
      print('🚀 Creating new team: "$name" for user: $userId');

      final teamId = _uuid.v4();
      final inviteCode = InviteCodeGenerator.generate();
      final team = Team(
        id: teamId,
        name: name.trim(),
        description: description?.trim(),
        icon: icon,
        inviteCode: inviteCode,
        createdBy: userId,
        createdAt: DateTime.now(),
        members: [
          TeamMember(
            userId: userId,
            role: TeamRole.admin,
            joinedAt: DateTime.now(),
          ),
        ],
      );

      final batch = _firestore.batch();
      batch.set(_firestore.doc(FirestorePaths.team(teamId)), team.toMap());
      batch.set(_firestore.doc(FirestorePaths.inviteCode(inviteCode)), {
        'teamId': teamId,
        'name': team.name,
        'icon': team.icon,
        'memberCount': 1,
      });
      batch.update(_firestore.doc(FirestorePaths.user(userId)), {
        'teams': FieldValue.arrayUnion([teamId]),
      });

      await batch.commit();

      print('✅ Success: Team "$name" created successfully with ID: $teamId');
      print('📋 Invite code: $inviteCode');
      return team;
    } catch (e, stackTrace) {
      print('❌ Error in createTeam for user $userId: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<Team?> previewTeamByCode(String code) async {
    try {
      final normalized = code.trim().toUpperCase();
      print('🔍 Previewing team with invite code: $normalized');

      final lookup = await _firestore
          .doc(FirestorePaths.inviteCode(normalized))
          .get();

      if (!lookup.exists) {
        print('⚠️ No team found for invite code: $normalized');
        return null;
      }

      final data = lookup.data()!;
      final teamId = data['teamId'] as String;

      print(
        '✅ Success: Found team preview for code $normalized (Team ID: $teamId)',
      );
      return Team(
        id: teamId,
        name: data['name'] as String? ?? 'Team',
        icon: data['icon'] as String? ?? '📁',
        inviteCode: normalized,
        createdBy: '',
        createdAt: DateTime.now(),
        members: List.generate(
          data['memberCount'] as int? ?? 0,
          (_) => TeamMember(
            userId: '',
            role: TeamRole.member,
            joinedAt: DateTime.now(),
          ),
        ),
      );
    } catch (e, stackTrace) {
      print('❌ Error in previewTeamByCode for code $code: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<Team> joinTeam({
    required String userId,
    required String inviteCode,
  }) async {
    try {
      final normalized = inviteCode.trim().toUpperCase();
      print('🔗 User $userId joining team with invite code: $normalized');

      final lookup = await _firestore
          .doc(FirestorePaths.inviteCode(normalized))
          .get();

      if (!lookup.exists) {
        print('❌ Invalid invite code: $normalized');
        throw AppException('Invalid invite code.');
      }

      final teamId = lookup.data()!['teamId'] as String;
      final teamRef = _firestore.doc(FirestorePaths.team(teamId));
      final teamDoc = await teamRef.get();

      if (!teamDoc.exists) {
        print('❌ Team not found for ID: $teamId');
        throw AppException('Team not found.');
      }

      final team = Team.fromFirestore(teamDoc);
      if (team.isMember(userId)) {
        print('⚠️ User $userId is already a member of team $teamId');
        return team;
      }

      final member = TeamMember(
        userId: userId,
        role: TeamRole.member,
        joinedAt: DateTime.now(),
      );

      final batch = _firestore.batch();
      batch.update(teamRef, {
        'members': FieldValue.arrayUnion([member.toMap()]),
      });
      batch.update(_firestore.doc(FirestorePaths.user(userId)), {
        'teams': FieldValue.arrayUnion([teamId]),
      });
      await batch.commit();

      final updated = await teamRef.get();
      print('✅ Success: User $userId joined team ${team.name} (ID: $teamId)');
      return Team.fromFirestore(updated);
    } catch (e, stackTrace) {
      print('❌ Error in joinTeam for user $userId with code $inviteCode: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> leaveTeam({
    required String userId,
    required String teamId,
  }) async {
    try {
      print('🚪 User $userId leaving team: $teamId');

      final teamRef = _firestore.doc(FirestorePaths.team(teamId));
      final teamDoc = await teamRef.get();

      if (!teamDoc.exists) {
        print('⚠️ Team $teamId not found, cannot leave');
        return;
      }

      final team = Team.fromFirestore(teamDoc);
      final updatedMembers = team.members
          .where((m) => m.userId != userId)
          .map((m) => m.toMap())
          .toList();

      final batch = _firestore.batch();
      batch.update(teamRef, {'members': updatedMembers});
      batch.update(_firestore.doc(FirestorePaths.user(userId)), {
        'teams': FieldValue.arrayRemove([teamId]),
      });
      await batch.commit();

      print('✅ Success: User $userId left team ${team.name} (ID: $teamId)');
    } catch (e, stackTrace) {
      print('❌ Error in leaveTeam for user $userId in team $teamId: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Stream<Team> watchTeam(String teamId) {
    try {
      print('📡 Watching team: $teamId');
      return _firestore.doc(FirestorePaths.team(teamId)).snapshots().map((doc) {
        final team = Team.fromFirestore(doc);
        print('✅ Success: Retrieved team update for ${team.name}');
        return team;
      });
    } catch (e, stackTrace) {
      print('❌ Error in watchTeam for team $teamId: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> updateMemberRole({
    required String teamId,
    required String memberId,
    required TeamRole role,
  }) async {
    try {
      print(
        '🔄 Updating role for member $memberId in team $teamId to ${role.toString()}',
      );

      final teamDoc = await _firestore.doc(FirestorePaths.team(teamId)).get();
      if (!teamDoc.exists) {
        print('❌ Team $teamId not found');
        throw AppException('Team not found.');
      }

      final team = Team.fromFirestore(teamDoc);
      final members = team.members.map((m) {
        if (m.userId == memberId) {
          return TeamMember(userId: m.userId, role: role, joinedAt: m.joinedAt);
        }
        return m;
      }).toList();

      await _firestore.doc(FirestorePaths.team(teamId)).update({
        'members': members.map((m) => m.toMap()).toList(),
      });

      print(
        '✅ Success: Updated role for member $memberId in team $teamId to ${role.toString()}',
      );
    } catch (e, stackTrace) {
      print(
        '❌ Error in updateMemberRole for member $memberId in team $teamId: $e',
      );
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> removeMember({
    required String teamId,
    required String memberId,
  }) async {
    try {
      print('🗑️ Removing member $memberId from team $teamId');

      final teamRef = _firestore.doc(FirestorePaths.team(teamId));
      final teamDoc = await teamRef.get();

      if (!teamDoc.exists) {
        print('⚠️ Team $teamId not found, cannot remove member');
        return;
      }

      final team = Team.fromFirestore(teamDoc);
      final members = team.members
          .where((m) => m.userId != memberId)
          .map((m) => m.toMap())
          .toList();

      final batch = _firestore.batch();
      batch.update(teamRef, {'members': members});
      batch.update(_firestore.doc(FirestorePaths.user(memberId)), {
        'teams': FieldValue.arrayRemove([teamId]),
      });
      await batch.commit();

      print(
        '✅ Success: Removed member $memberId from team ${team.name} (ID: $teamId)',
      );
    } catch (e, stackTrace) {
      print(
        '❌ Error in removeMember for member $memberId from team $teamId: $e',
      );
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
List<String> _chunkIds(List<String> ids) {  // ← Changed return type
  // Firestore whereIn supports max 30 values.
  const maxIds = 30;
  if (ids.length <= maxIds) return ids;  // ← Return ids directly, not wrapped in list
  print('⚠️ Truncating ${ids.length} IDs to $maxIds');
  return ids.sublist(0, maxIds);  // ← Return sublist directly
}
}
