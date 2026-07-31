import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../../calendar/presentation/screens/calendar_screen.dart';
import '../../../diary/domain/entities/story.dart';
import '../../../diary/presentation/providers/diary_providers.dart';
import '../../../diary/presentation/screens/story_detail_screen.dart';
import '../../../polls/domain/family_poll.dart';
import '../../../polls/presentation/providers/polls_providers.dart';
import '../../../polls/presentation/screens/family_polls_screen.dart';
import '../../../tasks/domain/entities/family_task.dart';
import '../../../tasks/presentation/providers/tasks_providers.dart';
import '../../../tasks/presentation/screens/task_detail_screen.dart';
import '../../../vault/domain/entities/vault_item.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../../../vault/presentation/screens/vault_screen.dart';

/// Single scrollable "what's new" timeline — diary entries, tasks, vault
/// photos, polls, and nearby calendar events interleaved by recency, instead
/// of making someone check four separate tabs to find out what happened.
/// See docs/PRODUCT_STRATEGY_AND_ENGAGEMENT.md, "Feed over tabs."
class FamilyFeedScreen extends ConsumerWidget {
  const FamilyFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final storiesAsync = ref.watch(storiesStreamProvider);
    final tasksAsync = ref.watch(myTasksStreamProvider);
    final vaultAsync = ref.watch(vaultItemsProvider);
    final pollsAsync = ref.watch(familyPollsStreamProvider);
    final eventsAsync = ref.watch(calendarEventsProvider);

    // Keep the spinner up until every source has *settled* (either got data
    // or errored) — not until all five happen to be loading simultaneously.
    // With AND across sources, the instant any single source resolved (even
    // to an error) the whole expression flipped false and the feed could
    // flash "Nothing yet" while the other four hadn't loaded yet. OR fixes
    // that: as long as even one source is still genuinely mid-flight, keep
    // waiting.
    final stillLoadingEverything = (storiesAsync.isLoading && !storiesAsync.hasValue) ||
        (tasksAsync.isLoading && !tasksAsync.hasValue) ||
        (vaultAsync.isLoading && !vaultAsync.hasValue) ||
        (pollsAsync.isLoading && !pollsAsync.hasValue) ||
        (eventsAsync.isLoading && !eventsAsync.hasValue);

    if (stillLoadingEverything) {
      return const Center(child: CircularProgressIndicator());
    }

    final entries = <_FeedEntry>[];

    for (final s in storiesAsync.value ?? const <Story>[]) {
      entries.add(
        _FeedEntry(
          timestamp: s.createdAt,
          icon: Icons.auto_stories_rounded,
          iconColor: scheme.primary,
          title: s.title.isNotEmpty ? s.title : 'New memory',
          subtitle: 'Diary · ${s.authorName}',
          onTap: (ctx) => Navigator.of(ctx).push(
            MaterialPageRoute<void>(
              builder: (_) => StoryDetailScreen(storyId: s.id),
            ),
          ),
        ),
      );
    }

    for (final t in tasksAsync.value ?? const <FamilyTask>[]) {
      entries.add(
        _FeedEntry(
          timestamp: t.createdAt,
          icon: t.status == TaskStatus.approved
              ? Icons.task_alt_rounded
              : Icons.task_outlined,
          iconColor: scheme.secondary,
          title: t.title,
          subtitle:
              'Task · ${t.assigneeName} · ${_taskStatusLabel(t.status)}',
          onTap: (ctx) => Navigator.of(ctx).push(
            MaterialPageRoute<void>(
              builder: (_) => TaskDetailScreen(taskId: t.id),
            ),
          ),
        ),
      );
    }

    for (final v in vaultAsync.value ?? const <VaultItem>[]) {
      entries.add(
        _FeedEntry(
          timestamp: v.createdAt,
          icon: Icons.photo_rounded,
          iconColor: scheme.tertiary,
          title: v.title.isNotEmpty ? v.title : 'New photo',
          subtitle: 'Vault · ${v.uploaderName}',
          onTap: (ctx) => Navigator.of(ctx).push(
            MaterialPageRoute<void>(
              builder: (_) => const VaultScreen(),
            ),
          ),
        ),
      );
    }

    for (final p in pollsAsync.value ?? const <FamilyPoll>[]) {
      entries.add(
        _FeedEntry(
          timestamp: p.createdAt,
          icon: Icons.poll_rounded,
          iconColor: Colors.deepPurple,
          title: p.question,
          subtitle: 'Poll',
          onTap: (ctx) => Navigator.of(ctx).push(
            MaterialPageRoute<void>(
              builder: (_) => const FamilyPollsScreen(),
            ),
          ),
        ),
      );
    }

    final now = DateTime.now();
    for (final e in eventsAsync.value ?? const []) {
      // Only recent-past/near-future events — the calendar screen already
      // owns the full schedule; the feed just surfaces what's relevant now.
      if (e.startAt.isBefore(now.subtract(const Duration(days: 3)))) continue;
      entries.add(
        _FeedEntry(
          timestamp: e.startAt,
          icon: Icons.event_rounded,
          iconColor: Colors.teal,
          title: e.title,
          subtitle:
              'Calendar · ${DateFormat.MMMd().add_jm().format(e.startAt.toLocal())}',
          onTap: (ctx) => Navigator.of(ctx).push(
            MaterialPageRoute<void>(
              builder: (_) => const CalendarScreen(),
            ),
          ),
        ),
      );
    }

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final top = entries.take(60).toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(storiesStreamProvider);
        ref.invalidate(myTasksStreamProvider);
        ref.invalidate(vaultItemsProvider);
        ref.invalidate(familyPollsStreamProvider);
        ref.invalidate(calendarEventsProvider);
      },
      child: top.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Nothing yet — add a memory, task, or photo to get '
                      'things started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              itemCount: top.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) {
                final entry = top[i];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: entry.iconColor.withValues(alpha: 0.15),
                      child: Icon(entry.icon, color: entry.iconColor),
                    ),
                    title: Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${entry.subtitle} · ${_relativeTime(entry.timestamp)}',
                    ),
                    onTap: () => entry.onTap(ctx),
                  ),
                );
              },
            ),
    );
  }
}

String _taskStatusLabel(TaskStatus s) {
  switch (s) {
    case TaskStatus.pending:
      return 'pending';
    case TaskStatus.submitted:
      return 'submitted';
    case TaskStatus.approved:
      return 'done';
    case TaskStatus.rejected:
      return 'rejected';
  }
}

String _relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.MMMd().format(t);
}

class _FeedEntry {
  const _FeedEntry({
    required this.timestamp,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final DateTime timestamp;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final void Function(BuildContext) onTap;
}
