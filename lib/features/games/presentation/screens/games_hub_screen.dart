import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'creative_challenge_screen.dart';
import 'future_predictions_game_screen.dart';
import 'know_your_family_screen.dart';
import 'memory_match_game_screen.dart';
import 'puzzle_builder_screen.dart';
import 'reel_battle_screen.dart';
import 'time_travel_game_screen.dart';
import 'who_said_game_screen.dart';

class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final games = <_GameTile>[
      _GameTile(
        icon: Icons.psychology_outlined,
        title: 'Who said this?',
        subtitle: 'Guess the chat author',
        chip: '+10 pts',
        builder: (_) => const WhoSaidGameScreen(),
      ),
      _GameTile(
        icon: Icons.grid_view_rounded,
        title: 'Memory match',
        subtitle: 'Pairs from vault photos',
        chip: '+10 pts',
        builder: (_) => const MemoryMatchGameScreen(),
      ),
      _GameTile(
        icon: Icons.family_restroom_outlined,
        title: 'Know your family',
        subtitle: 'Roster trivia',
        chip: '+10 pts',
        builder: (_) => const KnowYourFamilyScreen(),
      ),
      _GameTile(
        icon: Icons.history_edu_rounded,
        title: 'Time travel challenge',
        subtitle: 'Old memory · describe the moment',
        chip: '+5 pts',
        builder: (_) => const TimeTravelGameScreen(),
      ),
      _GameTile(
        icon: Icons.brush_outlined,
        title: 'Creative challenge',
        subtitle: 'Daily prompt + family wall',
        chip: '+5 pts',
        builder: (_) => const CreativeChallengeScreen(),
      ),
      _GameTile(
        icon: Icons.extension_rounded,
        title: 'Family puzzle builder',
        subtitle: 'Slide a real family photo back together',
        chip: 'up to +200',
        builder: (_) => const PuzzleBuilderScreen(),
      ),
      _GameTile(
        icon: Icons.movie_filter_rounded,
        title: 'Mini reel battle',
        subtitle: '10–30s clips · family votes with reactions',
        chip: 'leaderboard',
        builder: (_) => const ReelBattleScreen(),
      ),
      _GameTile(
        icon: Icons.auto_graph_rounded,
        title: 'Future predictions',
        subtitle: 'Predict outcomes · resolve later',
        chip: '+10 pts',
        builder: (_) => const FuturePredictionsGameScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Family games')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AppGradient(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.sports_esports_rounded, size: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '8 family-built games',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Each game uses your real chats, photos, and '
                            'memories — no generic puzzles.',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap a card to play. Points go to your family leaderboard.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.85),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemCount: games.length,
            itemBuilder: (ctx, i) {
              final g = games[i];
              return Card(
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: g.builder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(g.icon, color: scheme.onPrimaryContainer),
                        ),
                        const Spacer(),
                        Text(
                          g.title,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          g.subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            g.chip,
                            style: TextStyle(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Card(
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'First time in games?',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Each mini-game uses your real family data (chat, vault photos, '
                    'memories). Points update your family leaderboard — try “Know your family” '
                    'or “Who said this?” to warm up.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Play fair — points are for fun. Serious abuse belongs in My family → Reports inbox.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameTile {
  _GameTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.chip,
    required this.builder,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String chip;
  final WidgetBuilder builder;
}
