import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/domain/entities/family_member.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';
import '../../data/diary_repository_impl.dart';
import '../../domain/entities/story.dart';
import '../../domain/entities/story_comment.dart';
import '../../domain/repositories/diary_repository.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  final scope = ref.watch(familyScopeProvider);
  final me = ref.watch(currentMemberProvider).valueOrNull;
  final members =
      ref.watch(familyMembersProvider).valueOrNull ?? const <FamilyMember>[];
  return DiaryRepositoryImpl(
    scope: scope,
    gamification: ref.watch(gamificationRepositoryProvider),
    memberDisplayName: me?.displayName,
    familyMemberEmails: members.map((m) => m.email).toSet(),
  );
});

final storiesStreamProvider = StreamProvider<List<Story>>((ref) {
  return ref.watch(diaryRepositoryProvider).watchStories();
});

final storyDetailProvider = StreamProvider.family<Story?, String>((ref, id) {
  return ref.watch(diaryRepositoryProvider).watchStory(id);
});

final storyCommentsProvider = StreamProvider.family<List<StoryComment>, String>((ref, id) {
  return ref.watch(diaryRepositoryProvider).watchComments(id);
});
