import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gamification/presentation/providers/gamification_providers.dart';
import '../providers/family_games_providers.dart';

const _creativePrompts = <String>[
  'Draw or describe a tiny moment from today that nobody else noticed.',
  'If our family had a mascot, what would it be and why?',
  'Write a six-word story about last weekend.',
  'What song matches our family vibe this week?',
  'Share one photo idea we should take together soon.',
  'What tradition should we start this month?',
  'Free topic: one thing you are grateful for today.',
];

String _promptForWeekday() {
  final i = (DateTime.now().weekday - 1).clamp(0, 6);
  return _creativePrompts[i];
}

/// Daily creative prompt + family submissions (original “Creative Challenge”).
class CreativeChallengeScreen extends ConsumerStatefulWidget {
  const CreativeChallengeScreen({super.key});

  @override
  ConsumerState<CreativeChallengeScreen> createState() => _CreativeChallengeScreenState();
}

class _CreativeChallengeScreenState extends ConsumerState<CreativeChallengeScreen> {
  final _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await ref.read(familyGamesRepositoryProvider).submitCreativeChallenge(
            promptKey: creativeDayKey(),
            body: _body.text,
          );
      ref.invalidate(leaderboardProvider);
      ref.invalidate(creativeSubmissionsTodayProvider);
      if (mounted) {
        _body.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Posted · +5 pts')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final listAsync = ref.watch(creativeSubmissionsTodayProvider);
    final prompt = _promptForWeekday();

    return Scaffold(
      appBar: AppBar(title: const Text('Creative challenge')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Today’s prompt',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(prompt, style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.35)),
          const SizedBox(height: 20),
          TextField(
            controller: _body,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Your submission',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.publish_rounded),
            label: const Text('Post for the family'),
          ),
          const SizedBox(height: 32),
          Text('Today’s wall', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          listAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('$e'),
            data: (rows) {
              if (rows.isEmpty) {
                return Text(
                  'No posts yet today — be the first.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                );
              }
              return Column(
                children: rows
                    .map(
                      (s) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(s.authorName, style: Theme.of(context).textTheme.titleSmall),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(s.body),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
