import 'dart:io';

import '../entities/family_user_profile.dart';

abstract class UserProfileRepository {
  Stream<FamilyUserProfile?> watchProfile(String uid);

  /// Creates/merges `users/{uid}` with auth basics and active familyId.
  Future<void> ensureMyUserDoc();

  /// Uploads image to family-scoped Storage and updates both
  /// `users/{uid}.avatarUrl` + `families/{fid}/members/{uid}.avatarUrl`.
  Future<void> uploadAvatarFile(File imageFile);

  /// Updates per-family member preferences.
  Future<void> updateMyProfile({
    required String displayName,
    required String greeting,
  });
}
