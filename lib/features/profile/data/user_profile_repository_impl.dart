import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/media/media_upload_service.dart';
import '../../family/data/family_scope.dart';
import '../domain/entities/family_user_profile.dart';
import '../domain/repositories/user_profile_repository.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  UserProfileRepositoryImpl({
    required FamilyScope scope,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    MediaUploadService? mediaUpload,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _scope = scope,
        _auth = auth ?? FirebaseAuth.instance,
        _mediaUpload = mediaUpload ?? FirebaseStorageMediaUploadService();

  final FirebaseFirestore _db;
  final FamilyScope _scope;
  final FirebaseAuth _auth;
  final MediaUploadService _mediaUpload;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  User get _user {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    return u;
  }

  FamilyUserProfile? _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists || doc.data() == null) return null;
    final d = doc.data()!;
    final email = (d['email'] as String? ?? '').toLowerCase();
    return FamilyUserProfile(
      uid: doc.id,
      email: email,
      familyId: (d['familyId'] as String? ?? '').trim(),
      displayName: (d['displayName'] as String? ?? 'Family').trim(),
      isParent: false,
      greeting: (d['greeting'] as String? ?? '').trim(),
      avatarUrl: d['avatarUrl'] as String?,
      fcmToken: d['fcmToken'] as String?,
    );
  }

  @override
  Stream<FamilyUserProfile?> watchProfile(String uid) {
    return _userRef(uid).snapshots().map(_fromDoc);
  }

  @override
  Future<void> ensureMyUserDoc() async {
    final u = _user;
    final email = u.email?.toLowerCase();
    if (email == null) return;
    await _userRef(u.uid).set(
      {
        'email': email,
        'familyId': _scope.familyId,
        'displayName': u.displayName ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> uploadAvatarFile(File imageFile) async {
    final u = _user;
    final uploaded = await _mediaUpload.uploadFile(
      familyId: _scope.familyId,
      file: imageFile,
      folder: 'avatars',
      ownerUid: u.uid,
      fileName: 'avatar',
      contentType: 'image/jpeg',
    );
    final url = uploaded.url;
    await _userRef(u.uid).set(
      {
        'avatarUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await _scope.members.doc(u.uid).set(
      {
        'avatarUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    try {
      await u.updatePhotoURL(url);
    } catch (_) {
      // Auth may reject some URLs; Firestore still holds avatarUrl for the app.
    }
  }

  @override
  Future<void> updateMyProfile({
    required String displayName,
    required String greeting,
  }) async {
    final u = _user;
    await _scope.members.doc(u.uid).set(
      {
        'displayName': displayName.trim(),
        'greeting': greeting.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await _userRef(u.uid).set(
      {
        'displayName': displayName.trim(),
        'greeting': greeting.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
