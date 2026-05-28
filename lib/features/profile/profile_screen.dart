
// cat > /home/claude/lib/features/profile/profile_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../cubits/auth/auth_cubit.dart';
import '../../cubits/auth/auth_state.dart';
import '../../cubits/theme/theme_cubit.dart';
import '../../cubits/theme/theme_state.dart';
import '../../router/app_router.dart';
import '../../services/task_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/error_banner.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  Map<String, int> _stats = {'completed': 0, 'pending': 0};
  bool _notifications = true;
  bool _editing = false;
  bool _loadingStats = true;

  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _animCtrl.forward();
    _load();
  }

  Future<void> _load() async {
    final authCubit = context.read<AuthCubit>();
    await authCubit.loadProfile();
    final user = authCubit.state.profile;
    final userId = authCubit.state.userId;
    if (user != null) _nameController.text = user.name;
    if (userId != null && mounted) {
      final stats = await context.read<TaskService>().userTaskStats(userId);
      if (mounted) setState(() { _stats = stats; _loadingStats = false; });
    } else {
      if (mounted) setState(() => _loadingStats = false);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await context.read<AuthCubit>().updateProfile(name: _nameController.text.trim());
      setState(() => _editing = false);
      if (mounted) showSuccessSnackBar(context, 'Profile updated!');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        return BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, themeState) {
            final name = _nameController.text.isEmpty ? 'User' : _nameController.text;
            final email = authState.email ?? '';
            final initials = name.isNotEmpty ? name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase() : '?';

            return Scaffold(
              body: FadeTransition(
                opacity: CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      expandedHeight: 220,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                      actions: [
                        if (_editing)
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: FilledButton(
                              onPressed: _save,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              ),
                              child: const Text('Save'),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => setState(() => _editing = true),
                              style: IconButton.styleFrom(
                                backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [const Color(0xFF1A1040), AppColors.surfaceDark]
                                  : [const Color(0xFFECEAFF), AppColors.surfaceLight],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 80, 24, 20),
                            child: Row(
                              children: [
                                Hero(
                                  tag: 'avatar',
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [AppColors.primary, AppColors.primaryLight],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, fontFamily: 'Nunito')),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (_editing)
                                        AppTextField(controller: _nameController, label: 'Full Name')
                                      else
                                        Text(name, style: Theme.of(context).textTheme.titleLarge),
                                      const SizedBox(height: 4),
                                      Text(email, style: Theme.of(context).textTheme.bodyMedium),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Stats cards
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.check_circle_rounded,
                                    value: _loadingStats ? '—' : '${_stats['completed'] ?? 0}',
                                    label: 'Completed',
                                    color: AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.pending_rounded,
                                    value: _loadingStats ? '—' : '${_stats['pending'] ?? 0}',
                                    label: 'Pending',
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),

                            // Settings section
                            _SectionHeader('Preferences'),
                            const SizedBox(height: 12),
                            _SettingsCard(
                              children: [
                                _ToggleTile(
                                  icon: Icons.notifications_outlined,
                                  iconColor: AppColors.primary,
                                  title: 'Push Notifications',
                                  subtitle: 'Get notified about task updates',
                                  value: _notifications,
                                  onChanged: (v) => setState(() => _notifications = v),
                                ),
                                const Divider(height: 1),
                                _ToggleTile(
                                  icon: Icons.dark_mode_outlined,
                                  iconColor: const Color(0xFF9D8FE0),
                                  title: 'Dark Mode',
                                  subtitle: 'Switch to dark theme',
                                  value: themeState.mode == ThemeMode.dark,
                                  onChanged: (v) => context.read<ThemeCubit>().setDarkMode(v),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),
                            _SectionHeader('Account'),
                            const SizedBox(height: 12),
                            _SettingsCard(
                              children: [
                                _ActionTile(
                                  icon: Icons.help_outline_rounded,
                                  iconColor: AppColors.info,
                                  title: 'Help & Support',
                                  onTap: () {},
                                ),
                                const Divider(height: 1),
                                _ActionTile(
                                  icon: Icons.privacy_tip_outlined,
                                  iconColor: AppColors.accent,
                                  title: 'Privacy Policy',
                                  onTap: () {},
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Sign out?'),
                                      content: const Text('You will be returned to the login screen.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        FilledButton(
                                          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Sign Out'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await context.read<AuthCubit>().signOut();
                                    if (context.mounted) context.go(AppRoutes.login);
                                  }
                                },
                                icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                                label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.error, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label, required this.color});
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.iconColor, required this.title, required this.onTap});
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
            Icon(Icons.chevron_right_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}