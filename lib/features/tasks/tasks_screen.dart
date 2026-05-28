
// cat > /home/claude/lib/features/tasks/tasks_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme/app_theme.dart';
import '../../models/team.dart';
import '../../models/team_task.dart';
import '../../cubits/auth/auth_cubit.dart';
import '../../services/task_service.dart';
import '../../services/team_service.dart';
import '../../widgets/loading_overlay.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.teamId});
  final String teamId;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  TaskFilter _filter = TaskFilter.all;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() {
          _filter = [TaskFilter.all, TaskFilter.pending, TaskFilter.done][_tabCtrl.index];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskService = context.read<TaskService>();
    final teamService = context.read<TeamService>();
    final userId = context.read<AuthCubit>().state.userId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<Team>(
      stream: teamService.watchTeam(widget.teamId),
      builder: (context, teamSnapshot) {
        final team = teamSnapshot.data;

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverAppBar(
                expandedHeight: 120,
                floating: false,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.group_outlined),
                    onPressed: () => context.push('/teams/${widget.teamId}/members'),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.fromLTRB(60, 0, 60, 16),
                  title: Text(
                    team != null ? '${team.icon} ${team.name}' : 'Tasks',
                    style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                bottom: TabBar(
                  controller: _tabCtrl,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  labelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [Tab(text: 'ALL'), Tab(text: 'PENDING'), Tab(text: 'DONE')],
                ),
              ),
            ],
            body: StreamBuilder<List<TeamTask>>(
              stream: taskService.watchTasks(widget.teamId, filter: _filter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: List.generate(4, (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: ShimmerCard(height: 100),
                      )),
                    ),
                  );
                }

                final tasks = snapshot.data ?? [];

                if (tasks.isEmpty) {
                  return _EmptyTasksState(filter: _filter);
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {},
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 250 + index * 60),
                        curve: Curves.easeOutCubic,
                        builder: (_, val, child) => Transform.translate(
                          offset: Offset(0, 16 * (1 - val)),
                          child: Opacity(opacity: val, child: child),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TaskCard(
                            task: task,
                            userId: userId,
                            onTap: () => context.push('/teams/${widget.teamId}/tasks/${task.id}'),
                            onToggleDone: () async {
                              if (userId == null) return;
                              await taskService.markAssigneeDone(
                                teamId: widget.teamId,
                                taskId: task.id,
                                userId: userId,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/teams/${widget.teamId}/tasks/create'),
            label: const Text('Add Task', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
            icon: const Icon(Icons.add_rounded),
            extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatefulWidget {
  const _TaskCard({
    required this.task,
    required this.userId,
    required this.onTap,
    required this.onToggleDone,
  });
  final TeamTask task;
  final String? userId;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverdue = widget.task.dueDate != null &&
        widget.task.dueDate!.isBefore(DateTime.now()) &&
        !widget.task.isDone;
    final dueLabel = widget.task.dueDate != null
        ? DateFormat.MMMd().format(widget.task.dueDate!)
        : null;

    final myStatus = widget.userId != null
        ? widget.task.assigneeStatus[widget.userId] == 'done'
        : false;
    final isDone = widget.task.isDone || myStatus;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.identity()..scale(_pressed ? 0.98 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDone
                ? AppColors.success.withOpacity(0.3)
                : isOverdue
                    ? AppColors.error.withOpacity(0.3)
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: 1.5,
          ),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  )
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // Status icon
              GestureDetector(
                onTap: widget.onToggleDone,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppColors.success.withOpacity(0.15)
                        : isOverdue
                            ? AppColors.error.withOpacity(0.1)
                            : AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : isOverdue
                            ? Icons.warning_rounded
                            : Icons.radio_button_unchecked_rounded,
                    color: isDone
                        ? AppColors.success
                        : isOverdue
                            ? AppColors.error
                            : AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.task.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isDone
                                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                                : null,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (widget.task.assignedTo.isNotEmpty) ...[
                          Icon(Icons.person_outline_rounded, size: 13,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.task.assignedTo.length}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (dueLabel != null) ...[
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 13,
                            color: isOverdue ? AppColors.error : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dueLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isOverdue ? AppColors.error : null,
                                  fontWeight: isOverdue ? FontWeight.w700 : null,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTasksState extends StatelessWidget {
  const _EmptyTasksState({required this.filter});
  final TaskFilter filter;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (filter) {
      TaskFilter.pending => ('⏳', 'No pending tasks!', 'Great job keeping up with everything.'),
      TaskFilter.done => ('🎉', 'No completed tasks yet', 'Complete your first task to see it here.'),
      _ => ('📋', 'No tasks yet', 'Tap the button below to create your first task.'),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}