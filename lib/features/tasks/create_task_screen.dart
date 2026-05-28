// cat > /home/claude/lib/features/tasks/create_task_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:team_manager/models/team_member.dart';

import '../../app/theme/app_theme.dart';
import '../../core/errors/app_exception.dart';
import '../../cubits/auth/auth_cubit.dart';
import '../../models/team.dart';
import '../../models/app_user.dart';
import '../../services/task_service.dart';
import '../../services/team_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/error_banner.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key, required this.teamId});
  final String teamId;

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _selectedMembers = <String>{};
  DateTime? _dueDate;
  bool _loading = false;
  bool _loadingMembers = false;
  Team? _team;
  Map<String, AppUser> _userProfiles = {};

  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animCtrl.forward();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    final team = await context
        .read<TeamService>()
        .watchTeam(widget.teamId)
        .first;
    if (mounted) {
      setState(() => _team = team);
      // Auto-fetch members
      if (team.members.isNotEmpty) _fetchTeamMembers();
    }
  }

  Future<void> _fetchTeamMembers() async {
    if (_team == null || _team!.members.isEmpty) return;
    setState(() {
      _loadingMembers = true;
      _userProfiles.clear();
    });
    try {
      final userService = context.read<UserService>();
      final Map<String, AppUser> profiles = {};
      for (final member in _team!.members) {
        try {
          final user = await userService.getUserProfile(member.userId);
          profiles[member.userId] = user;
        } catch (_) {}
      }
      if (mounted)
        setState(() {
          _userProfiles = profiles;
          _loadingMembers = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDate: _dueDate ?? DateTime.now(),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _dueDate = date);
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = context.read<AuthCubit>().state.userId;
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      await context.read<TaskService>().createTask(
        teamId: widget.teamId,
        createdBy: userId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        assignedTo: _selectedMembers.toList(),
        dueDate: _dueDate,
      );
      if (mounted) {
        showSuccessSnackBar(context, 'Task created successfully!');
        context.pop();
      }
    } on AppException catch (e) {
      if (mounted) showErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _memberName(TeamMember member) {
    final profile = _userProfiles[member.userId];
    if (profile != null) return profile.name;
    return member.userId.contains('@')
        ? member.userId.split('@').first
        : member.userId;
  }

  @override
  Widget build(BuildContext context) {
    final members = _team?.members ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => context.pop(),
              ),
              title: const Text('New Task'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        )
                      : TextButton(
                          onPressed: _create,
                          child: const Text(
                            'Create',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        controller: _titleController,
                        label: 'Task Title',
                        icon: Icons.task_alt_rounded,
                        autofocus: true,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Title is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _descController,
                        label: 'Description (optional)',
                        icon: Icons.notes_rounded,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 28),

                      // Due date
                      _SectionLabel('Due Date'),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.cardDark
                                : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _dueDate != null
                                  ? AppColors.primary.withOpacity(0.5)
                                  : (isDark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                color: _dueDate != null
                                    ? AppColors.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.4),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _dueDate != null
                                    ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                                    : 'Pick a due date',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: _dueDate != null
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _dueDate != null
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.onSurface
                                            .withOpacity(0.4),
                                  fontSize: 15,
                                ),
                              ),
                              const Spacer(),
                              if (_dueDate != null)
                                GestureDetector(
                                  onTap: () => setState(() => _dueDate = null),
                                  child: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Assign members
                      Row(
                        children: [
                          _SectionLabel('Assign To'),
                          const SizedBox(width: 10),
                          if (_loadingMembers)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          const Spacer(),
                          if (_selectedMembers.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_selectedMembers.length} selected',
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_loadingMembers)
                        Column(
                          children: List.generate(
                            3,
                            (i) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                height: 64,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.cardDark
                                      : AppColors.cardLight,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (members.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.cardDark
                                : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.people_outline_rounded,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'No team members found',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        )
                      else
                        ...members.map((m) {
                          final selected = _selectedMembers.contains(m.userId);
                          final name = _memberName(m);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (selected) {
                                    _selectedMembers.remove(m.userId);
                                  } else {
                                    _selectedMembers.add(m.userId);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary.withOpacity(0.08)
                                      : (isDark
                                            ? AppColors.cardDark
                                            : AppColors.cardLight),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary.withOpacity(0.5)
                                        : (isDark
                                              ? AppColors.borderDark
                                              : AppColors.borderLight),
                                    width: selected ? 2 : 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: selected
                                          ? AppColors.primary
                                          : AppColors.primary.withOpacity(0.1),
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontFamily: 'Nunito',
                                          fontWeight: FontWeight.w800,
                                          color: selected
                                              ? Colors.white
                                              : AppColors.primary,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                          Text(
                                            m.role.value.toUpperCase(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.5,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: selected
                                          ? const Icon(
                                              Icons.check_circle_rounded,
                                              color: AppColors.primary,
                                              key: ValueKey('checked'),
                                            )
                                          : Icon(
                                              Icons.circle_outlined,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.2),
                                              key: const ValueKey('unchecked'),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 40),

                      // Create button
                      SizedBox(
                        width: double.infinity,
                        child: _loading
                            ? Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primaryLight,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            : FilledButton.icon(
                                onPressed: _create,
                                icon: const Icon(
                                  Icons.add_task_rounded,
                                  size: 20,
                                ),
                                label: const Text('Create Task'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleMedium);
  }
}
