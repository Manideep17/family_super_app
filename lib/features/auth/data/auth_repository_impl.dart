import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_flags.dart';
import '../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _google = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  @override
  Stream<String?> authStateChanges() =>
      _auth.authStateChanges().map((u) => u?.email);

  @override
  String? get currentUserEmail => _auth.currentUser?.email;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    await _auth.signInWithEmailAndPassword(
      email: normalized,
      password: password,
    );
  }

  @override
  Future<void> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    await _auth.createUserWithEmailAndPassword(
      email: normalized,
      password: password,
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    final googleUser = await _google.signIn();
    if (googleUser == null) {
      throw FamilyAuthException('Sign-in was cancelled.');
    }
    final tokens = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _google.signOut(),
      _auth.signOut(),
    ]);
  }

  @override
  Future<void> deleteAccount() async {
    if (!AppFlags.functionsEnabled) {
      throw FamilyAuthException(
        'Account deletion needs the backend (Cloud Functions), which is off '
        'in this build. Email support to request deletion instead.',
      );
    }
    if (_auth.currentUser == null) {
      throw FamilyAuthException('Sign in first.');
    }
    try {
      await FirebaseFunctions.instance.httpsCallable('deleteAccount').call();
    } on FirebaseFunctionsException catch (e) {
      throw FamilyAuthException(e.message ?? 'Could not delete account (${e.code}).');
    }
    // The Auth user no longer exists server-side; clear the local session too.
    try {
      await _google.signOut();
    } catch (_) {
      // Ignore — Google session cleanup is best-effort.
    }
    await _auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw FamilyAuthException('Enter your email first.');
    }
    await _auth.sendPasswordResetEmail(email: normalized);
  }

  @override
  Future<void> sendEmailVerification() async {
    final u = _auth.currentUser;
    if (u == null) {
      throw FamilyAuthException('Sign in first.');
    }
    if (u.emailVerified) return;
    await u.sendEmailVerification();
  }
}

class FamilyAuthException implements Exception {
  FamilyAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
