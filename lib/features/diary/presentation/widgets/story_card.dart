import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/story.dart';
import '../diary_moods.dart';

class StoryCard extends StatelessWidget {
  const StoryCard({super.key, required this.story, required this.onTap});

  final Story story;
  final VoidCallback onTap;

  static final _dateFmt = DateFormat.MMMd().add_jm();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final moodEmoji = DiaryMoods.emojiFor(story.mood);
    final excerpt = story.body.length > 140 ? '${story.body.substring(0, 140)}…' : story.body;

    final reactionTotal = story.reactions.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primaryContainer,
                      scheme.secondaryContainer.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    children: [
                      Text(moodEmoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              story.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${story.authorName} · ${_dateFmt.format(story.createdAt)}',
                              style: textTheme.labelMedium?.copyWith(
                                color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  excerpt,
                  style: textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
              if (story.taggedEmails.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: story.taggedEmails
                        .map(
                          (e) => Chip(
                            label: Text(e, style: textTheme.labelSmall),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (story.imageUrls.isNotEmpty || story.videoUrls.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      if (story.imageUrls.isNotEmpty)
                        Icon(Icons.photo_rounded, size: 18, color: scheme.primary),
                      if (story.imageUrls.isNotEmpty && story.videoUrls.isNotEmpty)
                        const SizedBox(width: 8),
                      if (story.videoUrls.isNotEmpty)
                        Icon(Icons.videocam_rounded, size: 18, color: scheme.tertiary),
                      const SizedBox(width: 6),
                      Text(
                        [
                          if (story.imageUrls.isNotEmpty) '${story.imageUrls.length} photo(s)',
                          if (story.videoUrls.isNotEmpty) '${story.videoUrls.length} video(s)',
                        ].join(' · '),
                        style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.favorite_border, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '$reactionTotal',
                      style: textTheme.labelMedium,
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.chat_bubble_outline, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${story.commentCount}',
                      style: textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
