import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/moderation/local_hide_store.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../../family/presentation/providers/local_hide_providers.dart';
import '../../domain/entities/story.dart';
import '../../domain/entities/story_comment.dart';
import '../diary_moods.dart';
import '../providers/diary_providers.dart';

const _storyReactions = ['👍', '❤️', '😂', '🙏', '👏', '✨'];

class StoryDetailScreen extends ConsumerStatefulWidget {
  const StoryDetailScreen({super.key, required this.storyId});

  final String storyId;

  @override
  ConsumerState<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends ConsumerState<StoryDetailScreen> {
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _pickReaction(Story story) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('React', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ..._storyReactions.map(
                      (e) => FilledButton.tonal(
                        onPressed: () => Navigator.pop(ctx, e),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, ''),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || emoji == null) return;
    final repo = ref.read(diaryRepositoryProvider);
    if (emoji.isEmpty) {
      await repo.setStoryReaction(storyId: story.id, emoji: null);
    } else {
      await repo.setStoryReaction(storyId: story.id, emoji: emoji);
    }
  }

  Map<String, int> _reactionGroups(Map<String, String> reactions) {
    final out = <String, int>{};
    for (final e in reactions.values) {
      out[e] = (out[e] ?? 0) + 1;
    }
    return out;
  }

  Future<void> _sendComment() async {
    final text = _comment.text;
    if (text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(diaryRepositoryProvider).addComment(widget.storyId, text);
      _comment.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reportStory(BuildContext context, WidgetRef ref, Story story) async {
    var hideOnDevice = false;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: const Text('Report memory?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The family owner can review reports. This helps keep the diary kind.',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: hideOnDevice,
                  onChanged: (v) => setSt(() => hideOnDevice = v ?? false),
                  title: const Text('Hide on my phone only'),
                  subtitle: const Text(
                    'Others still see this memory. Stays on your device.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Report'),
              ),
            ],
          );
        },
      ),
    );
    if (go != true || !context.mounted) return;
    final preview = '${story.title}\n${story.body}'.trim();
    final clipped =
        preview.length > 400 ? '${preview.substring(0, 400)}…' : preview;
    final familyId = ref.read(currentFamilyIdProvider).valueOrNull;
    try {
      await ref.read(diaryRepositoryProvider).reportStory(
            storyId: story.id,
            storyAuthorUid: story.authorUid,
            preview: clipped,
          );
      if (hideOnDevice && familyId != null && familyId.isNotEmpty) {
        await LocalHideStore.hideDiaryStory(familyId, story.id);
        ref.invalidate(hiddenDiaryStoryIdsProvider);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hideOnDevice
                  ? 'Report sent. Memory hidden in your diary tab.'
                  : 'Thanks — report sent.',
            ),
          ),
        );
        if (hideOnDevice) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storyAsync = ref.watch(storyDetailProvider(widget.storyId));
    final storyForAppBar = storyAsync.valueOrNull;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final commentsAsync = ref.watch(storyCommentsProvider(widget.storyId));
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat.yMMMEd().add_jm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory'),
        actions: [
          if (storyForAppBar != null &&
              myUid != null &&
              storyForAppBar.authorUid != myUid)
            IconButton(
              tooltip: 'Report',
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => _reportStory(context, ref, storyForAppBar),
            ),
        ],
      ),
      body: storyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (story) {
          if (story == null) {
            return const Center(child: Text('This memory was removed.'));
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  children: [
                    _StoryHeader(story: story, dateFmt: dateFmt),
                    const SizedBox(height: 12),
                    if (story.taggedEmails.isNotEmpty) ...[
                      Text('Tagged', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: story.taggedEmails
                            .map((e) => Chip(label: Text(e)))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SelectableText(
                      story.body,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
                    ),
                    if (story.imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Photos', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ...story.imageUrls.map(
                        (url) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 16 / 10,
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => ColoredBox(
                                  color: scheme.surfaceContainerHighest,
                                  child: Center(
                                    child: Icon(Icons.broken_image_outlined,
                                        color: scheme.outline),
                                  ),
                                ),
                                loadingBuilder: (ctx, child, prog) {
                                  if (prog == null) return child;
                                  return ColoredBox(
                                    color: scheme.surfaceContainerHighest,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (story.videoUrls.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Videos', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ...story.videoUrls.map(
                        (url) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.play_circle_outline, color: scheme.primary),
                          title: Text(
                            url,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: IconButton(
                            tooltip: 'Copy link',
                            icon: const Icon(Icons.copy_rounded),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: url));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Link copied')),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text('Reactions', style: Theme.of(context).textTheme.titleSmall),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _pickReaction(story),
                          icon: const Icon(Icons.add_reaction_outlined, size: 20),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    if (story.reactions.isEmpty)
                      Text(
                        'Be the first to react.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _reactionGroups(story.reactions).entries.map((e) {
                          return ActionChip(
                            label: Text('${e.key}  ${e.value}'),
                            onPressed: () => _pickReaction(story),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 24),
                    Text('Comments', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    commentsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('Comments: $e'),
                      data: (comments) {
                        if (comments.isEmpty) {
                          return Text(
                            'No comments yet.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          );
                        }
                        return Column(
                          children: comments
                              .map((c) => _CommentTile(comment: c, dateFmt: dateFmt))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Material(
                elevation: 8,
                color: scheme.surface,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _comment,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Write a comment…',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _sending ? null : _sendComment,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: EdgeInsets.zero,
                            shape: const CircleBorder(),
                          ),
                          child: _sending
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StoryHeader extends StatelessWidget {
  const _StoryHeader({required this.story, required this.dateFmt});

  final Story story;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final moodEmoji = DiaryMoods.emojiFor(story.mood);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer,
            scheme.tertiaryContainer.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(moodEmoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    story.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onPrimaryContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DiaryMoods.labelFor(story.mood),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.9),
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '${story.authorName} · ${dateFmt.format(story.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.dateFmt});

  final StoryComment comment;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  comment.authorName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  dateFmt.format(comment.createdAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              comment.text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
