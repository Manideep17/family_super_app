import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/owner/owner_analytics_emails.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/owner_analytics_snapshot.dart';
import '../providers/owner_analytics_providers.dart';

/// App-wide metrics for owners (no family membership required). Firestore rules
/// must allow dashboard-owner reads; see `owner_analytics_dashboard/README.md`.
class OwnerAnalyticsScreen extends ConsumerWidget {
  const OwnerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authRepositoryProvider);
    final email = auth.currentUserEmail;
    if (!isOwnerAnalyticsEmail(email)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Owner analytics')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This screen is restricted. Add your email (lowercase) to '
              '`lib/core/owner/owner_analytics_emails.dart` or build with '
              '`--dart-define=OWNER_ANALYTICS_EMAILS=...`.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    final asyncSnap = ref.watch(ownerAnalyticsSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner analytics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                ref.invalidate(ownerAnalyticsSnapshotProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async => auth.signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Could not load data',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Text(
                  'Deploy updated firestore.rules and set up the owner allowlist '
                  'or appAnalyticsOwner claim (see owner_analytics_dashboard/README.md).',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
        data: (snap) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ownerAnalyticsSnapshotProvider);
            await ref.read(ownerAnalyticsSnapshotProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              FilledButton.tonalIcon(
                onPressed: () => context.go('/onboarding'),
                icon: const Icon(Icons.family_restroom_rounded),
                label: const Text('Create or join a family'),
              ),
              const SizedBox(height: 16),
              Text(
                snap.scopeLabel,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 16),
              _MetricGrid(snapshot: snap),
              const SizedBox(height: 20),
              Text(
                'Task status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              _KvCard(entries: snap.taskStatusCounts),
              const SizedBox(height: 20),
              Text(
                'Mood split',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              _KvCard(entries: snap.moodCounts),
              const SizedBox(height: 20),
              Text(
                'Top contributors',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              _ContributorsTable(rows: snap.topContributors),
              const SizedBox(height: 20),
              Text(
                'Recent activity',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              if (snap.recentActivityLines.isEmpty)
                Text(
                  'No recent activity.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                )
              else
                ...snap.recentActivityLines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(line),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.snapshot});

  final OwnerAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = <_Metric>[
      _Metric('Families', '${snapshot.familyCount}'),
      _Metric('Members', '${snapshot.totalMembers}'),
      _Metric('Stories', '${snapshot.storyCount}'),
      _Metric('Tasks', '${snapshot.taskCount}'),
      _Metric('Events', '${snapshot.eventCount}'),
      _Metric('Vault', '${snapshot.vaultCount}'),
      _Metric('Predictions', '${snapshot.predictionCount}'),
      _Metric('Games', '${snapshot.gamesCount}'),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cross = w > 520 ? 4 : 2;
        return GridView.count(
          crossAxisCount: cross,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: items
              .map(
                (m) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          m.label,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.value,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _Metric {
  _Metric(this.label, this.value);
  final String label;
  final String value;
}

class _KvCard extends StatelessWidget {
  const _KvCard({required this.entries});

  final Map<String, int> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'None',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          children: entries.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(e.key)),
                  Text(
                    '${e.value}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ContributorsTable extends StatelessWidget {
  const _ContributorsTable({required this.rows});

  final List<OwnerContributorRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No contributor stats yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Pts'), numeric: true),
            DataColumn(label: Text('Stories'), numeric: true),
            DataColumn(label: Text('Games'), numeric: true),
          ],
          rows: rows.map((r) {
            final label =
                '${r.displayName} (${r.familyLabel})';
            return DataRow(
              cells: [
                DataCell(Text(label)),
                DataCell(Text('${r.points}')),
                DataCell(Text('${r.storiesCreated}')),
                DataCell(Text('${r.gamesWon}')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
