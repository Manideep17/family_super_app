import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_flags.dart';
import '../../../../core/rollups/free_weekly_rollup_service.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../domain/week_id.dart';
import '../badge_catalog.dart';
import '../providers/gamification_providers.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  @override
  Widget build(BuildContext context) {
    // Weekly champion is computed by the `weeklyChampionRollup` Cloud
    // Function (functions/src/weekly.ts), not the client.
    final async = ref.watch(leaderboardProvider);
    final championAsync = ref.watch(weeklyChampionProvider);
    final scheme = Theme.of(context).colorScheme;
    final thisWeek = familyWeekId(DateTime.now());
    final familyId = ref.watch(currentFamilyIdProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family leaderboard'),
        actions: [
          if (familyId != null && familyId.isNotEmpty)
            IconButton(
              tooltip: 'Run weekly rollup now',
              onPressed: () async {
                try {
                  await FreeWeeklyRollupService().runForFamily(familyId);
                  if (!context.mounted) return;
                  ref.invalidate(weeklyChampionProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Weekly rollup refreshed')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rollup failed: $e')),
                  );
                }
              },
              icon: const Icon(Icons.auto_fix_high_outlined),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 56, color: scheme.outline),
                    const SizedBox(height: 12),
                    Text(
                      'No scores yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Approve tasks, post diary entries, and play “Who said this?” to earn points.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: rows.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                if (!AppFlags.functionsEnabled) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'Free mode: weekly spotlight is disabled (requires Cloud Functions).',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  );
                }
                return championAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (ch) {
                    if (ch == null || (ch.name ?? '').isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final isThisWeek = ch.weekId == thisWeek;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(Icons.military_tech_rounded, color: scheme.onSecondaryContainer),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isThisWeek ? 'Weekly spotlight' : 'Recent weekly champion',
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                            color: scheme.onSecondaryContainer,
                                          ),
                                    ),
                                    Text(
                                      '${ch.name} · ${ch.points} pts',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            color: scheme.onSecondaryContainer,
                                          ),
                                    ),
                                    Text(
                                      ch.weekId,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: scheme.onSecondaryContainer.withValues(alpha: 0.85),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
              final s = rows[i - 1];
              final rank = i;
              final badges = BadgeCatalog.badgesFor(s);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            child: Text(
                              '$rank',
                              style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.displayName.isNotEmpty ? s.displayName : s.email,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                if (s.displayTitle.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Chip(
                                    label: Text(s.displayTitle),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    labelStyle: const TextStyle(fontSize: 12),
                                  ),
                                ],
                                Text(
                                  '${s.points} pts · ${s.famCoins} FAM coins · '
                                  '${s.storiesCreated} stories · ${s.gamesWon} game wins',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                                if (s.currentStreak > 0) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.local_fire_department_rounded,
                                        size: 14,
                                        color: scheme.tertiary,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${s.currentStreak}-day streak'
                                        '${s.longestStreak > s.currentStreak ? ' · best ${s.longestStreak}' : ''}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: scheme.tertiary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(Icons.stars_rounded, color: scheme.secondary),
                        ],
                      ),
                      if (badges.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: badges
                              .map(
                                (b) => Chip(
                                  avatar: Text(b.emoji, style: const TextStyle(fontSize: 14)),
                                  label: Text(b.label),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
