import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/domain/entities/family_role.dart';
import '../domain/entities/family.dart';
import '../domain/entities/family_member.dart';

/// Manages family lifecycle: create / join / leave, plus member-doc reads.
///
/// Firestore layout:
/// - `families/{fid}` — top-level family doc.
/// - `families/{fid}/members/{uid}` — per-member identity (name, role,
///    greeting, avatar).
/// - `users/{uid}` — global pointer with `familyId`, `email`, `fcmToken`.
class FamilyRepository {
  FamilyRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _families =>
      _db.collection('families');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  User get _user {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    return u;
  }

  // ───────────────────────── Reads ─────────────────────────

  /// Streams the current user's `users/{uid}.familyId`. Null until the user
  /// has created or joined a family.
  ///
  /// Reacts to `authStateChanges()` (not just a one-time `currentUser`
  /// read) so that signing out and a different user signing back in on the
  /// same app session re-subscribes to *that* user's doc instead of
  /// getting stuck on a permission-denied error against the previous
  /// user's uid — mirrors the same pattern already used by the router's
  /// `_routerFamilyIdProvider` (see core/router/app_router.dart).
  Stream<String?> watchMyFamilyId() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(null);
      return _users.doc(user.uid).snapshots().map((s) {
        if (!s.exists) return null;
        final fid = s.data()?['familyId'];
        return fid is String && fid.isNotEmpty ? fid : null;
      });
    });
  }

  /// Streams the family doc for [familyId]. Emits null while the doc loads
  /// or if it was deleted.
  Stream<Family?> watchFamily(String familyId) {
    return _families.doc(familyId).snapshots().map(_familyFromDoc);
  }

  /// Streams members of [familyId], ordered by joinedAt.
  Stream<List<FamilyMember>> watchMembers(String familyId) {
    return _families
        .doc(familyId)
        .collection('members')
        .orderBy('joinedAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(_memberFromDoc).toList());
  }

  /// Streams the current user's member doc inside [familyId].
  Stream<FamilyMember?> watchMyMember(String familyId) {
    final u = _auth.currentUser;
    if (u == null) return Stream.value(null);
    return _families
        .doc(familyId)
        .collection('members')
        .doc(u.uid)
        .snapshots()
        .map((s) => s.exists ? _memberFromDoc(s) : null);
  }

  // ───────────────────────── Writes ─────────────────────────

  /// Creates a new family and adds the current
  /// user as the first member. Returns the new familyId.
  Future<String> createFamily({
    required String name,
    required String displayName,
    required String greeting,
  }) async {
    final u = _user;
    if (u.email == null) throw StateError('Account is missing an email.');
    if (name.trim().isEmpty) throw ArgumentError('Pick a family name.');
    if (displayName.trim().isEmpty) {
      throw ArgumentError('Add your display name.');
    }

    final code = await _allocateJoinCode();
    final familyRef = _families.doc();
    final memberRef = familyRef.collection('members').doc(u.uid);
    final userRef = _users.doc(u.uid);

    await _db.runTransaction((tx) async {
      final existingUser = await tx.get(userRef);
      final existingFamily = existingUser.data()?['familyId'];
      if (existingFamily is String && existingFamily.isNotEmpty) {
        throw StateError('You already belong to a family.');
      }

      tx.set(familyRef, {
        'name': name.trim(),
        'joinCode': code,
        'createdBy': u.uid,
        'ownerUid': u.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'memberCount': 1,
      });
      tx.set(memberRef, {
        'uid': u.uid,
        'email': u.email!.toLowerCase(),
        'displayName': displayName.trim(),
        'role': 'member',
        'greeting': greeting.trim(),
        'avatarUrl': null,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      tx.set(
        userRef,
        {
          'email': u.email!.toLowerCase(),
          'familyId': familyRef.id,
          'displayName': displayName.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    return familyRef.id;
  }

  /// Joins an existing family by [joinCode]. Throws if the code is invalid.
  Future<String> joinFamily({
    required String joinCode,
    required String displayName,
    required String greeting,
  }) async {
    final u = _user;
    if (u.email == null) throw StateError('Account is missing an email.');
    if (displayName.trim().isEmpty) {
      throw ArgumentError('Add your display name.');
    }

    final normalized = joinCode.trim().toUpperCase();
    if (normalized.length != 6) {
      throw ArgumentError('Invite codes are 6 characters.');
    }

    // `families` no longer allows client-side queries (see firestore.rules —
    // `joinCode` is a short, human-typed string that must never be
    // brute-forceable via a `where(...)` query), so lookup goes through a
    // Cloud Function running with the admin SDK instead.
    String resolvedFamilyId;
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('resolveJoinCode')
          .call<Map<String, dynamic>>({'joinCode': normalized});
      resolvedFamilyId = result.data['familyId'] as String? ?? '';
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') {
        throw StateError('No family found for that code.');
      }
      rethrow;
    }
    if (resolvedFamilyId.isEmpty) {
      throw StateError('No family found for that code.');
    }
    final familyRef = _families.doc(resolvedFamilyId);
    final memberRef = familyRef.collection('members').doc(u.uid);
    final userRef = _users.doc(u.uid);

    await _db.runTransaction((tx) async {
      final freshUser = await tx.get(userRef);
      final existing = freshUser.data()?['familyId'];
      if (existing is String && existing.isNotEmpty) {
        throw StateError('You already belong to a family.');
      }
      final freshFamily = await tx.get(familyRef);
      final data = freshFamily.data();
      if (data == null) throw StateError('Family vanished.');

      tx.set(memberRef, {
        'uid': u.uid,
        'email': u.email!.toLowerCase(),
        'displayName': displayName.trim(),
        'role': 'member',
        'greeting': greeting.trim(),
        'avatarUrl': null,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      tx.update(familyRef, {
        'memberCount': FieldValue.increment(1),
      });
      tx.set(
        userRef,
        {
          'email': u.email!.toLowerCase(),
          'familyId': familyRef.id,
          'displayName': displayName.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    return familyRef.id;
  }

  /// Transfers ownership to another member (current user must be owner).
  Future<void> transferOwnership({
    required String familyId,
    required String newOwnerUid,
  }) async {
    final u = _user;
    if (newOwnerUid.isEmpty || newOwnerUid == u.uid) {
      throw ArgumentError('Pick another member as the new owner.');
    }
    final familyRef = _families.doc(familyId);
    final newOwnerMember = familyRef.collection('members').doc(newOwnerUid);

    await _db.runTransaction((tx) async {
      final fam = await tx.get(familyRef);
      final data = fam.data();
      if (data == null) throw StateError('Family not found.');
      final owner = (data['ownerUid'] as String?) ?? data['createdBy'] as String?;
      if (owner != u.uid) {
        throw StateError('Only the family owner can transfer ownership.');
      }
      final m = await tx.get(newOwnerMember);
      if (!m.exists) {
        throw StateError('New owner must already be a member of this family.');
      }
      tx.update(familyRef, {
        'ownerUid': newOwnerUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Owner-only: opt in to optional daily digest push (see Cloud Functions).
  Future<void> updateDailyDigestOptIn({
    required String familyId,
    required bool enabled,
  }) async {
    await _families.doc(familyId).set(
      {
        'dailyDigestOptIn': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Sets or clears the short announcement shown on the family home dashboard.
  Future<void> updatePinnedAnnouncement({
    required String familyId,
    required String text,
  }) async {
    final t = text.trim();
    if (t.length > 200) {
      throw ArgumentError('Keep the announcement to 200 characters or less.');
    }
    await _families.doc(familyId).set(
      {
        'pinnedAnnouncement': t,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Updates the current user's per-family member doc.
  Future<void> updateMyMember({
    required String familyId,
    String? displayName,
    String? greeting,
    String? avatarUrl,
  }) async {
    final u = _user;
    final ref = _families.doc(familyId).collection('members').doc(u.uid);
    final patch = <String, dynamic>{};
    if (displayName != null && displayName.trim().isNotEmpty) {
      patch['displayName'] = displayName.trim();
    }
    if (greeting != null) patch['greeting'] = greeting.trim();
    if (avatarUrl != null) patch['avatarUrl'] = avatarUrl;
    if (patch.isEmpty) return;
    patch['updatedAt'] = FieldValue.serverTimestamp();
    await ref.set(patch, SetOptions(merge: true));

    // Mirror displayName onto users/{uid} so push targeting can fall back.
    if (patch.containsKey('displayName')) {
      await _users.doc(u.uid).set(
        {
          'displayName': patch['displayName'],
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  /// Removes the current user from [familyId]. The family doc is left intact
  /// (other members can keep using it). Stories/tasks/etc. authored by this
  /// user remain readable to remaining members.
  Future<void> leaveFamily(String familyId) async {
    final u = _user;
    final familyRef = _families.doc(familyId);
    final memberRef = familyRef.collection('members').doc(u.uid);
    final userRef = _users.doc(u.uid);

    await _db.runTransaction((tx) async {
      final freshMember = await tx.get(memberRef);
      if (!freshMember.exists) return;
      tx.delete(memberRef);
      tx.update(familyRef, {
        'memberCount': FieldValue.increment(-1),
      });
      tx.set(
        userRef,
        {
          'familyId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  // ───────────────────────── Helpers ─────────────────────────

  /// Allocates a fresh, collision-checked 6-char join code via the
  /// `allocateJoinCode` Cloud Function (admin SDK) — `families` no longer
  /// allows client-side queries (see firestore.rules), so uniqueness can't
  /// be checked directly from the client anymore.
  Future<String> _allocateJoinCode() async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('allocateJoinCode')
        .call<Map<String, dynamic>>();
    final code = result.data['joinCode'] as String?;
    if (code == null || code.isEmpty) {
      throw StateError('Could not allocate a join code, try again.');
    }
    return code;
  }

  Family? _familyFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) return null;
    final d = doc.data();
    if (d == null) return null;
    final ts = d['createdAt'];
    final created = ts is Timestamp ? ts.toDate() : DateTime.now();
    return Family(
      id: doc.id,
      name: (d['name'] as String? ?? 'Family').trim(),
      joinCode: (d['joinCode'] as String? ?? '').toUpperCase(),
      memberLimit: (d['memberLimit'] as num?)?.toInt() ?? 0,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: created,
      memberCount: (d['memberCount'] as num?)?.toInt() ?? 0,
      pinnedAnnouncement: (d['pinnedAnnouncement'] as String? ?? '').trim(),
      ownerUid: (d['ownerUid'] as String? ?? d['createdBy'] as String? ?? '').trim(),
      dailyDigestOptIn: d['dailyDigestOptIn'] == true,
      subscriptionActive: d['subscriptionActive'] == true,
      subscriptionProductId: (d['subscriptionProductId'] as String? ?? '').trim(),
      subscriptionExpiresAt: (d['subscriptionExpiresAt'] as Timestamp?)?.toDate(),
    );
  }

  FamilyMember _memberFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final ts = d['joinedAt'];
    final joined = ts is Timestamp ? ts.toDate() : DateTime.now();
    return FamilyMember(
      uid: doc.id,
      email: (d['email'] as String? ?? '').toLowerCase(),
      displayName: (d['displayName'] as String? ?? 'Family').trim(),
      role: FamilyRole.member,
      greeting: (d['greeting'] as String? ?? '').trim(),
      joinedAt: joined,
      avatarUrl: d['avatarUrl'] as String?,
    );
  }
}
