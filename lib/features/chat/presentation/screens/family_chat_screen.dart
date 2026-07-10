import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/moderation/local_hide_store.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../../family/presentation/providers/local_hide_providers.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_bubble.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/family_chat_meta.dart';

const _quickReactions = ['👍', '❤️', '😂', '🙏', '👏', '✨'];

/// Real-time family thread + reactions + read receipts (meta doc).
class FamilyChatScreen extends ConsumerStatefulWidget {
  const FamilyChatScreen({super.key});

  @override
  ConsumerState<FamilyChatScreen> createState() => _FamilyChatScreenState();
}

class _FamilyChatScreenState extends ConsumerState<FamilyChatScreen> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  Timer? _readDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatRepositoryProvider).registerCurrentMember();
    });
  }

  @override
  void dispose() {
    _readDebounce?.cancel();
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  void _scheduleReadThrough(List<ChatMessage> messages) {
    if (messages.isEmpty) return;
    final last = messages.last;
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 600), () {
      ref.read(chatRepositoryProvider).updateMyReadThrough(last.createdAt);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  bool _allOthersRead(ChatMessage m, String myUid, FamilyChatMeta meta) {
    if (m.authorUid != myUid) return false;
    final others = meta.members.keys.where((id) => id != myUid).toList();
    if (others.isEmpty) return false;
    for (final id in others) {
      final t = meta.readThrough[id];
      if (t == null || t.isBefore(m.createdAt)) return false;
    }
    return true;
  }

  Future<void> _pickReaction(String messageId) async {
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
                    ..._quickReactions.map(
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
    final repo = ref.read(chatRepositoryProvider);
    if (emoji.isEmpty) {
      await repo.setReaction(messageId: messageId, emoji: null);
    } else {
      await repo.setReaction(messageId: messageId, emoji: emoji);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider);
    final metaAsync = ref.watch(chatMetaProvider);
    final hiddenChatIds =
        ref.watch(hiddenChatMessageIdsProvider).valueOrNull ?? <String>{};
    final familyId = ref.watch(currentFamilyIdProvider).valueOrNull;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    ref.listen(chatMessagesProvider, (prev, next) {
      next.whenData((list) {
        final hidden =
            ref.read(hiddenChatMessageIdsProvider).valueOrNull ?? <String>{};
        final visible =
            list.where((m) => !hidden.contains(m.id)).toList();
        _scheduleReadThrough(visible);
        if (prev?.valueOrNull?.length != next.valueOrNull?.length) {
          _scrollToBottom();
        }
      });
    });
    ref.listen(hiddenChatMessageIdsProvider, (_, next) {
      ref.read(chatMessagesProvider).whenData((list) {
        final hidden = next.valueOrNull ?? <String>{};
        final visible =
            list.where((m) => !hidden.contains(m.id)).toList();
        _scheduleReadThrough(visible);
      });
    });

    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: Color.lerp(scheme.surfaceContainerLowest, scheme.primaryContainer, 0.06)!,
      child: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                final visible = messages
                    .where((m) => !hiddenChatIds.contains(m.id))
                    .toList();
                if (visible.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        messages.isEmpty
                            ? 'Say hi to the family 👋'
                            : 'Every message is hidden on this device.\n\n'
                                'Open My family and tap “Show hidden content again” '
                                'to restore the thread here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  );
                }
                final meta = metaAsync.valueOrNull ?? const FamilyChatMeta();
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final m = visible[i];
                    final mine = uid != null && m.authorUid == uid;
                    final seen = uid != null && _allOthersRead(m, uid, meta);
                    return ChatBubble(
                      message: m,
                      isMine: mine,
                      allOthersRead: seen,
                      onLongPress: () => _pickReaction(m.id),
                      onReactionTap: () => _pickReaction(m.id),
                      onReport: mine
                          ? null
                          : () async {
                              var hideOnDevice = false;
                              final go = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => StatefulBuilder(
                                  builder: (ctx, setSt) {
                                    return AlertDialog(
                                      title: const Text('Report message?'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'The family owner can review reports. '
                                            'This helps keep chat kind.',
                                          ),
                                          CheckboxListTile(
                                            contentPadding: EdgeInsets.zero,
                                            value: hideOnDevice,
                                            onChanged: (v) => setSt(
                                              () => hideOnDevice = v ?? false,
                                            ),
                                            title: const Text(
                                              'Hide on my phone only',
                                            ),
                                            subtitle: const Text(
                                              'Others still see it. '
                                              'This stays on your device.',
                                            ),
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Report'),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                              if (go != true || !context.mounted) return;
                              try {
                                await ref
                                    .read(chatRepositoryProvider)
                                    .reportMessage(
                                      messageId: m.id,
                                      messageAuthorUid: m.authorUid,
                                      preview: m.text.length > 400
                                          ? '${m.text.substring(0, 400)}…'
                                          : m.text,
                                    );
                                if (hideOnDevice &&
                                    familyId != null &&
                                    familyId.isNotEmpty) {
                                  await LocalHideStore.hideChatMessage(
                                    familyId,
                                    m.id,
                                  );
                                  ref.invalidate(hiddenChatMessageIdsProvider);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        hideOnDevice
                                            ? 'Report sent. Message hidden here.'
                                            : 'Thanks — report sent.',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$e')),
                                  );
                                }
                              }
                            },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load chat.\n$e',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          _Composer(
            controller: _input,
            onSend: () async {
              final text = _input.text;
              _input.clear();
              await ref.read(chatRepositoryProvider).sendTextMessage(text);
            },
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Voice notes (soon)',
                onPressed: null,
                icon: Icon(Icons.mic_none_rounded, color: scheme.outline),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: onSend,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: const Icon(Icons.send_rounded, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
