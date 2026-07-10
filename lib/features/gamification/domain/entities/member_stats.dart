import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// `member_stats/{uid}` — points, activity, optional title and FAM coins.
class MemberStats extends Equatable {
  const MemberStats({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.points,
    required this.storiesCreated,
    required this.gamesWon,
    this.famCoins = 0,
    this.displayTitle = '',
    this.currentStreak = 0,
    this.longestStreak = 0,
  });

  final String uid;
  final String email;
  final String displayName;
  final int points;
  final int storiesCreated;
  final int gamesWon;

  /// Spendable-style family tokens (earned with activity; not real money).
  final int famCoins;

  /// Optional preset title chosen in profile (see [TitleCatalog]).
  final String displayTitle;

  /// Consecutive days with at least one recorded activity (story, approved
  /// task, or game win). Resets to 1 the day after a gap; see
  /// [StreakMilestones] for the "don't break the chain" reward ladder.
  final int currentStreak;

  /// Best [currentStreak] ever reached — used for streak badges, which stay
  /// earned even after a streak breaks.
  final int longestStreak;

  factory MemberStats.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return MemberStats(
      uid: doc.id,
      email: (d['email'] as String? ?? '').toLowerCase(),
      displayName: d['displayName'] as String? ?? '',
      points: (d['points'] as num?)?.toInt() ?? 0,
      storiesCreated: (d['storiesCreated'] as num?)?.toInt() ?? 0,
      gamesWon: (d['gamesWon'] as num?)?.toInt() ?? 0,
      famCoins: (d['famCoins'] as num?)?.toInt() ?? 0,
      displayTitle: (d['displayTitle'] as String? ?? '').trim(),
      currentStreak: (d['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (d['longestStreak'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        email,
        displayName,
        points,
        storiesCreated,
        gamesWon,
        famCoins,
        displayTitle,
        currentStreak,
        longestStreak,
      ];
}
