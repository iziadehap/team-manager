import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../models/team.dart';
import '../../cubits/auth/auth_cubit.dart';
import '../../services/team_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/error_banner.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _icon = '📁';
  bool _loading = false;
  Team? _createdTeam;

  static const _iconOptions = ['📁', '🎨', '💻', '📣', '⚽', '🚀'];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = context.read<AuthCubit>().state.userId;
    if (userId == null) return;

    setState(() => _loading = true);
    try {
      final team = await context.read<TeamService>().createTeam(
            userId: userId,
            name: _nameController.text,
            description: _descController.text,
            icon: _icon,
          );
      setState(() => _createdTeam = team);
    } on AppException catch (e) {
      if (mounted) showErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _inviteLink {
    final code = _createdTeam?.inviteCode ?? '';
    return '${AppConstants.inviteLinkBase}/$code';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CREATE TEAM')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _nameController,
                label: 'Team Name',
                icon: Icons.folder_outlined,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _descController,
                label: 'Description (optional)',
                icon: Icons.notes,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text('Team icon'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _iconOptions.map((icon) {
                  final selected = icon == _icon;
                  return ChoiceChip(
                    label: Text(icon, style: const TextStyle(fontSize: 24)),
                    selected: selected,
                    onSelected: (_) => setState(() => _icon = icon),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              if (_createdTeam == null)
                FilledButton(
                  onPressed: _loading ? null : _create,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('CREATE TEAM'),
                  ),
                )
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🔗 INVITE LINK',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SelectableText(_inviteLink),
                        const SizedBox(height: 8),
                        Text('Code: ${_createdTeam!.inviteCode}'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            Share.share(
                              'Join my team on TeamTask!\n$_inviteLink',
                            );
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('SHARE'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(
                    '/teams/${_createdTeam!.id}/tasks',
                  ),
                  child: const Text('GO TO TEAM'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
