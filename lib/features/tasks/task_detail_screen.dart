// cat > /home/claude/lib/features/tasks/task_detail_screen.dart << 'EOF'
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme/app_theme.dart';
import '../../core/constants/firestore_paths.dart';
import '../../cubits/auth/auth_cubit.dart';
import '../../models/app_user.dart';
import '../../models/task_comment.dart';
import '../../services/comment_service.dart';
import '../../services/task_service.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/loading_overlay.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.teamId, required this.taskId});
  final String teamId;
  final String taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> with SingleTickerProviderStateMixin {
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();
  final _userNames = <String, String>{};
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<String> _userName(String userId) async {
    if (_userNames.containsKey(userId)) return _userNames[userId]!;
    final doc = await FirebaseFirestore.instance.doc(FirestorePaths.user(userId)).get();
    final name = doc.exists ? AppUser.fromFirestore(doc).name : 'Unknown';
    _userNames[userId] = name;
    return name;
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final userId = context.read<AuthCubit>().state.userId;
    if (userId == null) return;
    await context.read<CommentService>().addComment(
          teamId: widget.teamId,
          taskId: widget.taskId,
          userId: userId,
          text: text,
        );
    _commentController.clear();
    _commentFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final taskService = context.read<TaskService>();
    final commentService = context.read<CommentService>();
    final userId = context.read<AuthCubit>().state.userId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder(
      stream: taskService.watchTask(widget.teamId, widget.taskId),
      builder: (context, taskSnapshot) {
        if (!taskSnapshot.hasData) {
          return const Scaffold(body: FullPageLoader());
        }
        final task = taskSnapshot.data!;
        final isOverdue = task.dueDate != null && task.dueDate!.isBefore(DateTime.now()) && !task.isDone;
        final myStatus = userId != null && task.assigneeStatus[userId] == 'done';

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => showErrorSnackBar(context, 'Edit coming soon.'),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: task.isDone
                                ? AppColors.success.withOpacity(0.1)
                                : isOverdue
                                    ? AppColors.error.withOpacity(0.1)
                                    : AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: task.isDone
                                  ? AppColors.success.withOpacity(0.3)
                                  : isOverdue
                                      ? AppColors.error.withOpacity(0.3)
                                      : AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                task.isDone ? Icons.check_circle_rounded : isOverdue ? Icons.warning_rounded : Icons.pending_rounded,
                                color: task.isDone ? AppColors.success : isOverdue ? AppColors.error : AppColors.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                task.isDone ? 'Completed' : isOverdue ? 'Overdue' : 'In Progress',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w700,
                                  color: task.isDone ? AppColors.success : isOverdue ? AppColors.error : AppColors.primary,
                                  fontSize: 15,
                                ),
                              ),
                              const Spacer(),
                              if (task.dueDate != null)
                                Text(
                                  'Due ${DateFormat.MMMd().format(task.dueDate!)}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isOverdue ? AppColors.error : null,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Description
                        _SectionHeader(title: 'Description'),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                          ),
                          child: Text(
                            task.description?.isNotEmpty == true ? task.description! : 'No description provided.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: task.description?.isNotEmpty == true
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                  height: 1.6,
                                ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Assignees
                        _SectionHeader(title: 'Assigned To', count: task.assignedTo.length),
                        const SizedBox(height: 10),
                        if (task.assignedTo.isEmpty)
                          Text('No one assigned', style: Theme.of(context).textTheme.bodyMedium)
                        else
                          ...task.assignedTo.map((id) {
                            final done = task.assigneeStatus[id] == 'done';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: FutureBuilder<String>(
                                future: _userName(id),
                                builder: (_, snap) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.cardDark : AppColors.cardLight,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: done ? AppColors.success.withOpacity(0.15) : AppColors.primary.withOpacity(0.1),
                                          child: Text(
                                            (snap.data ?? '?').isNotEmpty ? (snap.data ?? '?')[0].toUpperCase() : '?',
                                            style: TextStyle(
                                              fontFamily: 'Nunito',
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: done ? AppColors.success : AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            snap.data ?? '...',
                                            style: Theme.of(context).textTheme.titleSmall,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: done ? AppColors.success.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            done ? 'Done' : 'Pending',
                                            style: TextStyle(
                                              fontFamily: 'Nunito',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: done ? AppColors.success : AppColors.warning,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          }),

                        const SizedBox(height: 24),

                        // Meta info
                        Row(
                          children: [
                            Expanded(
                              child: _MetaChip(
                                icon: Icons.calendar_today_rounded,
                                label: 'Created',
                                value: DateFormat.MMMd().format(task.createdAt),
                              ),
                            ),
                            if (task.dueDate != null) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetaChip(
                                  icon: Icons.event_rounded,
                                  label: 'Due Date',
                                  value: DateFormat.MMMd().format(task.dueDate!),
                                  color: isOverdue ? AppColors.error : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Comments
                        _SectionHeader(title: 'Comments'),
                        const SizedBox(height: 12),
                        StreamBuilder<List<TaskComment>>(
                          stream: commentService.watchComments(widget.teamId, widget.taskId),
                          builder: (context, commentSnapshot) {
                            final comments = commentSnapshot.data ?? [];
                            return Column(
                              children: [
                                ...comments.map((c) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: FutureBuilder<String>(
                                        future: _userName(c.userId),
                                        builder: (_, snap) {
                                          return Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: isDark ? AppColors.cardDark : AppColors.cardLight,
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                                  child: Text(
                                                    (snap.data ?? '?').isNotEmpty ? (snap.data ?? '?')[0].toUpperCase() : '?',
                                                    style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primary),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(snap.data ?? '...', style: Theme.of(context).textTheme.labelLarge),
                                                      const SizedBox(height: 4),
                                                      Text(c.text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                        color: Theme.of(context).colorScheme.onSurface,
                                                        height: 1.4,
                                                      )),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    )),
                                // Comment input
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _commentController,
                                        focusNode: _commentFocus,
                                        style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w500, fontSize: 14),
                                        decoration: InputDecoration(
                                          hintText: 'Add a comment...',
                                          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontFamily: 'Nunito'),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        ),
                                        textInputAction: TextInputAction.send,
                                        onSubmitted: (_) => _addComment(),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                        onPressed: _addComment,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 32),

                        // Mark done button
                        if (userId != null && !task.isDone && !myStatus)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                await taskService.markAssigneeDone(
                                  teamId: widget.teamId,
                                  taskId: task.id,
                                  userId: userId,
                                );
                                if (mounted) showSuccessSnackBar(context, 'Marked as done! 🎉');
                              },
                              icon: const Icon(Icons.check_rounded, size: 20),
                              label: const Text('Mark as Done'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.success,
                                padding: const EdgeInsets.symmetric(vertical: 16),
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
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count});
  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.value, this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? AppColors.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: color ?? Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}