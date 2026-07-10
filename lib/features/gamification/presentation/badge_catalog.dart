import '../domain/entities/member_stats.dart';
import '../domain/streak_milestones.dart';

class BadgeView {
  const BadgeView(this.id, this.label, this.emoji);
  final String id;
  final String label;
  final String emoji;
}

/// Lightweight badge rules (client-side).
abstract final class BadgeCatalog {
  static List<BadgeView> badgesFor(MemberStats s) {
    final out = <BadgeView>[];
    if (s.famCoins >= 50) {
      out.add(const BadgeView('coin_collector', 'Coin collector', '🪙'));
    }
    if (s.points >= 30) {
      out.add(const BadgeView('helping_hand', 'Helping Hand', '🤝'));
    }
    if (s.storiesCreated >= 3) {
      out.add(const BadgeView('creative_genius', 'Creative Genius', '🎨'));
    }
    if (s.gamesWon >= 2) {
      out.add(const BadgeView('memory_master', 'Memory Master', '🧠'));
    }
    if (s.points >= 80) {
      out.add(const BadgeView('champion', 'Family Champion', '🏆'));
    }
    final streakMilestone = StreakMilestones.highestReached(s.longestStreak);
    if (streakMilestone != null) {
      out.add(
        BadgeView(
          'streak_$streakMilestone',
          StreakMilestones.labelFor(streakMilestone),
          StreakMilestones.emojiFor(streakMilestone),
        ),
      );
    }
    return out;
  }
}
