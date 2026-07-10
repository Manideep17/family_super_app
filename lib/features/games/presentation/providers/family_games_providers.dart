import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/presentation/providers/family_providers.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';
import '../../data/family_games_repository_impl.dart';
import '../../domain/entities/creative_submission.dart';
import '../../domain/repositories/family_games_repository.dart';

String creativeDayKey([DateTime? date]) {
  final d = date ?? DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final familyGamesRepositoryProvider = Provider<FamilyGamesRepository>((ref) {
  final scope = ref.watch(familyScopeProvider);
  final me = ref.watch(currentMemberProvider).valueOrNull;
  return FamilyGamesRepositoryImpl(
    scope: scope,
    gamification: ref.watch(gamificationRepositoryProvider),
    memberDisplayName: me?.displayName,
  );
});

final creativeSubmissionsTodayProvider = StreamProvider<List<CreativeSubmission>>((ref) {
  final key = creativeDayKey();
  return ref.watch(familyGamesRepositoryProvider).watchCreativeForPrompt(key);
});
