import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gamification/presentation/providers/gamification_providers.dart';
import '../../../vault/domain/entities/vault_item.dart';
import '../../../vault/presentation/providers/vault_providers.dart';

class _Tile {
  _Tile({required this.pairId});

  final int pairId;
  bool faceUp = false;
  bool matched = false;
}

class MemoryMatchGameScreen extends ConsumerStatefulWidget {
  const MemoryMatchGameScreen({super.key});

  @override
  ConsumerState<MemoryMatchGameScreen> createState() => _MemoryMatchGameScreenState();
}

class _MemoryMatchGameScreenState extends ConsumerState<MemoryMatchGameScreen> {
  final _random = Random();
  List<VaultItem>? _images;
  List<_Tile>? _tiles;
  int? _firstIndex;
  bool _busy = false;
  bool _wonNotified = false;

  void _buildBoard(List<VaultItem> images) {
    if (images.length < 4) {
      _images = null;
      _tiles = null;
      return;
    }
    images.shuffle(_random);
    final pick = images.take(4).toList();
    final pairs = <int>[];
    for (var i = 0; i < 4; i++) {
      pairs.addAll([i, i]);
    }
    pairs.shuffle(_random);
    _images = pick;
    _tiles = pairs.map((id) => _Tile(pairId: id)).toList();
    _firstIndex = null;
    _busy = false;
    _wonNotified = false;
  }

  Future<void> _onTap(int index) async {
    final tiles = _tiles;
    final t = tiles?[index];
    if (t == null || t.matched || t.faceUp || _busy) return;
    setState(() => t.faceUp = true);

    if (_firstIndex == null) {
      _firstIndex = index;
      return;
    }

    final first = tiles![_firstIndex!];
    final second = tiles[index];
    if (first.pairId == second.pairId) {
      setState(() {
        first.matched = true;
        second.matched = true;
        _firstIndex = null;
      });
      if (tiles.every((x) => x.matched) && !_wonNotified) {
        _wonNotified = true;
        try {
          await ref.read(gamificationRepositoryProvider).recordGameRoundWon(points: 10);
          ref.invalidate(leaderboardProvider);
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Board cleared! +10 points')),
          );
        }
      }
      return;
    }

    _busy = true;
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      first.faceUp = false;
      second.faceUp = false;
      _firstIndex = null;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vaultItemsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory match'),
        actions: [
          IconButton(
            tooltip: 'New board',
            onPressed: () {
              async.whenData((items) {
                final imgs = items.where((e) => e.isImage).toList();
                setState(() => _buildBoard(List.of(imgs)));
              });
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          final imgs = items.where((e) => e.isImage).toList();
          if (imgs.length < 4) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Add at least four photos to the vault to play memory match.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            );
          }
          if (_tiles == null || _images == null || _images!.length < 4) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _buildBoard(List.of(imgs)));
            });
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  'Find all four pairs. Tap two cards.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _tiles!.length,
                  itemBuilder: (context, i) {
                    final tile = _tiles![i];
                    final url = _images![tile.pairId].downloadUrl;
                    return Material(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _onTap(i),
                        child: tile.faceUp || tile.matched
                            ? Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(Icons.broken_image_outlined, color: scheme.outline),
                                ),
                              )
                            : Center(
                                child: Icon(Icons.help_outline, size: 36, color: scheme.primary),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
