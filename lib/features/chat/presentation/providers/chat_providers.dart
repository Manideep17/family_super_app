import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/presentation/providers/family_providers.dart';
import '../../data/chat_repository_impl.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/family_chat_meta.dart';
import '../../domain/repositories/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final scope = ref.watch(familyScopeProvider);
  final me = ref.watch(currentMemberProvider).valueOrNull;
  return ChatRepositoryImpl(
    scope: scope,
    memberDisplayName: me?.displayName,
  );
});

final chatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  return ref.watch(chatRepositoryProvider).watchMessages();
});

final chatMetaProvider = StreamProvider<FamilyChatMeta>((ref) {
  return ref.watch(chatRepositoryProvider).watchChatMeta();
});
