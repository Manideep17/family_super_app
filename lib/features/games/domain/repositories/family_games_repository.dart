import '../entities/creative_submission.dart';

abstract class FamilyGamesRepository {
  Future<void> submitTimeTravelResponse({
    required String storyId,
    required String storyTitle,
    String? storyImageUrl,
    required String response,
  });

  Future<void> submitCreativeChallenge({
    required String promptKey,
    required String body,
  });

  Stream<List<CreativeSubmission>> watchCreativeForPrompt(String promptKey, {int limit});
}
