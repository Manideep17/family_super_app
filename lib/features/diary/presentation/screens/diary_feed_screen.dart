import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/presentation/providers/local_hide_providers.dart';
import '../providers/diary_providers.dart';
import '../widgets/story_card.dart';
import 'create_story_screen.dart';
import 'story_detail_screen.dart';

/// Card-based feed of family stories / diary entries.
class DiaryFeedScreen extends ConsumerWidget {
  const DiaryFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(storiesStreamProvider);
    final hidden =
        ref.watch(hiddenDiaryStoryIdsProvider).valueOrNull ?? <String>{};
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: ColoredBox(
        color: Color.lerp(scheme.surfaceContainerLowest, scheme.tertiaryContainer, 0.04)!,
        child: storiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load memories.\n$e',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (stories) {
            final visible =
                stories.where((s) => !hidden.contains(s.id)).toList();
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(storiesStreamProvider);
                await ref.read(storiesStreamProvider.future);
              },
              child: visible.isEmpty && stories.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(32),
                      children: [
                        const SizedBox(height: 48),
                        Icon(Icons.auto_stories_rounded,
                            size: 56, color: scheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          'No stories yet',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap “New memory” to capture a moment for the family.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    )
                  : visible.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(32),
                          children: [
                            const SizedBox(height: 48),
                            Icon(Icons.visibility_off_outlined,
                                size: 56, color: scheme.outline),
                            const SizedBox(height: 16),
                            Text(
                              'No memories visible here',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Stories you hid after reporting are skipped on '
                              'this phone. Open My family → Show hidden content '
                              'again to bring them back.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        )
                      : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 12, bottom: 100),
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final s = visible[i];
                        return StoryCard(
                          story: s,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => StoryDetailScreen(storyId: s.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              fullscreenDialog: true,
              builder: (_) => const CreateStoryScreen(),
            ),
          );
          if (created == true && context.mounted) {
            ref.invalidate(storiesStreamProvider);
          }
        },
        icon: const Icon(Icons.edit_rounded),
        label: const Text('New memory'),
      ),
    );
  }
}
