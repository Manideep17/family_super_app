import 'package:equatable/equatable.dart';

enum ChatMessageType { text, voice }

/// Single row in `chats/{chatId}/messages/{messageId}`.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
    this.type = ChatMessageType.text,
    this.audioUrl,
    this.reactions = const {},
  });

  final String id;
  final String text;
  final String authorUid;
  final String authorName;
  final DateTime createdAt;
  final ChatMessageType type;
  final String? audioUrl;

  /// uid → single emoji character.
  final Map<String, String> reactions;

  @override
  List<Object?> get props => [
        id,
        text,
        authorUid,
        authorName,
        createdAt,
        type,
        audioUrl,
        reactions,
      ];
}
