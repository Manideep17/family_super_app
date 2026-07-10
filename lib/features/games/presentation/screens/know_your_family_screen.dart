import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../family/domain/entities/family_member.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';

enum _QKind { displayForEmail, greetingForMember }

class _Question {
  const _Question({
    required this.prompt,
    required this.choices,
    required this.answer,
  });

  final String prompt;
  final List<String> choices;
  final String answer;
}

class KnowYourFamilyScreen extends ConsumerStatefulWidget {
  const KnowYourFamilyScreen({super.key});

  @override
  ConsumerState<KnowYourFamilyScreen> createState() =>
      _KnowYourFamilyScreenState();
}

class _KnowYourFamilyScreenState extends ConsumerState<KnowYourFamilyScreen> {
  final _random = Random();
  _Question? _q;
  bool _answered = false;

  List<String> _shuffledChoices(List<String> wrongPool, String answer) {
    final set = wrongPool.toSet().toList()..shuffle(_random);
    if (!set.contains(answer)) set.add(answer);
    while (set.length < 4 && wrongPool.isNotEmpty) {
      set.add(wrongPool[_random.nextInt(wrongPool.length)]);
    }
    return (set.toList()..shuffle(_random)).take(4).toList();
  }

  void _next(List<FamilyMember> members) {
    if (members.length < 2) return;
    final subject = members[_random.nextInt(members.length)];
    final kind =
        _random.nextBool() ? _QKind.displayForEmail : _QKind.greetingForMember;

    late _Question q;
    switch (kind) {
      case _QKind.displayForEmail:
        final wrong = members
            .where((m) => m.email != subject.email)
            .map((m) => m.displayName)
            .toList();
        q = _Question(
          prompt: 'Who uses ${subject.email}?',
          choices: _shuffledChoices(wrong, subject.displayName),
          answer: subject.displayName,
        );
      case _QKind.greetingForMember:
        final answer = subject.greeting.isNotEmpty
            ? subject.greeting
            : 'No custom greeting';
        final wrong = members
            .where((m) => m.uid != subject.uid)
            .map((m) =>
                m.greeting.isNotEmpty ? m.greeting : 'No custom greeting')
            .toList();
        q = _Question(
          prompt: 'What greeting is set for ${subject.displayName}?',
          choices: _shuffledChoices(wrong, answer),
          answer: answer,
        );
    }

    setState(() {
      _q = q;
      _answered = false;
    });
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pick(String choice) async {
    if (_answered || _q == null) return;
    setState(() => _answered = true);
    final correct = choice == _q!.answer;
    if (correct) {
      try {
        await ref
            .read(gamificationRepositoryProvider)
            .recordGameRoundWon(points: 10);
        ref.invalidate(leaderboardProvider);
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                correct ? 'Nice! +10 points' : 'Answer was: ${_q!.answer}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final members =
        ref.watch(familyMembersProvider).valueOrNull ?? const <FamilyMember>[];
    if (_q == null && members.length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _next(members);
      });
    }
    final q = _q;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Know your family'),
        actions: [
          IconButton(
            tooltip: 'Next question',
            onPressed: members.length < 2 ? null : () => _next(members),
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
      body: q == null
          ? const Center(
              child: Text('Add more family members to play this game.'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  q.prompt,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(height: 1.3),
                ),
                const SizedBox(height: 24),
                ...q.choices.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FilledButton.tonal(
                      onPressed: _answered ? null : () => _pick(c),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                      child: Text(c),
                    ),
                  ),
                ),
                if (_answered) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _next(members),
                    icon: const Icon(Icons.navigate_next),
                    label: const Text('Next question'),
                  ),
                ],
              ],
            ),
    );
  }
}
