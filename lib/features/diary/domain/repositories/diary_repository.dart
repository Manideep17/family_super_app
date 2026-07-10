import 'dart:io';

import '../entities/story.dart';
import '../entities/story_comment.dart';

abstract class DiaryRepository {
  Stream<List<Story>> watchStories({int limit});

  Stream<Story?> watchStory(String storyId);

  Stream<List<StoryComment>> watchComments(String storyId);

  Future<String> createStory({
    required String title,
    required String body,
    required String mood,
    required List<String> taggedEmails,
    List<String> imageUrls,
    List<String> videoUrls,
  });

  /// Uploads [file] to Cloud Storage under `stories/{uid}/{uuid}.jpg` and
  /// returns the public download URL. Used by the diary "new memory" picker.
  Future<String> uploadStoryImage(File file);

  Future<void> addComment(String storyId, String text);

  /// Sets or toggles off the current user's reaction on the story.
  Future<void> setStoryReaction({
    required String storyId,
    String? emoji,
  });

  /// Report diary content to the family owner (see Firestore `stories/.../reports`).
  Future<void> reportStory({
    required String storyId,
    required String storyAuthorUid,
    required String preview,
  });
}
