import 'package:cloud_firestore/cloud_firestore.dart';

import '../network/retry.dart';
import '../network/sync_health.dart';
import '../../features/gamification/domain/week_id.dart';

class FreeWeeklyRollupService {
  FreeWeeklyRollupService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<void> runForFamily(String familyId) async {
    try {
      await withRetry(
        () async {
          final now = DateTime.now();
          final weekId = familyWeekId(now);
          final familyRef = _db.collection('families').doc(familyId);
          final championRef =
              familyRef.collection('gamification').doc('weekly_champion');
          final bestMomentsRef = familyRef.collection('best_moments').doc(weekId);

          final topStats = await familyRef
              .collection('member_stats')
              .orderBy('points', descending: true)
              .limit(1)
              .get();
          final championData = <String, dynamic>{'weekId': weekId};
          if (topStats.docs.isNotEmpty) {
            final d = topStats.docs.first.data();
            championData.addAll({
              'championUid': topStats.docs.first.id,
              'championName': d['displayName'] ?? d['email'] ?? 'Family',
              'championPoints': (d['points'] as num?)?.toInt() ?? 0,
            });
          }
          championData['updatedAt'] = FieldValue.serverTimestamp();
          await championRef.set(championData, SetOptions(merge: true));

          final storySnap = await familyRef
              .collection('stories')
              .orderBy('createdAt', descending: true)
              .limit(200)
              .get();
          final ranked = storySnap.docs.map((doc) {
            final d = doc.data();
            final rawReactions = d['reactions'];
            final reactionCount = rawReactions is Map ? rawReactions.length : 0;
            final commentCount = (d['commentCount'] as num?)?.toInt() ?? 0;
            final score = reactionCount * 2 + commentCount;
            final imageUrls = d['imageUrls'] as List<dynamic>? ?? const [];
            return <String, dynamic>{
              'id': doc.id,
              'title': d['title'] ?? '',
              'body': d['body'] ?? '',
              'authorName': d['authorName'] ?? '',
              'reactions': reactionCount,
              'commentCount': commentCount,
              'score': score,
              'firstImageUrl': imageUrls.isNotEmpty ? imageUrls.first : null,
            };
          }).toList()
            ..sort(
              (a, b) => ((b['score'] as int).compareTo(a['score'] as int)),
            );

          await bestMomentsRef.set({
            'weekId': weekId,
            'generatedAt': FieldValue.serverTimestamp(),
            'stories': ranked.take(5).toList(),
          }, SetOptions(merge: true));
        },
        timeout: const Duration(seconds: 20),
      );
      SyncHealth.recordSuccess('Rollup synced');
    } catch (e) {
      SyncHealth.recordError(e);
      rethrow;
    }
  }
}
