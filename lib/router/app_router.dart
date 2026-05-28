import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/tasks/create_task_screen.dart';
import '../features/tasks/task_detail_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/teams/create_team_screen.dart';
import '../features/teams/join_team_screen.dart';
import '../features/teams/team_members_screen.dart';
import '../features/teams/teams_screen.dart';
import '../core/router/go_router_refresh.dart';
import '../cubits/auth/auth_cubit.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const teams = '/teams';
  static const createTeam = '/teams/create';
  static const joinTeam = '/teams/join';
  static const tasks = '/teams/:teamId/tasks';
  static const createTask = '/teams/:teamId/tasks/create';
  static const taskDetail = '/teams/:teamId/tasks/:taskId';
  static const teamMembers = '/teams/:teamId/members';
  static const profile = '/profile';
}

GoRouter createAppRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefresh(authCubit.stream),
    redirect: (context, state) {
      final loggedIn = authCubit.state.isLoggedIn;
      final onAuth = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;
      final onSplash = state.matchedLocation == AppRoutes.splash;

      if (onSplash) return null;
      if (!loggedIn && !onAuth) return AppRoutes.login;
      if (loggedIn && onAuth) return AppRoutes.teams;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.teams,
        builder: (_, __) => const TeamsScreen(),
      ),
      GoRoute(
        path: AppRoutes.createTeam,
        builder: (_, __) => const CreateTeamScreen(),
      ),
      GoRoute(
        path: AppRoutes.joinTeam,
        builder: (_, state) {
          final code = state.uri.queryParameters['code'];
          return JoinTeamScreen(initialCode: code);
        },
      ),
      GoRoute(
        path: AppRoutes.tasks,
        builder: (_, state) {
          final teamId = state.pathParameters['teamId']!;
          return TasksScreen(teamId: teamId);
        },
      ),
      GoRoute(
        path: AppRoutes.createTask,
        builder: (_, state) {
          final teamId = state.pathParameters['teamId']!;
          return CreateTaskScreen(teamId: teamId);
        },
      ),
      GoRoute(
        path: AppRoutes.taskDetail,
        builder: (_, state) {
          final teamId = state.pathParameters['teamId']!;
          final taskId = state.pathParameters['taskId']!;
          return TaskDetailScreen(teamId: teamId, taskId: taskId);
        },
      ),
      GoRoute(
        path: AppRoutes.teamMembers,
        builder: (_, state) {
          final teamId = state.pathParameters['teamId']!;
          return TeamMembersScreen(teamId: teamId);
        },
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
    ],
  );
}
