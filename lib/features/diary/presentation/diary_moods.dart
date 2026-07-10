/// Mood values stored in Firestore `stories.mood`.
abstract final class DiaryMoods {
  static const List<(String id, String label, String emoji)> options = [
    ('happy', 'Happy', '😊'),
    ('fun', 'Fun', '🎉'),
    ('grateful', 'Grateful', '🙏'),
    ('calm', 'Calm', '🌿'),
    ('excited', 'Excited', '✨'),
    ('love', 'Love', '❤️'),
    ('proud', 'Proud', '🌟'),
    ('sad', 'Sad', '🌧️'),
  ];

  static String labelFor(String moodId) {
    for (final o in options) {
      if (o.$1 == moodId) return '${o.$3} ${o.$2}';
    }
    return moodId;
  }

  static String emojiFor(String moodId) {
    for (final o in options) {
      if (o.$1 == moodId) return o.$3;
    }
    return '📖';
  }
}
