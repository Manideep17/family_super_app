import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/retry.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../data/user_profile_repository_impl.dart';
import '../../domain/entities/family_user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final scope = ref.watch(familyScopeProvider);
  return UserProfileRepositoryImpl(scope: scope);
});

/// Reacts to `authStateChanges()` (not just a one-time `currentUser` read)
/// so that signing out and a different user signing back in on the same
/// app session re-subscribes for *that* user's profile instead of getting
/// stuck on the previous user's stream — see `FamilyRepository.watchMyFamilyId`
/// for the same fix applied to the family-id stream.
final myUserProfileProvider = StreamProvider<FamilyUserProfile?>((ref) {
  final repo = ref.watch(userProfileRepositoryProvider);
  return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream.value(null);
    return retryStream(() => repo.watchProfile(user.uid));
  });
});
