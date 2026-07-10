import '../entities/chat_message.dart';
import '../entities/family_chat_meta.dart';

abstract class ChatRepository {
  static const String familyChatId = 'family';

  Stream<List<ChatMessage>> watchMessages({int limit = 120});

  Stream<FamilyChatMeta> watchChatMeta();

  Future<void> registerCurrentMember();

  Future<void> sendTextMessage(String text);

  /// Updates this user's read cursor to [through] (typically latest visible message time).
  Future<void> updateMyReadThrough(DateTime through);

  Future<void> reportMessage({
    required String messageId,
    required String messageAuthorUid,
    required String preview,
  });

  /// Sets or clears this user's reaction on [messageId] ([emoji] null = remove).
  Future<void> setReaction({
    required String messageId,
    String? emoji,
  });
}
