import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/presentation/providers/family_providers.dart';
import '../../data/gamification_repository_impl.dart';
import '../../domain/entities/member_stats.dart';
import '../../domain/entities/weekly_champion.dart';
import '../../domain/repositories/gamification_repository.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  final scope = ref.watch(familyScopeProvider);
  final me = ref.watch(currentMemberProvider).valueOrNull;
  return GamificationRepositoryImpl(
    scope: scope,
    memberDisplayName: me?.displayName,
  );
});

final leaderboardProvider = StreamProvider<List<MemberStats>>((ref) {
  return ref.watch(gamificationRepositoryProvider).watchLeaderboard();
});

final myMemberStatsProvider = StreamProvider<MemberStats?>((ref) {
  return ref.watch(gamificationRepositoryProvider).watchMyMemberStats();
});

final weeklyChampionProvider = StreamProvider<WeeklyChampion?>((ref) {
  return ref.watch(gamificationRepositoryProvider).watchWeeklyChampion();
});
