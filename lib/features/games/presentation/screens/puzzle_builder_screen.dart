import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';
import '../../../vault/domain/entities/vault_item.dart';
import '../../../vault/presentation/providers/vault_providers.dart';

/// Sliding-tile puzzle built from a real family photo in the vault. The
/// chosen image is split into N×N tiles, the bottom-right is removed, the
/// rest are shuffled with a guaranteed-solvable parity, and the player taps
/// adjacent tiles to slide them. Solving rewards points + a moves/time
/// readout.
class PuzzleBuilderScreen extends ConsumerStatefulWidget {
  const PuzzleBuilderScreen({super.key});

  @override
  ConsumerState<PuzzleBuilderScreen> createState() =>
      _PuzzleBuilderScreenState();
}

class _PuzzleBuilderScreenState extends ConsumerState<PuzzleBuilderScreen> {
  static const _grid = 3; // 3×3 — friendly difficulty.
  VaultItem? _picked;
  late List<int> _tiles;
  int _moves = 0;
  Stopwatch _watch = Stopwatch();
  Timer? _ticker;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _tiles = List.generate(_grid * _grid, (i) => i);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start(VaultItem item) {
    setState(() {
      _picked = item;
      _tiles = _shuffled();
      _moves = 0;
      _won = false;
      _watch = Stopwatch()..start();
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Shuffles tiles with even parity (guaranteed solvable on 3×3).
  List<int> _shuffled() {
    final rnd = Random();
    const n = _grid * _grid;
    while (true) {
      final order = List<int>.generate(n - 1, (i) => i)..shuffle(rnd);
      order.add(n - 1); // empty stays bottom-right initially
      var inv = 0;
      for (var i = 0; i < n - 1; i++) {
        for (var j = i + 1; j < n - 1; j++) {
          if (order[i] > order[j]) inv++;
        }
      }
      if (inv.isEven && !_isSolved(order)) return order;
    }
  }

  bool _isSolved(List<int> tiles) {
    for (var i = 0; i < tiles.length; i++) {
      if (tiles[i] != i) return false;
    }
    return true;
  }

  void _tap(int index) {
    if (_won) return;
    final empty = _tiles.indexOf(_grid * _grid - 1);
    final r1 = index ~/ _grid, c1 = index % _grid;
    final r2 = empty ~/ _grid, c2 = empty % _grid;
    final adj = (r1 == r2 && (c1 - c2).abs() == 1) ||
        (c1 == c2 && (r1 - r2).abs() == 1);
    if (!adj) return;
    setState(() {
      final tmp = _tiles[index];
      _tiles[index] = _tiles[empty];
      _tiles[empty] = tmp;
      _moves += 1;
      _won = _isSolved(_tiles);
    });
    if (_won) {
      _watch.stop();
      _ticker?.cancel();
      _onWin();
    }
  }

  Future<void> _onWin() async {
    final pts = (200 - _moves).clamp(20, 200);
    try {
      await ref
          .read(gamificationRepositoryProvider)
          .recordGameRoundWon(points: pts);
    } catch (_) {}
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Solved!'),
        content: Text(
          '$_moves moves · ${_watch.elapsed.inSeconds}s\n+$pts family points',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nice'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (_picked != null) _start(_picked!);
            },
            child: const Text('Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final asyncItems = ref.watch(vaultItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Family puzzle builder')),
      body: _picked == null
          ? asyncItems.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load vault: $e')),
              data: (items) {
                final photos = items
                    .where((i) => i.contentType.startsWith('image/'))
                    .toList();
                if (photos.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Upload at least one photo to the family vault to '
                        'turn it into a puzzle.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  );
                }
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
                              const Icon(Icons.extension_rounded, size: 36),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pick a memory to slide',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Solve it in fewer moves to score '
                                      'more points.',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: photos.length,
                      itemBuilder: (ctx, i) {
                        final p = photos[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _start(p),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(p.downloadUrl, fit: BoxFit.cover),
                                Positioned(
                                  left: 8,
                                  bottom: 8,
                                  right: 8,
                                  child: Text(
                                    p.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 4,
                                          color: Colors.black,
                                        ),
                                      ],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag_outlined, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        '$_moves moves · ${_watch.elapsed.inSeconds}s',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Shuffle'),
                        onPressed: () => _start(_picked!),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.collections_outlined),
                        label: const Text('Change'),
                        onPressed: () => setState(() {
                          _picked = null;
                          _watch.stop();
                          _ticker?.cancel();
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _Board(
                            url: _picked!.downloadUrl,
                            grid: _grid,
                            tiles: _tiles,
                            onTap: _tap,
                            won: _won,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.url,
    required this.grid,
    required this.tiles,
    required this.onTap,
    required this.won,
  });

  final String url;
  final int grid;
  final List<int> tiles;
  final ValueChanged<int> onTap;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final emptyValue = grid * grid - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        final tileSize = size / grid;
        return Container(
          color: scheme.surfaceContainerHighest,
          child: Stack(
            children: [
              for (var i = 0; i < tiles.length; i++)
                if (won || tiles[i] != emptyValue)
                  _Tile(
                    url: url,
                    grid: grid,
                    tileSize: tileSize,
                    position: i,
                    value: tiles[i],
                    onTap: () => onTap(i),
                  ),
              if (won)
                IgnorePointer(
                  child: Container(
                    color: Colors.black26,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: Colors.white,
                      size: 80,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.url,
    required this.grid,
    required this.tileSize,
    required this.position,
    required this.value,
    required this.onTap,
  });

  final String url;
  final int grid;
  final double tileSize;
  final int position;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pr = position ~/ grid;
    final pc = position % grid;
    final vr = value ~/ grid;
    final vc = value % grid;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      left: pc * tileSize,
      top: pr * tileSize,
      width: tileSize,
      height: tileSize,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRect(
          child: SizedBox(
            width: tileSize,
            height: tileSize,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxWidth: tileSize * grid,
              maxHeight: tileSize * grid,
              child: Transform.translate(
                offset: Offset(-vc * tileSize, -vr * tileSize),
                child: Image.network(
                  url,
                  width: tileSize * grid,
                  height: tileSize * grid,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
