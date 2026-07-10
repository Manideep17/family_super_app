import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/domain/entities/family_member.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';

class _Quote {
  const _Quote({
    required this.id,
    required this.text,
    required this.authorName,
    required this.authorUid,
  });

  final String id;
  final String text;
  final String authorName;
  final String authorUid;
}

/// Picks an anonymous family chat line; guess who wrote it (+points on success).
class WhoSaidGameScreen extends ConsumerStatefulWidget {
  const WhoSaidGameScreen({super.key});

  @override
  ConsumerState<WhoSaidGameScreen> createState() => _WhoSaidGameScreenState();
}

class _WhoSaidGameScreenState extends ConsumerState<WhoSaidGameScreen> {
  final _random = Random();
  bool _loading = false;
  String? _error;
  _Quote? _quote;
  List<String> _choices = [];
  String? _correctName;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadRound(List<String> names) async {
    setState(() {
      _loading = true;
      _error = null;
      _answered = false;
    });
    try {
      final fid = ref.read(currentFamilyIdProvider).valueOrNull;
      if (fid == null || fid.isEmpty) {
        throw StateError('No family selected.');
      }
      final snap = await FirebaseFirestore.instance
          .collection('families')
          .doc(fid)
          .collection('chats')
          .doc('main')
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(160)
          .get();

      final candidates = <_Quote>[];
      for (final d in snap.docs) {
        final data = d.data();
        final text = (data['text'] as String? ?? '').trim();
        if (text.length < 12) continue;
        final name = (data['authorName'] as String? ?? '').trim();
        final uid = (data['authorUid'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        candidates.add(_Quote(id: d.id, text: text, authorName: name, authorUid: uid));
      }
      if (candidates.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Need a bit more family chat first — send a few messages and try again.';
        });
        return;
      }

      final q = candidates[_random.nextInt(candidates.length)];
      final pool = names.toSet().toList()..shuffle(_random);
      final choices = <String>{q.authorName};
      for (final n in pool) {
        if (choices.length >= 4) break;
        if (n != q.authorName) choices.add(n);
      }
      while (choices.length < 4 && names.isNotEmpty) {
        choices.add(names[_random.nextInt(names.length)]);
      }
      final list = choices.toList()..shuffle(_random);

      setState(() {
        _quote = q;
        _correctName = q.authorName;
        _choices = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _guess(String name) async {
    if (_answered) return;
    setState(() => _answered = true);
    final correct = name == _correctName;
    if (correct) {
      try {
        await ref.read(gamificationRepositoryProvider).recordGameRoundWon(points: 10);
        ref.invalidate(leaderboardProvider);
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(correct ? 'Yes! +10 points' : 'Nice try — it was $_correctName'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(familyMembersProvider);
    final members = membersAsync.valueOrNull ?? const <FamilyMember>[];
    final names = members
        .map((m) => m.displayName.trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    if (_quote == null && !_loading && names.length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadRound(names);
      });
    }
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Who said this?'),
        actions: [
          IconButton(
            tooltip: 'New quote',
            onPressed: _loading ? null : () => _loadRound(names),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : membersAsync.isLoading
              ? const Center(child: CircularProgressIndicator())
              : membersAsync.hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load family members: ${membersAsync.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : names.length < 2
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Need at least 2 family members to play this game.',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _quote == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Loading a quote...',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          'Guess the author',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 16),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                scheme.primaryContainer.withValues(alpha: 0.5),
                                scheme.secondaryContainer.withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              '“${_quote!.text}”',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.35),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text('Who said it?', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 12),
                        ..._choices.map(
                          (n) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: FilledButton.tonal(
                              onPressed: _answered
                                  ? null
                                  : () => _guess(n),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                              ),
                              child: Text(n),
                            ),
                          ),
                        ),
                        if (_answered) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _loadRound(names),
                            icon: const Icon(Icons.navigate_next),
                            label: const Text('Next round'),
                          ),
                        ],
                      ],
                    ),
    );
  }
}
