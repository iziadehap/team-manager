import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/errors/app_exception.dart';
import '../../models/team.dart';
import '../../cubits/auth/auth_cubit.dart';
import '../../services/team_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/error_banner.dart';

class JoinTeamScreen extends StatefulWidget {
  const JoinTeamScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  State<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends State<JoinTeamScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  Team? _preview;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;
      _previewTeam();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _previewTeam() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    final team = await context.read<TeamService>().previewTeamByCode(code);
    if (mounted) setState(() => _preview = team);
  }

  Future<void> _join() async {
    final userId = context.read<AuthCubit>().state.userId;
    if (userId == null) return;

    setState(() => _loading = true);
    try {
      final team = await context.read<TeamService>().joinTeam(
            userId: userId,
            inviteCode: _codeController.text,
          );
      if (mounted) context.go('/teams/${team.id}/tasks');
    } on AppException catch (e) {
      if (mounted) showErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JOIN TEAM')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter invite code:'),
            const SizedBox(height: 8),
            AppTextField(
              controller: _codeController,
              label: 'Invite code',
              icon: Icons.vpn_key_outlined,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _previewTeam,
              child: const Text('Preview team'),
            ),
            if (_preview != null) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: Text(_preview!.icon,
                      style: const TextStyle(fontSize: 28)),
                  title: Text(_preview!.name),
                  subtitle: Text('${_preview!.memberCount} members'),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _join,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('JOIN TEAM'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                showErrorSnackBar(context, 'QR scanner coming soon.');
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('OR SCAN QR CODE'),
            ),
          ],
        ),
      ),
    );
  }
}
