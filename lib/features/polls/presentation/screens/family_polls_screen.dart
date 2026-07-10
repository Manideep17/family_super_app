import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/family_poll.dart';
import '../providers/polls_providers.dart';

/// Lightweight polls for the family (`families/{fid}/polls`).
class FamilyPollsScreen extends ConsumerWidget {
  const FamilyPollsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final pollsAsync = ref.watch(familyPollsStreamProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Family polls')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New poll'),
      ),
      body: pollsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (polls) {
          if (polls.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.poll_outlined, size: 56, color: scheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      'No polls yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap “New poll” for a quick family vote — pizza vs tacos, movie night picks, and more.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: polls.length,
            itemBuilder: (context, i) {
              return _PollCard(poll: polls[i], myUid: myUid);
            },
          );
        },
      ),
    );
  }

  static Future<void> _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    final bCtrl = TextEditingController();
    final cCtrl = TextEditingController();
    final dCtrl = TextEditingController();
    var anonymous = false;
    DateTime? closesAt;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('New poll'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    hintText: 'Pizza or tacos tonight?',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: aCtrl,
                  decoration: const InputDecoration(labelText: 'Option A'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bCtrl,
                  decoration: const InputDecoration(labelText: 'Option B'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Option C (optional)',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Option D (optional)',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Anonymous tally'),
                  subtitle: const Text(
                    'Hides your pick in the UI; family still sees totals.',
                  ),
                  value: anonymous,
                  onChanged: (v) => setSt(() => anonymous = v),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deadline (optional)'),
                  subtitle: Text(
                    closesAt == null
                        ? 'No deadline'
                        : DateFormat.yMMMd().add_jm().format(closesAt!),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.event_rounded),
                    onPressed: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: now,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (d == null || !ctx.mounted) return;
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(now),
                      );
                      if (t == null) return;
                      setSt(() {
                        closesAt = DateTime(
                          d.year,
                          d.month,
                          d.day,
                          t.hour,
                          t.minute,
                        );
                      });
                    },
                  ),
                ),
                if (closesAt != null)
                  TextButton(
                    onPressed: () => setSt(() => closesAt = null),
                    child: const Text('Clear deadline'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) {
      qCtrl.dispose();
      aCtrl.dispose();
      bCtrl.dispose();
      cCtrl.dispose();
      dCtrl.dispose();
      return;
    }
    try {
      await ref.read(pollsRepositoryProvider).createPoll(
            question: qCtrl.text,
            optionA: aCtrl.text,
            optionB: bCtrl.text,
            optionC: cCtrl.text,
            optionD: dCtrl.text,
            closesAt: closesAt,
            anonymous: anonymous,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poll posted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      qCtrl.dispose();
      aCtrl.dispose();
      bCtrl.dispose();
      cCtrl.dispose();
      dCtrl.dispose();
    }
  }
}

class _PollCard extends ConsumerWidget {
  const _PollCard({required this.poll, required this.myUid});

  final FamilyPoll poll;
  final String myUid;

  int _countFor(Map<String, String> votes, String letter) =>
      votes.values.where((v) => v == letter).length;

  String _labelForPick(String pick) {
    for (final e in poll.activeOptions) {
      if (e.key == pick) return e.value;
    }
    return pick;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final votesAsync = ref.watch(pollResponsesProvider(poll.id));

    return votesAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('$e'),
        ),
      ),
      data: (votes) {
        final isCreator = poll.createdBy == myUid;
        final closed = poll.isVotingClosed;
        final mine = votes[myUid];
        final fmt = DateFormat.yMMMd().add_jm();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        poll.question,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (isCreator) ...[
                      if (!closed)
                        IconButton(
                          tooltip: 'Close voting',
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Close poll?'),
                                content: const Text(
                                  'No one can change votes after this.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true) return;
                            try {
                              await ref
                                  .read(pollsRepositoryProvider)
                                  .closePoll(poll.id);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.lock_outline_rounded),
                        ),
                      IconButton(
                        tooltip: 'Delete poll',
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete poll?'),
                              content: const Text(
                                'This removes all votes for this poll.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          try {
                            await ref
                                .read(pollsRepositoryProvider)
                                .deletePoll(poll.id);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ],
                ),
                if (poll.anonymous)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Anonymous tally',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.tertiary,
                          ),
                    ),
                  ),
                if (poll.closesAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      poll.isVotingClosed
                          ? 'Closed ${fmt.format(poll.closesAt!)}'
                          : 'Closes ${fmt.format(poll.closesAt!)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                if (poll.closed && poll.closesAt == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Voting closed',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                const SizedBox(height: 8),
                ...poll.activeOptions.map((opt) {
                  final n = _countFor(votes, opt.key);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '$n · ${opt.value}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                _OptionButtons(
                  poll: poll,
                  closed: closed,
                  onVote: (pick) => _vote(context, ref, pick),
                ),
                if (mine != null && !poll.anonymous)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Your pick: ${_labelForPick(mine)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                          ),
                    ),
                  ),
                if (mine != null && poll.anonymous)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'You voted',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _vote(BuildContext context, WidgetRef ref, String pick) async {
    try {
      await ref.read(pollsRepositoryProvider).setMyVote(
            pollId: poll.id,
            pick: pick,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }
}

class _OptionButtons extends StatelessWidget {
  const _OptionButtons({
    required this.poll,
    required this.closed,
    required this.onVote,
  });

  final FamilyPoll poll;
  final bool closed;
  final void Function(String pick) onVote;

  @override
  Widget build(BuildContext context) {
    final opts = poll.activeOptions;
    if (opts.length <= 2) {
      return Row(
        children: [
          Expanded(
            child: FilledButton.tonal(
              onPressed:
                  closed ? null : () => onVote(opts[0].key),
              child: Text(
                opts[0].value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonal(
              onPressed:
                  closed ? null : () => onVote(opts[1].key),
              child: Text(
                opts[1].value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < opts.length; i += 2) ...[
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: closed
                      ? null
                      : () => onVote(opts[i].key),
                  child: Text(
                    opts[i].value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (i + 1 < opts.length) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: closed
                        ? null
                        : () => onVote(opts[i + 1].key),
                    child: Text(
                      opts[i + 1].value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (i + 2 < opts.length) const SizedBox(height: 8),
        ],
      ],
    );
  }
}
