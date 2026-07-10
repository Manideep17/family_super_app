import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/moderation/local_hide_store.dart';
import 'family_providers.dart';

final hiddenChatMessageIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final fid = ref.watch(currentFamilyIdProvider).valueOrNull;
  if (fid == null || fid.isEmpty) return {};
  return LocalHideStore.hiddenChatMessageIds(fid);
});

final hiddenDiaryStoryIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final fid = ref.watch(currentFamilyIdProvider).valueOrNull;
  if (fid == null || fid.isEmpty) return {};
  return LocalHideStore.hiddenDiaryStoryIds(fid);
});
