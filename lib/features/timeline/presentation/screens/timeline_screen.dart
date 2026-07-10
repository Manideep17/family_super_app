import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../family/domain/entities/family_member.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../../calendar/presentation/screens/event_detail_screen.dart';
import '../../../diary/presentation/diary_moods.dart';
import '../../../diary/presentation/screens/story_detail_screen.dart';
import '../../domain/entities/timeline_entry.dart';
import '../providers/timeline_providers.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  String? _personEmail;
  bool _onThisDayOnly = false;
  bool _last30DaysOnly = false;

  static final _dateFmt = DateFormat.yMMMd().add_jm();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(timelineStreamProvider);
    final members =
        ref.watch(familyMembersProvider).valueOrNull ?? const <FamilyMember>[];
    final scheme = Theme.of(context).colorScheme;

    final personItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('Everyone'),
      ),
      ...members.map(
        (m) => DropdownMenuItem<String?>(
          value: m.email.toLowerCase(),
          child: Text(m.displayName),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Memory timeline')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String?>(
                    value: _personEmail,
                    hint: const Text('Everyone'),
                    items: personItems,
                    onChanged: (v) => setState(() => _personEmail = v),
                  ),
                  FilterChip(
                    label: const Text('On this day'),
                    selected: _onThisDayOnly,
                    onSelected: (v) => setState(() => _onThisDayOnly = v),
                    avatar: const Icon(Icons.cake_outlined, size: 18),
                  ),
                  FilterChip(
                    label: const Text('Last 30 days'),
                    selected: _last30DaysOnly,
                    onSelected: (v) => setState(() => _last30DaysOnly = v),
                    avatar: const Icon(Icons.date_range, size: 18),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (entries) {
                final now = DateTime.now();
                var list = entries;
                if (_personEmail != null && _personEmail!.isNotEmpty) {
                  list = list
                      .where((e) => e.involvesPerson(_personEmail!))
                      .toList();
                }
                if (_onThisDayOnly) {
                  list = list.where((e) => e.isOnThisDay(now)).toList();
                }
                if (_last30DaysOnly) {
                  final cutoff = now.subtract(const Duration(days: 30));
                  list = list.where((e) => !e.at.isBefore(cutoff)).toList();
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(timelineStreamProvider);
                    await ref.read(timelineStreamProvider.future);
                  },
                  child: list.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(32),
                          children: [
                            Icon(Icons.timeline, size: 48, color: scheme.outline),
                            const SizedBox(height: 12),
                            Text(
                              _onThisDayOnly
                                  ? 'No memories on this calendar day yet.'
                                  : _last30DaysOnly
                                      ? 'Nothing in the last 30 days for this filter.'
                                      : _personEmail != null &&
                                              _personEmail!.isNotEmpty
                                          ? 'No timeline items for that person with the current filters.'
                                          : 'Your family timeline will fill in as people add diary entries and calendar events.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            if (!_onThisDayOnly &&
                                !_last30DaysOnly &&
                                (_personEmail == null ||
                                    _personEmail!.isEmpty)) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Tip: open the Home tab and tap “Write a memory” to add the first story.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final e = list[i];
                            return _TimelineTile(
                              entry: e,
                              dateFmt: _dateFmt,
                              onTap: () {
                                if (e.kind == TimelineKind.story &&
                                    e.storyId != null) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          StoryDetailScreen(storyId: e.storyId!),
                                    ),
                                  );
                                } else if (e.kind == TimelineKind.calendarEvent &&
                                    e.eventId != null) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          EventDetailScreen(eventId: e.eventId!),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.entry,
    required this.dateFmt,
    required this.onTap,
  });

  final TimelineEntry entry;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isStory = entry.kind == TimelineKind.story;
    final badge = isStory ? 'Story' : _eventLabel(entry.eventType ?? 'other');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.thumbUrl != null && entry.thumbUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      entry.thumbUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderIcon(isStory, scheme),
                    ),
                  )
                else
                  _placeholderIcon(isStory, scheme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Chip(
                            label: Text(badge, style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          if (isStory && entry.mood != null) ...[
                            const SizedBox(width: 6),
                            Text(DiaryMoods.emojiFor(entry.mood!)),
                          ],
                        ],
                      ),
                      Text(
                        entry.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${entry.authorOrCreatorName} · ${dateFmt.format(entry.at)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderIcon(bool isStory, ColorScheme scheme) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isStory ? Icons.auto_stories_rounded : Icons.event_rounded,
        color: scheme.primary,
      ),
    );
  }

  String _eventLabel(String type) {
    switch (type) {
      case 'birthday':
        return 'Birthday';
      case 'trip':
        return 'Trip';
      case 'reminder':
        return 'Reminder';
      default:
        return 'Event';
    }
  }
}
