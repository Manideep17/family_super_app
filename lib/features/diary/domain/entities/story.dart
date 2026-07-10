import 'package:equatable/equatable.dart';

/// Family diary / story entry stored in `stories/{id}`.
class Story extends Equatable {
  const Story({
    required this.id,
    required this.title,
    required this.body,
    required this.mood,
    required this.authorUid,
    required this.authorName,
    required this.taggedEmails,
    required this.imageUrls,
    required this.videoUrls,
    required this.createdAt,
    this.reactions = const {},
    this.commentCount = 0,
  });

  final String id;
  final String title;
  final String body;
  final String mood;
  final String authorUid;
  final String authorName;
  final List<String> taggedEmails;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final DateTime createdAt;
  final Map<String, String> reactions;
  final int commentCount;

  @override
  List<Object?> get props => [
        id,
        title,
        body,
        mood,
        authorUid,
        authorName,
        taggedEmails,
        imageUrls,
        videoUrls,
        createdAt,
        reactions,
        commentCount,
      ];
}
