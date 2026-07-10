/// Auth surface — sign-in / sign-out + the auth state stream.
///
/// Per-family identity (display name, role, custom greeting) lives in
/// `families/{fid}/members/{uid}` and is exposed via `currentMemberProvider`.
abstract class AuthRepository {
  Stream<String?> authStateChanges();
  Future<void> signInWithEmail({required String email, required String password});
  Future<void> registerWithEmail({
    required String email,
    required String password,
  });
  Future<void> signInWithGoogle();
  Future<void> signOut();

  /// Sends a Firebase password-reset email (email/password accounts only).
  Future<void> sendPasswordResetEmail(String email);

  /// For email/password accounts that have not verified yet.
  Future<void> sendEmailVerification();

  String? get currentUserEmail;
  String? get currentUid;
}
