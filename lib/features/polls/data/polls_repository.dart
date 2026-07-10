import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../family/data/family_scope.dart';
import '../domain/family_poll.dart';

class PollsRepository {
  PollsRepository({
    required FamilyScope scope,
    FirebaseAuth? auth,
  })  : _scope = scope,
        _auth = auth ?? FirebaseAuth.instance;

  final FamilyScope _scope;
  final FirebaseAuth _auth;

  Stream<List<FamilyPoll>> watchPolls({int limit = 40}) {
    return _scope.polls
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(FamilyPoll.fromDoc).toList());
  }

  /// `uid` -> `a` | `b` | `c` | `d`.
  Stream<Map<String, String>> watchResponses(String pollId) {
    return _scope.polls
        .doc(pollId)
        .collection('responses')
        .snapshots()
        .map((s) {
      final out = <String, String>{};
      for (final d in s.docs) {
        final p = d.data()['pick'];
        if (p is String &&
            (p == 'a' || p == 'b' || p == 'c' || p == 'd')) {
          out[d.id] = p;
        }
      }
      return out;
    });
  }

  Future<void> createPoll({
    required String question,
    required String optionA,
    required String optionB,
    String? optionC,
    String? optionD,
    DateTime? closesAt,
    bool anonymous = false,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    final q = question.trim();
    final a = optionA.trim();
    final b = optionB.trim();
    final c = optionC?.trim() ?? '';
    final d = optionD?.trim() ?? '';
    if (q.isEmpty || a.isEmpty || b.isEmpty) {
      throw ArgumentError('Fill in the question and both base options.');
    }
    final payload = <String, dynamic>{
      'question': q,
      'optionA': a,
      'optionB': b,
      'createdBy': u.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'closed': false,
      'anonymous': anonymous,
    };
    if (c.isNotEmpty) payload['optionC'] = c;
    if (d.isNotEmpty) payload['optionD'] = d;
    if (closesAt != null) {
      payload['closesAt'] = Timestamp.fromDate(closesAt);
    }
    await _scope.polls.add(payload);
  }

  Future<void> closePoll(String pollId) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    final snap = await _scope.polls.doc(pollId).get();
    final data = snap.data();
    if (data == null) return;
    if (data['createdBy'] != u.uid) {
      throw StateError('Only the creator can close this poll.');
    }
    await _scope.polls.doc(pollId).update({
      'closed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setMyVote({
    required String pollId,
    required String pick,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    if (pick != 'a' && pick != 'b' && pick != 'c' && pick != 'd') return;
    await _scope.polls
        .doc(pollId)
        .collection('responses')
        .doc(uid)
        .set({'pick': pick});
  }

  Future<void> deletePoll(String pollId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snap = await _scope.polls.doc(pollId).get();
    final data = snap.data();
    if (data == null) return;
    if (data['createdBy'] != uid) {
      throw StateError('Only the creator can delete this poll.');
    }
    final responses = await _scope.polls
        .doc(pollId)
        .collection('responses')
        .get();
    final batch = _scope.firestore.batch();
    for (final d in responses.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_scope.polls.doc(pollId));
    await batch.commit();
  }
}
