import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/chat_message.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.allOthersRead,
    required this.onLongPress,
    required this.onReactionTap,
    this.onReport,
  });

  final ChatMessage message;
  final bool isMine;
  final bool allOthersRead;
  final VoidCallback onLongPress;
  final VoidCallback onReactionTap;
  final VoidCallback? onReport;

  static final _timeFmt = DateFormat.jm();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final bg = isMine
        ? Color.lerp(scheme.primaryContainer, scheme.primary, 0.12)!
        : scheme.surfaceContainerHighest;
    final fg = isMine ? scheme.onPrimaryContainer : scheme.onSurface;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: bg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 18),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.authorName,
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (message.type == ChatMessageType.voice)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic_rounded, size: 20, color: fg),
                        const SizedBox(width: 6),
                        Text(
                          message.audioUrl != null && message.audioUrl!.isNotEmpty
                              ? 'Voice note'
                              : 'Voice (soon)',
                          style: textTheme.bodyMedium?.copyWith(color: fg),
                        ),
                      ],
                    )
                  else
                    SelectableText(
                      message.text,
                      style: textTheme.bodyLarge?.copyWith(color: fg, height: 1.35),
                    ),
                  if (message.reactions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: _reactionGroups(message.reactions).entries.map((e) {
                        return InkWell(
                          onTap: onReactionTap,
                          borderRadius: BorderRadius.circular(12),
                          child: Material(
                            color: scheme.surface.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                '${e.key} ${e.value}',
                                style: textTheme.labelMedium,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        _timeFmt.format(message.createdAt),
                        style: textTheme.labelSmall?.copyWith(
                          color: fg.withValues(alpha: 0.65),
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          allOthersRead ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 16,
                          color: allOthersRead
                              ? scheme.primary
                              : fg.withValues(alpha: 0.55),
                        ),
                      ],
                      if (!isMine && onReport != null) ...[
                        const Spacer(),
                        IconButton(
                          tooltip: 'Report',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 28,
                          ),
                          icon: Icon(
                            Icons.flag_outlined,
                            size: 18,
                            color: fg.withValues(alpha: 0.55),
                          ),
                          onPressed: onReport,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// emoji → count (uids aggregated).
  static Map<String, int> _reactionGroups(Map<String, String> reactions) {
    final out = <String, int>{};
    for (final emoji in reactions.values) {
      out[emoji] = (out[emoji] ?? 0) + 1;
    }
    return out;
  }
}
