import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_flags.dart';
import '../../../../core/rollups/free_weekly_rollup_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../../diary/presentation/screens/story_detail_screen.dart';
import '../../../gamification/domain/week_id.dart';

/// Streams the doc written by the `bestMomentsRollup` Cloud Function on
/// Sundays. If the function hasn't run for this week yet, falls back to
/// the previous week's doc so the screen is never blank.
final bestMomentsProvider =
    StreamProvider.autoDispose<Map<String, dynamic>?>((ref) async* {
  final db = FirebaseFirestore.instance;
  final fid = ref.watch(currentFamilyIdProvider).valueOrNull;
  if (fid == null || fid.isEmpty) {
    yield null;
    return;
  }
  final thisWeek = familyWeekId(DateTime.now());
  final prevWeek = familyWeekId(
    DateTime.now().subtract(const Duration(days: 7)),
  );

  await for (final snap in db
      .collection('families')
      .doc(fid)
      .collection('best_moments')
      .doc(thisWeek)
      .snapshots()) {
    if (snap.exists && snap.data() != null) {
      yield snap.data();
    } else {
      final fb = await db
          .collection('families')
          .doc(fid)
          .collection('best_moments')
          .doc(prevWeek)
          .get();
      yield fb.data();
    }
  }
});

class BestMomentsScreen extends ConsumerWidget {
  const BestMomentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bestMomentsProvider);
    final scheme = Theme.of(context).colorScheme;
    final familyId = ref.watch(currentFamilyIdProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Best moments'),
        actions: [
          if (familyId != null && familyId.isNotEmpty)
            IconButton(
              tooltip: 'Generate now',
              onPressed: () async {
                try {
                  await FreeWeeklyRollupService().runForFamily(familyId);
                  if (!context.mounted) return;
                  ref.invalidate(bestMomentsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Best moments refreshed')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Refresh failed: $e')),
                  );
                }
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data == null) return _Empty(scheme: scheme);
          final stories = (data['stories'] as List<dynamic>? ?? []);
          final weekId = data['weekId']?.toString() ?? '';
          final generatedAt = data['generatedAt'];
          DateTime? gen;
          if (generatedAt is Timestamp) gen = generatedAt.toDate();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AppGradient(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 36),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Top moments · $weekId',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              if (gen != null)
                                Text(
                                  'Curated ${DateFormat.yMMMd().format(gen.toLocal())}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (!AppFlags.functionsEnabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    'Free mode: weekly automatic highlight rollups are unavailable.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              if (stories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No memories made it onto the highlight reel '
                      'this week — yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                ...List.generate(stories.length, (i) {
                  final raw = stories[i] as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _MomentCard(rank: i + 1, data: raw),
                  );
                }),
              Text(
                AppFlags.functionsEnabled
                    ? 'Highlights are computed every Sunday at 11pm by a Cloud Function — reactions × 2 + comments.'
                    : 'In free mode, this page fills when weekly highlight docs are created manually or when Cloud Functions are enabled.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.rank, required this.data});

  final int rank;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final id = data['id']?.toString() ?? '';
    final title = (data['title'] ?? '').toString();
    final body = (data['body'] ?? '').toString();
    final author = (data['authorName'] ?? '').toString();
    final reactions = (data['reactions'] as num?)?.toInt() ?? 0;
    final comments = (data['commentCount'] as num?)?.toInt() ?? 0;
    final image = data['firstImageUrl']?.toString();

    return Card(
      child: InkWell(
        onTap: id.isEmpty
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StoryDetailScreen(storyId: id),
                  ),
                ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (image != null && image.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: scheme.surfaceContainerHigh,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: scheme.outline,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title.isEmpty ? 'Memory' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (body.isNotEmpty)
                    Text(
                      body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        author,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const Spacer(),
                      Icon(Icons.favorite_border,
                          size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '$reactions',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.mode_comment_outlined,
                          size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '$comments',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text('Highlights will arrive soon',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              AppFlags.functionsEnabled
                  ? 'A Cloud Function curates the family\'s top memories every Sunday night. Add reactions and comments to influence what shows up here.'
                  : 'This feature uses weekly Cloud Function rollups, which are disabled in free mode.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
