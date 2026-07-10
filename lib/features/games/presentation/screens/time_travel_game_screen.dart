import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../diary/domain/entities/story.dart';
import '../../../diary/presentation/providers/diary_providers.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';
import '../providers/family_games_providers.dart';

/// Shows a past memory; family responds in their own words (+ small points).
class TimeTravelGameScreen extends ConsumerStatefulWidget {
  const TimeTravelGameScreen({super.key});

  @override
  ConsumerState<TimeTravelGameScreen> createState() => _TimeTravelGameScreenState();
}

class _TimeTravelGameScreenState extends ConsumerState<TimeTravelGameScreen> {
  final _random = Random();
  final _response = TextEditingController();
  Story? _story;
  bool _busy = false;

  void _pickStory(List<Story> stories) {
    if (stories.isEmpty) {
      setState(() => _story = null);
      return;
    }
    final pool = stories.where((s) => s.body.trim().length > 12 || s.imageUrls.isNotEmpty).toList();
    final use = pool.isNotEmpty ? pool : stories;
    setState(() => _story = use[_random.nextInt(use.length)]);
  }

  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = _story;
    if (s == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(familyGamesRepositoryProvider).submitTimeTravelResponse(
            storyId: s.id,
            storyTitle: s.title.isNotEmpty ? s.title : 'Memory',
            storyImageUrl: s.imageUrls.isNotEmpty ? s.imageUrls.first : null,
            response: _response.text,
          );
      ref.invalidate(leaderboardProvider);
      if (mounted) {
        _response.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shared with the family · +5 pts')),
        );
        final list = await ref.read(storiesStreamProvider.future);
        _pickStory(list);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(storiesStreamProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time travel'),
        actions: [
          IconButton(
            tooltip: 'Another memory',
            onPressed: () {
              async.whenData(_pickStory);
            },
            icon: const Icon(Icons.shuffle_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (stories) {
          if (stories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Add diary stories first — then you can time-travel back to them.'),
              ),
            );
          }
          if (_story == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _pickStory(stories);
            });
            return const Center(child: CircularProgressIndicator());
          }
          final s = _story!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Step into an old moment',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (s.imageUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(
                      s.imageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(Icons.broken_image_outlined, color: scheme.outline, size: 48),
                      ),
                    ),
                  ),
                ),
              if (s.imageUrls.isNotEmpty) const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: scheme.surfaceContainerHighest,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    s.body.trim().isEmpty ? s.title : s.body,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'From ${s.authorName} · ${_fmt(s.createdAt)}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Text(
                'Describe the moment, how it felt, or how you’d recreate it today.',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _response,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Your words for the family…',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Share with family'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) {
    final local = d.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
