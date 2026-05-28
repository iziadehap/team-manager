import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../models/app_user.dart';
import '../../models/team.dart';
import '../../models/team_member.dart';
import '../../models/team_role.dart';
import '../../cubits/auth/auth_cubit.dart';
import '../../services/team_service.dart';
import '../../widgets/error_banner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';

class TeamMembersScreen extends StatefulWidget {
  const TeamMembersScreen({super.key, required this.teamId});

  final String teamId;

  @override
  State<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends State<TeamMembersScreen> {
  final _userNames = <String, String>{};

  Future<void> _loadNames(List<TeamMember> members) async {
    final firestore = FirebaseFirestore.instance;
    for (final member in members) {
      if (_userNames.containsKey(member.userId)) continue;
      final doc =
          await firestore.doc(FirestorePaths.user(member.userId)).get();
      if (doc.exists && mounted) {
        final user = AppUser.fromFirestore(doc);
        setState(() => _userNames[member.userId] = user.name);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthCubit>().state.userId;
    final teamService = context.read<TeamService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Team Members')),
      body: StreamBuilder<Team>(
        stream: teamService.watchTeam(widget.teamId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final team = snapshot.data!;
          _loadNames(team.members);
          final isAdmin =
              currentUserId != null && team.isAdmin(currentUserId);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Team Code: ${team.inviteCode}',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () {
                          Share.share(
                            'Join ${team.name} on TeamTask!\n'
                            '${AppConstants.inviteLinkBase}/${team.inviteCode}',
                          );
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('SHARE INVITE'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('MEMBERS (${team.memberCount})',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...team.members.map((member) {
                final name = _userNames[member.userId] ?? 'Loading...';
                final isYou = member.userId == currentUserId;
                return Card(
                  child: ListTile(
                    leading: Icon(
                      member.role == TeamRole.admin
                          ? Icons.workspace_premium
                          : Icons.person_outline,
                    ),
                    title: Text(
                      '$name${isYou ? ' (You)' : ''} '
                      '(${member.role == TeamRole.admin ? 'Admin' : 'Member'})',
                    ),
                    subtitle: Text(
                      'Joined ${DateFormat.yMMMd().format(member.joinedAt)}',
                    ),
                    onLongPress: isAdmin && !isYou
                        ? () => _showAdminActions(team, member)
                        : null,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAdminActions(Team team, TeamMember member) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Make admin'),
              onTap: () => Navigator.pop(ctx, 'admin'),
            ),
            ListTile(
              leading: const Icon(Icons.person_remove),
              title: const Text('Remove member'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final service = context.read<TeamService>();
    try {
      if (action == 'admin') {
        await service.updateMemberRole(
          teamId: team.id,
          memberId: member.userId,
          role: TeamRole.admin,
        );
      } else if (action == 'remove') {
        await service.removeMember(
          teamId: team.id,
          memberId: member.userId,
        );
      }
    } on AppException catch (e) {
      if (mounted) showErrorSnackBar(context, e.message);
    }
  }
}
