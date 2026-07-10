import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/moderation_report_entry.dart';
import '../providers/moderation_reports_providers.dart';

/// Read-only inbox for the **family** owner (`families/{fid}.ownerUid`).
/// Requires Firestore rules + composite index on `reports` collection group.
class FamilyReportsInboxScreen extends ConsumerWidget {
  const FamilyReportsInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(familyModerationReportsStreamProvider);
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat.yMMMd().add_jm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports inbox'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Could not load reports',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Text(
                  'Deploy `firestore.rules` and indexes (see '
                  '`docs/MODERATION_AND_EDITS.md`), then try again.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
        data: (List<ModerationReportEntry> rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined, size: 56, color: scheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      'No open reports',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When someone flags chat or a diary memory, it appears '
                      'here for you to review.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rows[i];
              final kindLabel = r.kind.isEmpty ? 'report' : r.kind;
              final when = r.createdAt != null
                  ? dateFmt.format(r.createdAt!)
                  : '—';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(kindLabel),
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text('reporter: ${r.reporterUid}'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        r.preview,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Author uid: ${r.targetAuthorUid}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      Text(
                        when,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        r.firestorePath,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.outline,
                              fontFamily: 'monospace',
                              fontSize: 10,
                            ),
                      ),
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
