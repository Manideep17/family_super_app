import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../family/data/family_scope.dart';
import '../domain/entities/member_stats.dart';
import '../domain/entities/weekly_champion.dart';
import '../domain/repositories/gamification_repository.dart';
import '../domain/streak_milestones.dart';
import '../domain/title_catalog.dart';

class GamificationRepositoryImpl implements GamificationRepository {
  GamificationRepositoryImpl({
    required FamilyScope scope,
    String? memberDisplayName,
    FirebaseAuth? auth,
  })  : _scope = scope,
        _displayName = memberDisplayName,
        _auth = auth ?? FirebaseAuth.instance;

  final FamilyScope _scope;
  final String? _displayName;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _statsRef(String uid) =>
      _scope.memberStats.doc(uid);

  DocumentReference<Map<String, dynamic>> get _weeklyRef =>
      _scope.gamification.doc('weekly_champion');

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

  MemberStats _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      MemberStats.fromFirestore(doc);

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static bool _isDayBefore(String lastDayKey, String todayKey) {
    final last = DateTime.tryParse(lastDayKey);
    final today = DateTime.tryParse(todayKey);
    if (last == null || today == null) return false;
    return today.difference(last).inDays == 1;
  }

  /// Folds "did something today" streak bookkeeping into an existing
  /// activity write (new story, approved task, game win). One extra read
  /// per activity — fine at family-app scale.
  ///
  /// Returns the plain (non-`FieldValue`) fields to merge in, plus a
  /// `coinBonus` int the caller must add into its own `famCoins` increment
  /// (two separate `FieldValue.increment` calls on the same key in one
  /// `.set()` would silently clobber each other).
  Future<_StreakUpdate> _streakPatch(String uid) async {
    final snap = await _statsRef(uid).get();
    final d = snap.data() ?? const <String, dynamic>{};
    final todayKey = _dayKey(DateTime.now());
    final lastDay = d['lastActiveDay'] as String?;

    if (lastDay == todayKey) {
      // Already recorded activity today — no streak change.
      return const _StreakUpdate(fields: <String, dynamic>{}, coinBonus: 0);
    }

    var currentStreak = (d['currentStreak'] as num?)?.toInt() ?? 0;
    final longestBefore = (d['longestStreak'] as num?)?.toInt() ?? 0;
    currentStreak =
        (lastDay != null && _isDayBefore(lastDay, todayKey)) ? currentStreak + 1 : 1;
    final longestStreak =
        currentStreak > longestBefore ? currentStreak : longestBefore;

    final claimed = ((d['streakMilestonesClaimed'] as List<dynamic>?) ?? const [])
        .map((e) => (e as num).toInt())
        .toSet();
    var coinBonus = 0;
    for (final milestone in StreakMilestones.thresholds) {
      if (currentStreak >= milestone && !claimed.contains(milestone)) {
        claimed.add(milestone);
        coinBonus += StreakMilestones.coinsFor(milestone);
      }
    }

    return _StreakUpdate(
      fields: {
        'lastActiveDay': todayKey,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'streakMilestonesClaimed': claimed.toList(),
      },
      coinBonus: coinBonus,
    );
  }

  @override
  Future<void> syncWeeklyChampionFromLeaderboard(
    List<MemberStats> board,
  ) async {
    // No-op: weekly champion is owned by the `weeklyChampionRollup` Cloud
    // Function, which writes `families/{fid}/gamification/weekly_champion`.
    return;
  }

  @override
  Stream<WeeklyChampion?> watchWeeklyChampion() {
    return _weeklyRef.snapshots().map((s) {
      if (!s.exists || s.data() == null) return null;
      final m = s.data()!;
      return WeeklyChampion(
        weekId: m['weekId'] as String? ?? '',
        uid: m['championUid'] as String?,
        name: m['championName'] as String?,
        points: (m['championPoints'] as num?)?.toInt() ?? 0,
      );
    });
  }

  @override
  Future<void> ensureMyProfile() async {
    final u = _user;
    final email = u.email?.toLowerCase();
    if (email == null) return;
    await _statsRef(u.uid).set(
      {
        'email': email,
        'displayName': _name(u),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> addTaskRewardPoints({
    required String assigneeUid,
    required String assigneeEmail,
    required String assigneeName,
    required int points,
  }) async {
    if (assigneeUid.isEmpty) return;
    final delta = points < 0 ? 0 : points;
    final coinDelta = delta == 0 ? 0 : (delta ~/ 5).clamp(1, 500);
    final streak = await _streakPatch(assigneeUid);
    await _statsRef(assigneeUid).set(
      {
        'email': assigneeEmail.toLowerCase(),
        'displayName': assigneeName,
        'points': FieldValue.increment(delta),
        'famCoins': FieldValue.increment(coinDelta + streak.coinBonus),
        'updatedAt': FieldValue.serverTimestamp(),
        ...streak.fields,
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> recordStoryCreated() async {
    final u = _user;
    final email = u.email?.toLowerCase();
    if (email == null) return;
    final streak = await _streakPatch(u.uid);
    await _statsRef(u.uid).set(
      {
        'email': email,
        'displayName': _name(u),
        'storiesCreated': FieldValue.increment(1),
        'famCoins': FieldValue.increment(3 + streak.coinBonus),
        'updatedAt': FieldValue.serverTimestamp(),
        ...streak.fields,
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> recordGameRoundWon({int points = 10}) async {
    final u = _user;
    final email = u.email?.toLowerCase();
    if (email == null) return;
    final delta = points < 0 ? 0 : points;
    final streak = await _streakPatch(u.uid);
    await _statsRef(u.uid).set(
      {
        'email': email,
        'displayName': _name(u),
        'points': FieldValue.increment(delta),
        'gamesWon': FieldValue.increment(1),
        'famCoins': FieldValue.increment(2 + streak.coinBonus),
        'updatedAt': FieldValue.serverTimestamp(),
        ...streak.fields,
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> updateMyDisplayTitle(String? title) async {
    final u = _user;
    final t = title?.trim() ?? '';
    if (t.isNotEmpty && !TitleCatalog.isAllowed(t)) {
      throw ArgumentError('Pick a title from the list.');
    }
    final cost = TitleCatalog.coinCostFor(t);
    if (cost <= 0) {
      final patch = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (t.isEmpty) {
        patch['displayTitle'] = FieldValue.delete();
      } else {
        patch['displayTitle'] = t;
      }
      await _statsRef(u.uid).set(patch, SetOptions(merge: true));
      return;
    }

    await _scope.firestore.runTransaction((tx) async {
      final ref = _statsRef(u.uid);
      final snap = await tx.get(ref);
      final cur = snap.data();
      final coins = (cur?['famCoins'] as num?)?.toInt() ?? 0;
      if (coins < cost) {
        throw StateError('Need $cost FAM coins for that title.');
      }
      tx.set(
        ref,
        {
          'displayTitle': t,
          'famCoins': coins - cost,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<void> claimWeeklyChampionTitle() async {
    final u = _user;
    final champSnap = await _weeklyRef.get();
    final m = champSnap.data();
    final champUid = m?['championUid'] as String?;
    if (champUid == null || champUid != u.uid) {
      throw StateError('Only the weekly champion can claim this title.');
    }
    await _statsRef(u.uid).set(
      {
        'displayTitle': TitleCatalog.weeklyChampionTitle,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Stream<MemberStats?> watchMyMemberStats() {
    final u = _auth.currentUser;
    if (u == null) return Stream.value(null);
    return _statsRef(u.uid).snapshots().map((s) {
      if (!s.exists) return null;
      return _fromDoc(s);
    });
  }

  @override
  Stream<List<MemberStats>> watchLeaderboard({int limit = 20}) {
    return _scope.memberStats
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }
}

/// Result of [GamificationRepositoryImpl._streakPatch] — plain fields to
/// merge in, plus a coin bonus the caller folds into its own increment.
class _StreakUpdate {
  const _StreakUpdate({required this.fields, required this.coinBonus});
  final Map<String, dynamic> fields;
  final int coinBonus;
}
