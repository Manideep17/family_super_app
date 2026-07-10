import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/family_repository.dart';
import '../../data/family_scope.dart';
import '../../domain/entities/family.dart' as family_entity;
import '../../domain/entities/family_member.dart';

/// Single instance of [FamilyRepository] used everywhere.
final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository();
});

/// Streams the currently-signed-in user's `users/{uid}.familyId`. Null when
/// signed out OR when signed in but not yet in a family (→ onboarding).
final currentFamilyIdProvider = StreamProvider<String?>((ref) {
  return ref.watch(familyRepositoryProvider).watchMyFamilyId();
});

/// The active family scope. Throws if no family is selected — every screen
/// that uses this is guarded by the router gate.
final familyScopeProvider = Provider<FamilyScope>((ref) {
  final fid = ref.watch(currentFamilyIdProvider).valueOrNull;
  if (fid == null || fid.isEmpty) {
    throw StateError(
      'familyScopeProvider read before currentFamilyIdProvider resolved.',
    );
  }
  return FamilyScope(familyId: fid, firestore: FirebaseFirestore.instance);
});

/// Family doc for the current scope.
final currentFamilyProvider = StreamProvider<family_entity.Family?>((ref) {
  final fid = ref.watch(currentFamilyIdProvider).valueOrNull;
  if (fid == null || fid.isEmpty) return Stream.value(null);
  return ref.watch(familyRepositoryProvider).watchFamily(fid);
});

/// All members of the current family.
final familyMembersProvider = StreamProvider<List<FamilyMember>>((ref) {
  final fid = ref.watch(currentFamilyIdProvider).valueOrNull;
  if (fid == null || fid.isEmpty) return Stream.value(const []);
  return ref.watch(familyRepositoryProvider).watchMembers(fid);
});

/// The signed-in user's per-family member doc (display name, role, greeting,
/// avatar). Null when signed out or onboarding.
final currentMemberProvider = StreamProvider<FamilyMember?>((ref) {
  final fid = ref.watch(currentFamilyIdProvider).valueOrNull;
  if (fid == null || fid.isEmpty) return Stream.value(null);
  return ref.watch(familyRepositoryProvider).watchMyMember(fid);
});

/// Plain auth uid (helper for repos).
final currentUidProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});
