import 'package:firebase_auth/firebase_auth.dart';

import '../../models/app_user.dart';

class AuthState {
  const AuthState({
    this.user,
    this.profile,
    this.isLoading = false,
  });

  final User? user;
  final AppUser? profile;
  final bool isLoading;

  bool get isLoggedIn => user != null;
  String? get userId => user?.uid;
  String? get email => user?.email;

  AuthState copyWith({
    User? user,
    AppUser? profile,
    bool? isLoading,
  }) {
    return AuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
