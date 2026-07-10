import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/entities/moderation_report_entry.dart';

class ModerationReportsRepository {
  ModerationReportsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<ModerationReportEntry>> watchReportsForFamily(String familyId) {
    return _db
        .collectionGroup('reports')
        .where('familyId', isEqualTo: familyId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(ModerationReportEntry.fromDoc)
              .toList(growable: false),
        );
  }
}
