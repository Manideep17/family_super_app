import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/predictions_providers.dart';

class PredictionsScreen extends ConsumerWidget {
  const PredictionsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final text = await showDialog<String?>(
      context: context,
      builder: (_) => const _PredictionInputDialog(
        title: 'New prediction',
        hintText: 'What do you think will happen?',
        confirmLabel: 'Save',
        maxLines: 3,
      ),
    );
    if (text == null || text.isEmpty || !context.mounted) return;
    try {
      await ref.read(predictionsRepositoryProvider).createPrediction(text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prediction saved')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _reveal(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final note = await showDialog<String?>(
      context: context,
      builder: (_) => const _PredictionInputDialog(
        title: 'Reveal prediction',
        hintText: 'Outcome note (optional)',
        confirmLabel: 'Reveal',
        maxLines: 2,
        allowEmpty: true,
      ),
    );
    if (note == null || !context.mounted) return;
    try {
      await ref.read(predictionsRepositoryProvider).revealPrediction(
            id,
            outcomeNote: note.isEmpty ? null : note,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as revealed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(predictionsStreamProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Family predictions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Predict'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.psychology_outlined, size: 56, color: scheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      'No predictions yet',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log a playful “we’ll see” bet — game scores, weather, who '
                      'shows up first for dinner. Resolve it later with Reveal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: () => _create(context, ref),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add first prediction'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = list[i];
              final mine = p.predictorUid == uid;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            p.revealed
                                ? Icons.check_circle_outline
                                : Icons.pending_outlined,
                            color: p.revealed ? scheme.primary : scheme.outline,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.predictorName,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          if (!p.revealed && mine)
                            TextButton(
                              onPressed: () => _reveal(context, ref, p.id),
                              child: const Text('Reveal'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(p.text, style: Theme.of(context).textTheme.bodyLarge),
                      if (p.revealed && (p.outcomeNote ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Outcome: ${p.outcomeNote}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Stateful dialog that owns its [TextEditingController] so the controller
/// is disposed only after the dialog itself is unmounted (and finishes its
/// exit animation).
class _PredictionInputDialog extends StatefulWidget {
  const _PredictionInputDialog({
    required this.title,
    required this.hintText,
    required this.confirmLabel,
    this.maxLines = 1,
    this.allowEmpty = false,
  });

  final String title;
  final String hintText;
  final String confirmLabel;
  final int maxLines;
  final bool allowEmpty;

  @override
  State<_PredictionInputDialog> createState() => _PredictionInputDialogState();
}

class _PredictionInputDialogState extends State<_PredictionInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (!widget.allowEmpty && value.isEmpty) {
      Navigator.pop<String?>(context, null);
      return;
    }
    Navigator.pop<String?>(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
        ),
        maxLines: widget.maxLines,
        autofocus: true,
        textInputAction: widget.maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.done,
        onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop<String?>(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
