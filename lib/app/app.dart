import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubits/theme/theme_cubit.dart';
import '../cubits/theme/theme_state.dart';
import 'theme/app_theme.dart';

class TeamTaskApp extends StatelessWidget {
  const TeamTaskApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, themeState) {
        return MaterialApp.router(
          title: 'TeamTask',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeState.mode,
          routerConfig: router,
        );
      },
    );
  }
}
