import 'package:equatable/equatable.dart';

class StoryComment extends Equatable {
  const StoryComment({
    required this.id,
    required this.storyId,
    required this.text,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
  });

  final String id;
  final String storyId;
  final String text;
  final String authorUid;
  final String authorName;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, storyId, text, authorUid, authorName, createdAt];
}
