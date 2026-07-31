import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/analytics/app_analytics.dart';
import '../../../../core/config/app_flags.dart';
import '../../../../core/media/media_upload_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../family/presentation/providers/family_providers.dart';

/// Mini reel battle (Phase 3).
///
/// Each family member uploads a 10–30s video around an optional theme.
/// Family votes by reacting with one of three emoji; total reaction count
/// drives the leaderboard.
///
/// Firestore: `reels/{id}` with shape:
/// {
///   title, theme,
///   authorUid, authorName, authorEmail,
///   downloadUrl, storagePath,
///   reactions: { uid: '🔥' | '😂' | '❤️' },
///   createdAt
/// }
class ReelBattleScreen extends ConsumerStatefulWidget {
  const ReelBattleScreen({super.key});

  @override
  ConsumerState<ReelBattleScreen> createState() => _ReelBattleScreenState();
}

class _ReelBattleScreenState extends ConsumerState<ReelBattleScreen> {
  final _picker = ImagePicker();
  bool _uploading = false;

  CollectionReference<Map<String, dynamic>> get _col =>
      ref.read(familyScopeProvider).reels;

  Stream<List<Map<String, dynamic>>> _watch() => _col
      .orderBy('createdAt', descending: true)
      .limit(40)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Future<void> _record() async {
    if (!AppFlags.mediaUploadsEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reel uploads are disabled in no-cost mode.'),
          ),
        );
      }
      return;
    }
    if (_uploading) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final theme = await showDialog<String>(
      context: context,
      builder: (_) => const _ThemeDialog(),
    );
    if (theme == null) return;

    XFile? clip;
    try {
      clip = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );
      // If camera fails or is unavailable, fall back to gallery.
      clip ??= await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
    } catch (_) {
      clip = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );
    }
    if (clip == null) return;

    setState(() => _uploading = true);
    try {
      final id = const Uuid().v4();
      final uploaded = await FirebaseStorageMediaUploadService().uploadFile(
        familyId: ref.read(familyScopeProvider).familyId,
        file: File(clip.path),
        folder: 'reels',
        ownerUid: user.uid,
        fileName: id,
        contentType: 'video/mp4',
      );
      final email = user.email?.toLowerCase() ?? '';
      final member = ref.read(currentMemberProvider).valueOrNull;
      await _col.doc(id).set({
        'title': theme,
        'theme': theme,
        'authorUid': user.uid,
        'authorName': member?.displayName ?? (user.displayName ?? 'Family'),
        'authorEmail': email,
        'downloadUrl': uploaded.url,
        'storagePath': uploaded.storagePath,
        'reactions': <String, String>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
      AppAnalytics.logEvent('reel_created');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _react(String id, String emoji) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = _col.doc(id);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final raw = snap.data()?['reactions'];
      final reactions = <String, String>{};
      if (raw is Map) {
        raw.forEach((k, v) => reactions[k.toString()] = v.toString());
      }
      if (reactions[uid] == emoji) {
        reactions.remove(uid);
      } else {
        reactions[uid] = emoji;
      }
      tx.update(ref, {'reactions': reactions});
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Mini reel battle')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: AppFlags.mediaUploadsEnabled ? _record : null,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.videocam_outlined),
        label: Text(
          AppFlags.mediaUploadsEnabled
              ? (_uploading ? 'Uploading…' : 'Record')
              : 'Storage off',
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _watch(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final list = snap.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AppGradient(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.movie_filter_rounded, size: 36),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Make a 10-30s reel',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                AppFlags.mediaUploadsEnabled
                                    ? 'Pick a theme, record or pick a video, and let the family react.'
                                    : 'Video reels are off in no-cost mode.',
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
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No reels yet — tap Record to start.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                ...list.map(
                  (r) => _ReelCard(
                    data: r,
                    myUid: myUid,
                    onReact: (e) => _react(r['id'] as String, e),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeDialog extends StatefulWidget {
  const _ThemeDialog();

  @override
  State<_ThemeDialog> createState() => _ThemeDialogState();
}

class _ThemeDialogState extends State<_ThemeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      'Family dance',
      'Best breakfast',
      'Throwback moment',
      'Today in 30 sec',
      'Pet moment',
    ];
    return AlertDialog(
      title: const Text('Pick a theme'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Or write your own',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => Navigator.pop<String>(context, v.trim()),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggestions
                .map((s) => ActionChip(
                      label: Text(s),
                      onPressed: () => Navigator.pop<String>(context, s),
                    ))
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop<String?>(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final v = _controller.text.trim();
            if (v.isEmpty) {
              Navigator.pop<String?>(context, null);
            } else {
              Navigator.pop<String>(context, v);
            }
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _ReelCard extends StatefulWidget {
  const _ReelCard({
    required this.data,
    required this.myUid,
    required this.onReact,
  });

  final Map<String, dynamic> data;
  final String myUid;
  final ValueChanged<String> onReact;

  @override
  State<_ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<_ReelCard> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final url = widget.data['downloadUrl']?.toString();
    if (url == null || url.isEmpty || _controller != null) return;
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = c;
    c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _initialized = true);
      c.setLooping(true);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = widget.data['theme']?.toString() ?? 'Reel';
    final author = widget.data['authorName']?.toString() ?? '';
    final reactions = (widget.data['reactions'] as Map<dynamic, dynamic>? ?? {})
        .map((k, v) => MapEntry(k.toString(), v.toString()));
    final myReact = reactions[widget.myUid];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: _initialized && _controller != null
                  ? GestureDetector(
                      onTap: () {
                        final c = _controller!;
                        c.value.isPlaying ? c.pause() : c.play();
                        setState(() {});
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          VideoPlayer(_controller!),
                          if (!_controller!.value.isPlaying)
                            Container(
                              color: Colors.black26,
                              child: const Center(
                                child: Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white,
                                  size: 64,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : Container(
                      color: scheme.surfaceContainerHigh,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          theme,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by $author',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final emoji in const ['🔥', '😂', '❤️'])
                        _ReactionPill(
                          emoji: emoji,
                          count: reactions.values
                              .where((v) => v == emoji)
                              .length,
                          selected: myReact == emoji,
                          onTap: () => widget.onReact(emoji),
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

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    required this.emoji,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHigh,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text('$count'),
          ],
        ),
      ),
    );
  }
}
