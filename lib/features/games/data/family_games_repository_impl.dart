import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../family/data/family_scope.dart';
import '../../gamification/domain/repositories/gamification_repository.dart';
import '../domain/entities/creative_submission.dart';
import '../domain/repositories/family_games_repository.dart';

class FamilyGamesRepositoryImpl implements FamilyGamesRepository {
  FamilyGamesRepositoryImpl({
    required FamilyScope scope,
    GamificationRepository? gamification,
    String? memberDisplayName,
    FirebaseAuth? auth,
  })  : _scope = scope,
        _gamification = gamification,
        _displayName = memberDisplayName,
        _auth = auth ?? FirebaseAuth.instance;

  final FamilyScope _scope;
  final GamificationRepository? _gamification;
  final String? _displayName;
  final FirebaseAuth _auth;

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

  Future<void> _maybeReward() async {
    try {
      await _gamification?.recordGameRoundWon(points: 5);
    } catch (_) {}
  }

  CreativeSubmission _creativeFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['createdAt'];
    DateTime created;
    if (ts is Timestamp) {
      created = ts.toDate();
    } else {
      created = DateTime.fromMillisecondsSinceEpoch(0);
    }
    return CreativeSubmission(
      id: doc.id,
      promptKey: d['promptKey'] as String? ?? '',
      body: d['body'] as String? ?? '',
      authorUid: d['authorUid'] as String? ?? '',
      authorName: d['authorName'] as String? ?? '',
      createdAt: created,
    );
  }

  @override
  Future<void> submitTimeTravelResponse({
    required String storyId,
    required String storyTitle,
    String? storyImageUrl,
    required String response,
  }) async {
    final u = _user;
    final trimmed = response.trim();
    if (trimmed.isEmpty) throw ArgumentError('Write something first.');
    await _scope.timeTravelEntries.add({
      'storyId': storyId,
      'storyTitle': storyTitle,
      'storyImageUrl': storyImageUrl,
      'response': trimmed,
      'authorUid': u.uid,
      'authorName': _name(u),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _maybeReward();
  }

  @override
  Future<void> submitCreativeChallenge({
    required String promptKey,
    required String body,
  }) async {
    final u = _user;
    final trimmed = body.trim();
    if (trimmed.isEmpty) throw ArgumentError('Write something first.');
    await _scope.creativeSubmissions.add({
      'promptKey': promptKey,
      'body': trimmed,
      'authorUid': u.uid,
      'authorName': _name(u),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _maybeReward();
  }

  @override
  Stream<List<CreativeSubmission>> watchCreativeForPrompt(
    String promptKey, {
    int limit = 40,
  }) {
    return _scope.creativeSubmissions
        .orderBy('createdAt', descending: true)
        .limit(120)
        .snapshots()
        .map(
          (s) => s.docs
              .map(_creativeFromDoc)
              .where((c) => c.promptKey == promptKey)
              .take(limit)
              .toList(),
        );
  }
}
