import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/presentation/providers/family_providers.dart';
import '../../data/user_profile_repository_impl.dart';
import '../../domain/entities/family_user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final scope = ref.watch(familyScopeProvider);
  return UserProfileRepositoryImpl(scope: scope);
});

final myUserProfileProvider = StreamProvider<FamilyUserProfile?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value(null);
  }
  return ref.watch(userProfileRepositoryProvider).watchProfile(uid);
});
