import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../family/data/family_scope.dart';
import '../domain/entities/family_prediction.dart';
import '../domain/repositories/predictions_repository.dart';

class PredictionsRepositoryImpl implements PredictionsRepository {
  PredictionsRepositoryImpl({
    required FamilyScope scope,
    String? memberDisplayName,
    FirebaseAuth? auth,
  })  : _scope = scope,
        _displayName = memberDisplayName,
        _auth = auth ?? FirebaseAuth.instance;

  final FamilyScope _scope;
  final String? _displayName;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _col => _scope.predictions;

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

  FamilyPrediction _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['createdAt'];
    DateTime created;
    if (ts is Timestamp) {
      created = ts.toDate();
    } else {
      created = DateTime.fromMillisecondsSinceEpoch(0);
    }
    return FamilyPrediction(
      id: doc.id,
      text: d['text'] as String? ?? '',
      predictorUid: d['predictorUid'] as String? ?? '',
      predictorName: d['predictorName'] as String? ?? '',
      createdAt: created,
      revealed: d['revealed'] as bool? ?? false,
      outcomeNote: d['outcomeNote'] as String?,
    );
  }

  @override
  Stream<List<FamilyPrediction>> watchPredictions({int limit = 80}) {
    return _col
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  @override
  Future<String> createPrediction(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ArgumentError('Empty prediction');
    final u = _user;
    final doc = await _col.add({
      'text': trimmed,
      'predictorUid': u.uid,
      'predictorName': _name(u),
      'createdAt': FieldValue.serverTimestamp(),
      'revealed': false,
    });
    return doc.id;
  }

  @override
  Future<void> revealPrediction(String id, {String? outcomeNote}) async {
    final snap = await _col.doc(id).get();
    if (!snap.exists) return;
    final p = _fromDoc(snap);
    if (p.predictorUid != _user.uid) {
      throw StateError('Only the author can reveal this prediction.');
    }
    await _col.doc(id).update({
      'revealed': true,
      'outcomeNote': outcomeNote?.trim(),
      'revealedAt': FieldValue.serverTimestamp(),
    });
  }
}
