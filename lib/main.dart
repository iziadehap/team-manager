import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:team_manager/services/user_service.dart';

import 'app/app.dart';
import 'cubits/auth/auth_cubit.dart';
import 'cubits/theme/theme_cubit.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'services/comment_service.dart';
import 'services/notification_service.dart';
import 'services/task_service.dart';
import 'services/team_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final authService = AuthService();
  final authCubit = AuthCubit(authService);
  final themeCubit = ThemeCubit()..load();
  final notificationService = NotificationService();
  await notificationService.initialize();

  final router = createAppRouter(authCubit);

  // await makeCollections();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<UserService>(create: (_) => UserService()),

        RepositoryProvider<AuthService>.value(value: authService),
        RepositoryProvider(create: (_) => TeamService()),
        RepositoryProvider(create: (_) => TaskService()),
        RepositoryProvider(create: (_) => CommentService()),
        RepositoryProvider<NotificationService>.value(
          value: notificationService,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<ThemeCubit>.value(value: themeCubit),
        ],
        child: TeamTaskApp(router: router),
      ),
    ),
  );
}
