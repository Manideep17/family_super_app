import '../entities/member_stats.dart';
import '../entities/weekly_champion.dart';

abstract class GamificationRepository {
  /// Ensures `member_stats/{uid}` exists with email/name (no point reset).
  Future<void> ensureMyProfile();

  /// Updates `gamification/weekly_champion` when week or top player changes.
  Future<void> syncWeeklyChampionFromLeaderboard(List<MemberStats> board);

  Stream<WeeklyChampion?> watchWeeklyChampion();

  Future<void> addTaskRewardPoints({
    required String assigneeUid,
    required String assigneeEmail,
    required String assigneeName,
    required int points,
  });

  Future<void> recordStoryCreated();

  /// +[points] and increments games won (Phase 3 mini-games).
  Future<void> recordGameRoundWon({int points = 10});

  /// Preset title on leaderboard / profile (`member_stats.displayTitle`).
  /// Premium titles deduct [TitleCatalog.coinCostFor] FAM coins in a transaction.
  Future<void> updateMyDisplayTitle(String? title);

  /// Sets [TitleCatalog.weeklyChampionTitle] if the current user is this week's
  /// champion (see `gamification/weekly_champion`).
  Future<void> claimWeeklyChampionTitle();

  Stream<MemberStats?> watchMyMemberStats();

  Stream<List<MemberStats>> watchLeaderboard({int limit});
}
