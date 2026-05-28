import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/firestore_paths.dart';
import '../core/errors/app_exception.dart';
import '../models/app_user.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const _rememberMeKey = 'remember_me';

  User? get firebaseUser => _auth.currentUser;
  bool get isLoggedIn => firebaseUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
    if (!value) {
      // Session-only: sign out when app restarts if not remembered.
      // Splash still checks currentUser for active session.
    }
  }

  Future<AppUser?> getCurrentUserProfile() async {
    final user = firebaseUser;
    if (user == null) return null;
    final doc = await _firestore.doc(FirestorePaths.user(user.uid)).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  Future<void> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await setRememberMe(rememberMe);
    } on FirebaseAuthException catch (e) {
      throw AppException(_mapAuthError(e));
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      final appUser = AppUser(
        id: user.uid,
        name: name.trim(),
        email: email.trim(),
        createdAt: DateTime.now(),
      );
      await _firestore
          .doc(FirestorePaths.user(user.uid))
          .set(appUser.toMap());
    } on FirebaseAuthException catch (e) {
      throw AppException(_mapAuthError(e));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> updateProfile({required String name, String? photoUrl}) async {
    final user = firebaseUser;
    if (user == null) throw AppException('Not signed in');
    await _firestore.doc(FirestorePaths.user(user.uid)).update({
      'name': name.trim(),
      if (photoUrl != null) 'photoUrl': photoUrl,
    });
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
