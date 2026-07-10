/// Preset display titles members can pick (stored on `member_stats.displayTitle`).
abstract final class TitleCatalog {
  /// Weekly champion can claim this title for free (see gamification).
  static const String weeklyChampionTitle = 'Weekly legend';

  static const List<String> choices = [
    '',
    'MVP',
    'Snack captain',
    'Chore hero',
    'Story keeper',
    'Game night boss',
    'Chief hug officer',
    'Calendar wizard',
    'Meme minister',
    weeklyChampionTitle,
    'Kitchen MVP',
    'Road trip DJ',
  ];

  /// Extra coin cost when selecting a title (0 = free).
  static int coinCostFor(String stored) {
    switch (stored.trim()) {
      case 'Kitchen MVP':
      case 'Road trip DJ':
        return 15;
      default:
        return 0;
    }
  }

  static bool isAllowed(String? title) {
    final t = title?.trim() ?? '';
    return choices.contains(t);
  }

  static String labelFor(String stored) {
    final t = stored.trim();
    if (t.isEmpty) return 'No title';
    final cost = coinCostFor(t);
    if (cost > 0) return '$t ($cost coins)';
    return t;
  }
}
