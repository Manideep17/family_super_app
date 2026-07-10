/// Streak milestone rules — "don't break the chain" mechanics.
///
/// [MemberStats.currentStreak] / [MemberStats.longestStreak] are maintained
/// server-side-ish in [GamificationRepositoryImpl] (folded into the same
/// writes that already record activity: a new story, an approved task, a
/// game win). Hitting a threshold for the first time awards a one-time FAM
/// coin bonus — see `streakMilestonesClaimed` on the Firestore doc, which
/// guards against re-awarding the same milestone after a streak resets and
/// climbs back up.
abstract final class StreakMilestones {
  /// Ordered ascending; keep ordered — [coinsFor] assumes it.
  static const List<int> thresholds = [3, 7, 30, 100];

  static int coinsFor(int milestone) {
    switch (milestone) {
      case 3:
        return 5;
      case 7:
        return 15;
      case 30:
        return 50;
      case 100:
        return 150;
      default:
        return 0;
    }
  }

  static String labelFor(int milestone) {
    switch (milestone) {
      case 3:
        return 'Spark';
      case 7:
        return 'Family Flame';
      case 30:
        return 'Bonfire';
      case 100:
        return 'Eternal Flame';
      default:
        return '$milestone-day streak';
    }
  }

  static String emojiFor(int milestone) {
    switch (milestone) {
      case 3:
        return '✨';
      case 7:
        return '🔥';
      case 30:
        return '🔥🔥';
      case 100:
        return '🏵️';
      default:
        return '🔥';
    }
  }

  /// Highest milestone reached at or below [longestStreak], or null.
  static int? highestReached(int longestStreak) {
    int? best;
    for (final t in thresholds) {
      if (longestStreak >= t) best = t;
    }
    return best;
  }
}
