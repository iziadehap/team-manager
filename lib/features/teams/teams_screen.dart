
// cat > /home/claude/lib/features/teams/teams_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme/app_theme.dart';
import '../../core/errors/app_exception.dart';
import '../../cubits/auth/auth_cubit.dart';
import '../../models/app_user.dart';
import '../../models/team.dart';
import '../../router/app_router.dart';
import '../../services/team_service.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/loading_overlay.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> with SingleTickerProviderStateMixin {
  AppUser? _user;
  final _pendingCounts = <String, int>{};
  bool _isLoadingCounts = false;
  String? _lastLoadedTeamIds;

  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _loadUser();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final authCubit = context.read<AuthCubit>();
    await authCubit.loadProfile();
    final profile = authCubit.state.profile;
    if (mounted) {
      setState(() => _user = profile);
      _animCtrl.forward(from: 0);
    }
  }

  Future<void> _refreshPendingCounts(List<Team> teams) async {
    if (_isLoadingCounts || teams.isEmpty) return;
    final teamIdsKey = teams.map((t) => t.id).join(',');
    if (_lastLoadedTeamIds == teamIdsKey) return;
    _isLoadingCounts = true;
    final service = context.read<TeamService>();
    final newCounts = <String, int>{};
    for (final team in teams) {
      try {
        final count = await service.pendingTaskCount(team.id);
        newCounts[team.id] = count;
      } catch (_) {
        newCounts[team.id] = 0;
      }
    }
    if (mounted) {
      setState(() {
        _pendingCounts
          ..clear()
          ..addAll(newCounts);
        _lastLoadedTeamIds = teamIdsKey;
      });
    }
    _isLoadingCounts = false;
  }

  Future<void> _leaveTeam(Team team) async {
    final userId = context.read<AuthCubit>().state.userId;
    if (userId == null) return;
    try {
      await context.read<TeamService>().leaveTeam(userId: userId, teamId: team.id);
      _lastLoadedTeamIds = null;
      await _loadUser();
    } on AppException catch (e) {
      if (mounted) showErrorSnackBar(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamService = context.read<TeamService>();
    final teamIds = _user?.teamIds ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Fancy app bar
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
              title: Text(
                'My Teams',
                style: Theme.of(context).appBarTheme.titleTextStyle,
              ),
              background: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 16, 56),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _user != null
                      ? Text(
                          'Hey, ${_user!.name.split(' ').first} 👋',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.push(AppRoutes.profile),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _user?.name.isNotEmpty == true ? _user!.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontFamily: 'Nunito', fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),

          if (_user == null)
            const SliverFillRemaining(child: FullPageLoader())
          else if (teamIds.isEmpty)
            SliverFillRemaining(
              child: _EmptyTeams(
                onCreate: () => context.push(AppRoutes.createTeam),
                onJoin: () => context.push(AppRoutes.joinTeam),
              ),
            )
          else
            SliverToBoxAdapter(
              child: StreamBuilder<List<Team>>(
                stream: teamService.watchUserTeams(teamIds),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: List.generate(3, (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ShimmerCard(height: 90),
                        )),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                            ),
                            const SizedBox(height: 20),
                            Text('Something went wrong', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text('${snapshot.error}', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _loadUser,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final teams = snapshot.data ?? [];

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && teams.isNotEmpty && !_isLoadingCounts) {
                      _refreshPendingCounts(teams);
                    }
                  });

                  return RefreshIndicator(
                    onRefresh: () async {
                      _lastLoadedTeamIds = null;
                      await _loadUser();
                      if (teams.isNotEmpty) await _refreshPendingCounts(teams);
                    },
                    color: AppColors.primary,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      child: Column(
                        children: [
                          ...teams.asMap().entries.map((entry) {
                            final i = entry.key;
                            final team = entry.value;
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(milliseconds: 300 + i * 80),
                              curve: Curves.easeOutCubic,
                              builder: (_, val, child) => Transform.translate(
                                offset: Offset(0, 20 * (1 - val)),
                                child: Opacity(opacity: val, child: child),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _TeamCard(
                                  team: team,
                                  pendingCount: _pendingCounts[team.id] ?? 0,
                                  onTap: () => context.push('/teams/${team.id}/tasks'),
                                  onLeave: () async {
                                    final confirmed = await _showLeaveDialog(team);
                                    if (confirmed) _leaveTeam(team);
                                  },
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          _ActionButtons(
                            onCreate: () => context.push(AppRoutes.createTeam),
                            onJoin: () => context.push(AppRoutes.joinTeam),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<bool> _showLeaveDialog(Team team) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Leave team?'),
            content: Text('You\'ll lose access to ${team.name} and all its tasks.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _TeamCard extends StatefulWidget {
  const _TeamCard({
    required this.team,
    required this.pendingCount,
    required this.onTap,
    required this.onLeave,
  });
  final Team team;
  final int pendingCount;
  final VoidCallback onTap;
  final VoidCallback onLeave;

  @override
  State<_TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<_TeamCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      onLongPress: widget.onLeave,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.identity()..scale(_pressed ? 0.98 : 1.0),
        transformAlignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1.5,
            ),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(widget.team.icon, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.team.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _MiniChip(
                          label: '${widget.team.memberCount} members',
                          icon: Icons.group_outlined,
                        ),
                        const SizedBox(width: 8),
                        if (widget.pendingCount > 0)
                          _MiniChip(
                            label: '${widget.pendingCount} pending',
                            icon: Icons.pending_actions_rounded,
                            color: AppColors.warning,
                          )
                        else
                          _MiniChip(
                            label: 'All done',
                            icon: Icons.check_circle_outline_rounded,
                            color: AppColors.success,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.icon, this.color});
  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w600, color: c)),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.onCreate, required this.onJoin});
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Team'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.link_rounded, size: 18),
            label: const Text('Join Team'),
          ),
        ),
      ],
    );
  }
}

class _EmptyTeams extends StatelessWidget {
  const _EmptyTeams({required this.onCreate, required this.onJoin});
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.15), AppColors.accent.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Center(child: Text('👥', style: TextStyle(fontSize: 44))),
            ),
            const SizedBox(height: 28),
            Text('No teams yet', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'Create a new team or join one with an invite code to get started.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create a Team'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onJoin,
                icon: const Icon(Icons.link_rounded),
                label: const Text('Join with Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}