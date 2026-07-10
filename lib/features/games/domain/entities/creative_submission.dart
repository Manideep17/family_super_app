import 'package:equatable/equatable.dart';

/// `creative_submissions/{id}`
class CreativeSubmission extends Equatable {
  const CreativeSubmission({
    required this.id,
    required this.promptKey,
    required this.body,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
  });

  final String id;
  final String promptKey;
  final String body;
  final String authorUid;
  final String authorName;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, promptKey, body, authorUid, authorName, createdAt];
}
