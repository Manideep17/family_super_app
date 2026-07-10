import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/presentation/providers/family_providers.dart';
import '../../data/polls_repository.dart';
import '../../domain/family_poll.dart';

final pollsRepositoryProvider = Provider<PollsRepository>((ref) {
  final scope = ref.watch(familyScopeProvider);
  return PollsRepository(scope: scope);
});

final familyPollsStreamProvider =
    StreamProvider.autoDispose<List<FamilyPoll>>((ref) {
  return ref.watch(pollsRepositoryProvider).watchPolls();
});

final pollResponsesProvider = StreamProvider.autoDispose
    .family<Map<String, String>, String>((ref, pollId) {
  return ref.watch(pollsRepositoryProvider).watchResponses(pollId);
});
