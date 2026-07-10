import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../../core/media/media_upload_service.dart';
import '../../family/data/family_scope.dart';
import '../domain/entities/vault_item.dart';
import '../domain/repositories/vault_repository.dart';

class VaultRepositoryImpl implements VaultRepository {
  VaultRepositoryImpl({
    required FamilyScope scope,
    required Set<String> familyMemberEmails,
    String? memberDisplayName,
    FirebaseAuth? auth,
    MediaUploadService? mediaUpload,
  })  : _scope = scope,
        _familyEmails = familyMemberEmails,
        _displayName = memberDisplayName,
        _auth = auth ?? FirebaseAuth.instance,
        _mediaUpload = mediaUpload ?? CloudinaryMediaUploadService();

  final FamilyScope _scope;
  final Set<String> _familyEmails;
  final String? _displayName;
  final FirebaseAuth _auth;
  final MediaUploadService _mediaUpload;

  CollectionReference<Map<String, dynamic>> get _items => _scope.vaultItems;

  User get _user {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    return u;
  }

  String _name(User u) {
    final memberName = _displayName?.trim();
    if (memberName != null && memberName.isNotEmpty) {
      return memberName;
    }
    final n = u.displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return u.email ?? 'Family';
  }

  VaultItem _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['createdAt'];
    DateTime created;
    if (ts is Timestamp) {
      created = ts.toDate();
    } else {
      created = DateTime.fromMillisecondsSinceEpoch(0);
    }
    final tags = (d['personTags'] as List<dynamic>?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        const <String>[];
    return VaultItem(
      id: doc.id,
      title: d['title'] as String? ?? '',
      downloadUrl: d['downloadUrl'] as String? ?? '',
      storagePath: d['storagePath'] as String? ?? '',
      uploaderUid: d['uploaderUid'] as String? ?? '',
      uploaderName: d['uploaderName'] as String? ?? '',
      uploaderEmail: (d['uploaderEmail'] as String? ?? '').toLowerCase(),
      personTags: tags,
      eventTag: d['eventTag'] as String?,
      createdAt: created,
      contentType: d['contentType'] as String? ?? 'image/jpeg',
      extractedText: d['extractedText'] as String? ?? '',
    );
  }

  @override
  Stream<List<VaultItem>> watchItems({int limit = 200}) {
    return _items
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  @override
  Future<void> uploadPhoto({
    required File file,
    required String title,
    required List<String> personTags,
    String? eventTag,
    String? extractedText,
  }) async {
    final u = _user;
    final email = u.email?.toLowerCase();
    if (email == null) throw StateError('No email');
    final lower = personTags.map((e) => e.trim().toLowerCase()).toSet();
    final tags = _familyEmails.isEmpty
        ? lower.toList()
        : lower.where(_familyEmails.contains).toList();

    final id = const Uuid().v4();
    final uploaded = await _mediaUpload.uploadFile(
      file: file,
      folder: 'vault',
      ownerUid: u.uid,
      fileName: id,
      contentType: 'image/jpeg',
    );

    final ev = eventTag?.trim();
    await _items.doc(id).set({
      'title': title.trim().isEmpty ? 'Photo' : title.trim(),
      'downloadUrl': uploaded.url,
      'storagePath': uploaded.storagePath,
      'uploaderUid': u.uid,
      'uploaderName': _name(u),
      'uploaderEmail': email,
      'personTags': tags,
      'eventTag': (ev != null && ev.isNotEmpty) ? ev : null,
      'createdAt': FieldValue.serverTimestamp(),
      'contentType': uploaded.contentType,
      'extractedText': (extractedText ?? '').trim(),
    });
  }

  @override
  Future<void> deleteItem(String itemId) async {
    final snap = await _items.doc(itemId).get();
    if (!snap.exists) return;
    final item = _fromDoc(snap);
    if (item.uploaderUid != _user.uid) {
      throw StateError('Only the uploader can delete this item.');
    }
    // Cloudinary unsigned uploads cannot be deleted securely from client.
    // We still remove the Firestore record so the vault view updates.
    await _items.doc(itemId).delete();
  }
}
