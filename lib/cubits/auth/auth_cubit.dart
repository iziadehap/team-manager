import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/auth_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._authService) : super(AuthState(user: _authService.firebaseUser)) {
    _authSubscription = _authService.authStateChanges.listen(_onAuthChanged);
  }

  final AuthService _authService;
  late final StreamSubscription<User?> _authSubscription;

  void _onAuthChanged(User? user) {
    emit(state.copyWith(user: user, profile: user == null ? null : state.profile));
  }

  Future<void> loadProfile() async {
    final profile = await _authService.getCurrentUserProfile();
    emit(state.copyWith(profile: profile));
  }

  Future<void> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _authService.signIn(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
      emit(state.copyWith(user: _authService.firebaseUser, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false));
      rethrow;
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(isLoading: true));
    try {
      await _authService.register(
        name: name,
        email: email,
        password: password,
      );
      emit(state.copyWith(user: _authService.firebaseUser, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false));
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    emit(const AuthState());
  }

  Future<void> updateProfile({required String name, String? photoUrl}) async {
    await _authService.updateProfile(name: name, photoUrl: photoUrl);
    await loadProfile();
  }

  @override
  Future<void> close() {
    _authSubscription.cancel();
    return super.close();
  }
}
