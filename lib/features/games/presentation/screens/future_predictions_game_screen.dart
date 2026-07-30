import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/analytics/app_analytics.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';

/// Future Predictions game (Phase 3).
///
/// Each prediction is a one-line claim about what the family thinks will
/// happen by a target date. The family can vote yes/no. When the target
/// date is reached, the author resolves the actual outcome and everyone who
/// guessed right earns points.
///
/// Firestore: `future_predictions/{id}` with shape:
/// {
///   text, authorUid, authorName, authorEmail,
///   targetAt: Timestamp,
///   votes: { uid: 'yes' | 'no' },     // family member votes
///   resolved: bool, outcome: 'yes' | 'no' | null,
///   createdAt
/// }
class FuturePredictionsGameScreen extends ConsumerStatefulWidget {
  const FuturePredictionsGameScreen({super.key});

  @override
  ConsumerState<FuturePredictionsGameScreen> createState() =>
      _FuturePredictionsGameScreenState();
}

class _FuturePredictionsGameScreenState
    extends ConsumerState<FuturePredictionsGameScreen> {
  CollectionReference<Map<String, dynamic>> get _col =>
      ref.read(familyScopeProvider).futurePredictions;

  Stream<List<Map<String, dynamic>>> _watch() => _col
      .orderBy('createdAt', descending: true)
      .limit(80)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Future<void> _create() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final result = await showDialog<_NewPrediction?>(
      context: context,
      builder: (_) => const _NewPredictionDialog(),
    );
    if (result == null) return;
    final email = user.email?.toLowerCase() ?? '';
    final member = ref.read(currentMemberProvider).valueOrNull;
    await _col.add({
      'text': result.text,
      'authorUid': user.uid,
      'authorName': member?.displayName ?? (user.displayName ?? 'Family'),
      'authorEmail': email,
      'targetAt': Timestamp.fromDate(result.target),
      'votes': <String, String>{},
      'resolved': false,
      'outcome': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    AppAnalytics.logEvent('prediction_created');
  }

  Future<void> _vote(String id, String value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _col.doc(id).update({'votes.$uid': value});
  }

  Future<void> _resolve(
      String id, String outcome, Map<String, String> votes) async {
    await _col.doc(id).update({
      'resolved': true,
      'outcome': outcome,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    AppAnalytics.logEvent('prediction_resolved', params: {'outcome': outcome});
    // Award points to family members whose vote matched the outcome.
    final repo = ref.read(gamificationRepositoryProvider);
    final me = FirebaseAuth.instance.currentUser?.uid;
    for (final entry in votes.entries) {
      if (entry.value == outcome && entry.key == me) {
        try {
          await repo.recordGameRoundWon(points: 10);
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Future predictions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_chart_rounded),
        label: const Text('Predict'),
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
                        const Icon(Icons.auto_graph_rounded, size: 36),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'What will happen?',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Make a prediction with a target date. Family '
                                'votes yes/no — winners earn +10 pts.',
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
                      'No predictions yet — tap Predict to start one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                ...list.map((p) => _PredictionCard(
                      data: p,
                      myUid: myUid,
                      onVote: (v) => _vote(p['id'] as String, v),
                      onResolve: (outcome) {
                        final votes =
                            (p['votes'] as Map<dynamic, dynamic>?) ?? {};
                        return _resolve(
                          p['id'] as String,
                          outcome,
                          votes.map(
                            (k, v) => MapEntry(k.toString(), v.toString()),
                          ),
                        );
                      },
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({
    required this.data,
    required this.myUid,
    required this.onVote,
    required this.onResolve,
  });

  final Map<String, dynamic> data;
  final String myUid;
  final ValueChanged<String> onVote;
  final Future<void> Function(String) onResolve;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = data['text']?.toString() ?? '';
    final authorName = data['authorName']?.toString() ?? '';
    final authorUid = data['authorUid']?.toString() ?? '';
    final resolved = data['resolved'] == true;
    final outcome = data['outcome']?.toString();
    final tsTarget = data['targetAt'];
    DateTime? target;
    if (tsTarget is Timestamp) target = tsTarget.toDate();
    final votes = (data['votes'] as Map<dynamic, dynamic>? ?? {})
        .map((k, v) => MapEntry(k.toString(), v.toString()));
    final yes = votes.values.where((v) => v == 'yes').length;
    final no = votes.values.where((v) => v == 'no').length;
    final myVote = votes[myUid];
    final isMine = authorUid == myUid;
    final dueReached = target != null && DateTime.now().isAfter(target);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      authorName,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  if (target != null)
                    Text(
                      'by ${DateFormat.yMMMd().format(target.toLocal())}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(text, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 12),
              if (resolved)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: outcome == 'yes'
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.redAccent.withValues(alpha: 0.1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        outcome == 'yes' ? Icons.check_circle : Icons.cancel,
                        color:
                            outcome == 'yes' ? Colors.green : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        outcome == 'yes' ? 'Came true' : 'Did not happen',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              else ...[
                Row(
                  children: [
                    _VoteButton(
                      icon: Icons.thumb_up_alt_outlined,
                      label: 'Yes · $yes',
                      selected: myVote == 'yes',
                      onTap: () => onVote('yes'),
                    ),
                    const SizedBox(width: 10),
                    _VoteButton(
                      icon: Icons.thumb_down_alt_outlined,
                      label: 'No · $no',
                      selected: myVote == 'no',
                      onTap: () => onVote('no'),
                    ),
                  ],
                ),
                if (isMine && dueReached) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onResolve('no'),
                          child: const Text('Mark: did not happen'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => onResolve('yes'),
                          child: const Text('Mark: came true'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHigh,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewPrediction {
  const _NewPrediction(this.text, this.target);
  final String text;
  final DateTime target;
}

class _NewPredictionDialog extends StatefulWidget {
  const _NewPredictionDialog();

  @override
  State<_NewPredictionDialog> createState() => _NewPredictionDialogState();
}

class _NewPredictionDialogState extends State<_NewPredictionDialog> {
  final _controller = TextEditingController();
  DateTime? _target;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _target = picked);
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || _target == null) {
      Navigator.pop<_NewPrediction?>(context, null);
      return;
    }
    Navigator.pop<_NewPrediction?>(
      context,
      _NewPrediction(text, _target!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New prediction'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'e.g. We will finish 20 tasks this month.',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _target == null
                      ? 'Pick a target date'
                      : 'By ${DateFormat.yMMMd().format(_target!)}',
                ),
              ),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: const Text('Date'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop<_NewPrediction?>(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
