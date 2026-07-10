import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../../core/analytics/app_analytics.dart';
import '../../../core/media/media_upload_service.dart';
import '../../family/data/family_scope.dart';
import '../../gamification/domain/repositories/gamification_repository.dart';
import '../domain/entities/story.dart';
import '../domain/entities/story_comment.dart';
import '../domain/repositories/diary_repository.dart';

class DiaryRepositoryImpl implements DiaryRepository {
  DiaryRepositoryImpl({
    required FamilyScope scope,
    required GamificationRepository gamification,
    String? memberDisplayName,
    Set<String>? familyMemberEmails,
    FirebaseAuth? auth,
    MediaUploadService? mediaUpload,
  })  : _scope = scope,
        _gamification = gamification,
        _displayName = memberDisplayName,
        _familyEmails = familyMemberEmails ?? const {},
        _auth = auth ?? FirebaseAuth.instance,
        _mediaUpload = mediaUpload ?? CloudinaryMediaUploadService();

  final FamilyScope _scope;
  final GamificationRepository _gamification;
  final String? _displayName;
  final Set<String> _familyEmails;
  final FirebaseAuth _auth;
  final MediaUploadService _mediaUpload;

  CollectionReference<Map<String, dynamic>> get _stories => _scope.stories;

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

  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e.toString()).toList();
  }

  Story _storyFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['createdAt'];
    DateTime created;
    if (ts is Timestamp) {
      created = ts.toDate();
    } else {
      created = DateTime.fromMillisecondsSinceEpoch(0);
    }
    final raw = d['reactions'];
    final reactions = Map<String, String>.from(
      (raw is Map ? raw : const {})
          .map((k, v) => MapEntry(k.toString(), v.toString())),
    );
    return Story(
      id: doc.id,
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      mood: d['mood'] as String? ?? 'happy',
      authorUid: d['authorUid'] as String? ?? '',
      authorName: d['authorName'] as String? ?? '',
      taggedEmails: _stringList(d['taggedEmails']),
      imageUrls: _stringList(d['imageUrls']),
      videoUrls: _stringList(d['videoUrls']),
      createdAt: created,
      reactions: reactions,
      commentCount: (d['commentCount'] as num?)?.toInt() ?? 0,
    );
  }

  StoryComment _commentFromDoc(
    String storyId,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    final ts = d['createdAt'];
    DateTime created;
    if (ts is Timestamp) {
      created = ts.toDate();
    } else {
      created = DateTime.fromMillisecondsSinceEpoch(0);
    }
    return StoryComment(
      id: doc.id,
      storyId: storyId,
      text: d['text'] as String? ?? '',
      authorUid: d['authorUid'] as String? ?? '',
      authorName: d['authorName'] as String? ?? '',
      createdAt: created,
    );
  }

  @override
  Stream<List<Story>> watchStories({int limit = 60}) {
    return _stories
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(_storyFromDoc).toList());
  }

  @override
  Stream<Story?> watchStory(String storyId) {
    return _stories.doc(storyId).snapshots().map((s) {
      if (!s.exists) return null;
      return _storyFromDoc(s);
    });
  }

  @override
  Stream<List<StoryComment>> watchComments(String storyId) {
    return _stories
        .doc(storyId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => _commentFromDoc(storyId, d)).toList());
  }

  @override
  Future<String> createStory({
    required String title,
    required String body,
    required String mood,
    required List<String> taggedEmails,
    List<String> imageUrls = const [],
    List<String> videoUrls = const [],
  }) async {
    final u = _user;
    final lower = taggedEmails.map((e) => e.trim().toLowerCase()).toSet();
    // Filter to known family emails when we have a roster; otherwise pass-through.
    final tags = _familyEmails.isEmpty
        ? lower.toList()
        : lower.where(_familyEmails.contains).toList();

    final doc = await _stories.add({
      'title': title.trim(),
      'body': body.trim(),
      'mood': mood,
      'authorUid': u.uid,
      'authorName': _name(u),
      'authorEmail': u.email?.toLowerCase() ?? '',
      'taggedEmails': tags,
      'imageUrls':
          imageUrls.where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList(),
      'videoUrls':
          videoUrls.where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'reactions': <String, String>{},
      'commentCount': 0,
    });
    try {
      await _gamification.recordStoryCreated();
    } catch (_) {}
    await AppAnalytics.logEvent(
      'story_created',
      params: {'family_id': _scope.familyId, 'has_images': imageUrls.isNotEmpty},
    );
    return doc.id;
  }

  @override
  Future<String> uploadStoryImage(File file) async {
    final u = _user;
    final id = const Uuid().v4();
    final uploaded = await _mediaUpload.uploadFile(
      file: file,
      folder: 'stories',
      ownerUid: u.uid,
      fileName: id,
      contentType: 'image/jpeg',
    );
    return uploaded.url;
  }

  @override
  Future<void> addComment(String storyId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final u = _user;
    final batch = _scope.firestore.batch();
    final cRef = _stories.doc(storyId).collection('comments').doc();
    batch.set(cRef, {
      'text': trimmed,
      'authorUid': u.uid,
      'authorName': _name(u),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_stories.doc(storyId), {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();
    await AppAnalytics.logEvent(
      'story_commented',
      params: {'family_id': _scope.familyId},
    );
  }

  @override
  Future<void> setStoryReaction({
    required String storyId,
    String? emoji,
  }) async {
    final uid = _user.uid;
    final ref = _stories.doc(storyId);
    await _scope.firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final raw = data['reactions'];
      final reactions = Map<String, String>.from(
        (raw is Map ? raw : const {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );
      if (emoji == null) {
        reactions.remove(uid);
      } else if (reactions[uid] == emoji) {
        reactions.remove(uid);
      } else {
        reactions[uid] = emoji;
      }
      tx.update(ref, {'reactions': reactions});
    });
  }

  @override
  Future<void> reportStory({
    required String storyId,
    required String storyAuthorUid,
    required String preview,
  }) async {
    final u = _user;
    await _stories.doc(storyId).collection('reports').doc(u.uid).set({
      'reporterUid': u.uid,
      'familyId': _scope.familyId,
      'kind': 'diary',
      'targetAuthorUid': storyAuthorUid,
      'storyAuthorUid': storyAuthorUid,
      'preview': preview,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
