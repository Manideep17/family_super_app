import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/festivals/indian_festivals.dart';
import '../../../../core/network/sync_health.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../../calendar/presentation/screens/calendar_screen.dart';
import '../../../diary/domain/entities/story.dart';
import '../../../diary/presentation/providers/diary_providers.dart';
import '../../../diary/presentation/screens/create_story_screen.dart';
import '../../../diary/presentation/screens/story_detail_screen.dart';
import '../../../games/presentation/screens/games_hub_screen.dart';
import '../../../gamification/domain/entities/weekly_champion.dart';
import '../../../gamification/domain/title_catalog.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';
import '../../../gamification/presentation/screens/leaderboard_screen.dart';
import '../../../insights/presentation/screens/ai_quiz_screen.dart';
import '../../../insights/presentation/screens/best_moments_screen.dart';
import '../../../insights/presentation/screens/mood_insights_screen.dart';
import '../../../insights/presentation/screens/weekly_digest_screen.dart';
import '../../../predictions/presentation/screens/predictions_screen.dart';
import '../../../polls/presentation/screens/family_polls_screen.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../../profile/presentation/providers/user_profile_providers.dart';
import '../../../tasks/domain/entities/family_task.dart';
import '../../../tasks/presentation/providers/tasks_providers.dart';
import '../../../tasks/presentation/screens/create_task_screen.dart';
import '../../../tasks/presentation/screens/task_detail_screen.dart';
import '../../../timeline/presentation/screens/timeline_screen.dart';
import '../../../vault/presentation/screens/vault_screen.dart';

/// Personalized home screen — gradient hero, snapshot grid, on-this-day,
/// recent memories, weekly champion strip.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentMemberProvider).valueOrNull;
    final meProfile = ref.watch(myUserProfileProvider).valueOrNull;
    final authUser = FirebaseAuth.instance.currentUser;
    final resolvedDisplayName = (() {
      final memberName = me?.displayName.trim();
      if (memberName != null && memberName.isNotEmpty) return memberName;
      final profileName = meProfile?.displayName.trim();
      if (profileName != null && profileName.isNotEmpty) return profileName;
      final authName = authUser?.displayName?.trim();
      if (authName != null && authName.isNotEmpty) return authName;
      final emailPrefix = authUser?.email?.split('@').first.trim();
      if (emailPrefix != null && emailPrefix.isNotEmpty) return emailPrefix;
      return 'Family';
    })();
    final email = me?.email.toLowerCase() ?? '';
    final scheme = Theme.of(context).colorScheme;
    final family = ref.watch(currentFamilyProvider).valueOrNull;
    final pinned = family?.pinnedAnnouncement.trim() ?? '';
    final storiesAsync = ref.watch(storiesStreamProvider);
    final tasksAsync = ref.watch(myTasksStreamProvider);
    final eventsAsync = ref.watch(calendarEventsProvider);
    final championAsync = ref.watch(weeklyChampionProvider);
    final myProfile = ref.watch(myUserProfileProvider);

    final pendingForMe = tasksAsync.maybeWhen(
      data: (tasks) => tasks
          .where(
            (t) =>
                t.isAssignee(email) &&
                (t.status == TaskStatus.pending ||
                    t.status == TaskStatus.submitted),
          )
          .toList(),
      orElse: () => <FamilyTask>[],
    );

    final upcoming = eventsAsync.maybeWhen(
      data: (events) {
        final now = DateTime.now();
        final soon = events
            .where((e) =>
                e.startAt.isAfter(now.subtract(const Duration(hours: 1))))
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
        return soon.take(3).toList();
      },
      orElse: () => const [],
    );

    final stories = storiesAsync.value ?? const <Story>[];
    final memoriesThisWeek = stories
        .where((s) => s.createdAt
            .isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .length;
    final onThisDay = stories
        .where((s) => _isAnniversary(s.createdAt, DateTime.now()))
        .toList();
    final recent = [...stories]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentTop = recent.take(5).toList();
    final streak = _familyActivityStreak(stories, tasksAsync.value ?? const []);
    final rituals = _buildRituals(
      stories: stories,
      tasks: tasksAsync.value ?? const [],
      now: DateTime.now(),
    );
    final ritualsDone = rituals.where((r) => r.done).length;
    final ritualProgress = rituals.isEmpty ? 0.0 : ritualsDone / rituals.length;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(storiesStreamProvider);
        ref.invalidate(myTasksStreamProvider);
        ref.invalidate(calendarEventsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _HeroCard(
              greeting: _greeting(custom: me?.greeting),
              displayName: resolvedDisplayName,
              memberAccent: AppTheme.colorForMember(
                email.isNotEmpty ? email : resolvedDisplayName,
              ),
              avatarUrl: myProfile.maybeWhen(
                data: (p) => p?.avatarUrl,
                orElse: () => null,
              ),
              memoriesThisWeek: memoriesThisWeek,
              pendingTasks: pendingForMe.length,
            ).animate().fadeIn(duration: 320.ms).slideY(
                  begin: -0.05,
                  duration: 320.ms,
                  curve: Curves.easeOut,
                ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _SyncHealthBanner(),
          ),
          if (pinned.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Material(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        color: scheme.onPrimaryContainer,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Family announcement',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pinned,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                    height: 1.35,
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
          if (IndianFestivals.next() != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _FestivalBanner(festival: IndianFestivals.next()!),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _StreakCard(
              streakDays: streak,
              progress: (streak > 7 ? 7 : streak) / 7,
            ).animate().fadeIn(duration: 280.ms),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _RitualCard(
              rituals: rituals,
              completedCount: ritualsDone,
              progress: ritualProgress,
            ).animate().fadeIn(duration: 280.ms),
          ),
          const SizedBox(height: 16),
          championAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (ch) {
              if (ch == null || (ch.name ?? '').isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: _ChampionStrip(champion: ch),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                _SnapshotTile(
                  icon: Icons.task_alt_rounded,
                  iconBg: scheme.primaryContainer,
                  iconColor: scheme.onPrimaryContainer,
                  label: 'Open tasks',
                  value: '${pendingForMe.length}',
                  hint: pendingForMe.isEmpty ? 'all clear ✨' : 'tap to view',
                  onTap: () {},
                ),
                _SnapshotTile(
                  icon: Icons.auto_stories_rounded,
                  iconBg: scheme.secondaryContainer,
                  iconColor: scheme.onSecondaryContainer,
                  label: 'This week',
                  value: '$memoriesThisWeek',
                  hint: 'memor${memoriesThisWeek == 1 ? 'y' : 'ies'} written',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TimelineScreen(),
                    ),
                  ),
                ),
                _SnapshotTile(
                  icon: Icons.event_rounded,
                  iconBg: scheme.tertiaryContainer,
                  iconColor: scheme.onTertiaryContainer,
                  label: 'Upcoming',
                  value: '${upcoming.length}',
                  hint: upcoming.isEmpty
                      ? 'no events soon'
                      : DateFormat.MMMd().format(upcoming.first.startAt),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const CalendarScreen()),
                  ),
                ),
                _SnapshotTile(
                  icon: Icons.insights_rounded,
                  iconBg: Colors.pink.shade100,
                  iconColor: Colors.pink.shade900,
                  label: 'Mood',
                  value: stories.isEmpty
                      ? '—'
                      : _moodEmoji(_dominantMood(stories)),
                  hint: stories.isEmpty ? 'no entries yet' : 'family vibe',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MoodInsightsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Quick actions',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _ActionTile(
                  icon: Icons.edit_note_rounded,
                  label: 'New memory',
                  color: scheme.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const CreateStoryScreen()),
                  ),
                ),
                _ActionTile(
                  icon: Icons.add_task_rounded,
                  label: 'Assign',
                  color: scheme.secondary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => const CreateTaskScreen(),
                    ),
                  ),
                ),
                _ActionTile(
                  icon: Icons.sports_esports_rounded,
                  label: 'Games',
                  color: scheme.tertiary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const GamesHubScreen()),
                  ),
                ),
                _ActionTile(
                  icon: Icons.psychology_alt_rounded,
                  label: 'AI quiz',
                  color: Colors.purple,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const AiQuizScreen()),
                  ),
                ),
                _ActionTile(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Weekly digest',
                  color: Colors.deepOrange,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const WeeklyDigestScreen()),
                  ),
                ),
                _ActionTile(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Best moments',
                  color: Colors.amber.shade700,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BestMomentsScreen(),
                    ),
                  ),
                ),
                _ActionTile(
                  icon: Icons.lightbulb_outline,
                  label: 'Predictions',
                  color: Colors.teal,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PredictionsScreen(),
                    ),
                  ),
                ),
                _ActionTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Vault',
                  color: Colors.indigo,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const VaultScreen()),
                  ),
                ),
                _ActionTile(
                  icon: Icons.emoji_events_outlined,
                  label: 'Leaderboard',
                  color: Colors.orange,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LeaderboardScreen(),
                    ),
                  ),
                ),
                _ActionTile(
                  icon: Icons.poll_outlined,
                  label: 'Polls',
                  color: Colors.deepPurple,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FamilyPollsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (onThisDay.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.cake_rounded, color: scheme.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'On this day',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            ...onThisDay.take(2).map(
                  (s) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _OnThisDayCard(story: s),
                  ),
                ),
            const SizedBox(height: 10),
          ],
          if (pendingForMe.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Needs your attention',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            ...pendingForMe.take(3).map(
                  (t) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Card(
                      child: ListTile(
                        leading: Icon(
                          t.status == TaskStatus.submitted
                              ? Icons.hourglass_top_rounded
                              : Icons.task_alt_outlined,
                          color: scheme.secondary,
                        ),
                        title: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          t.status == TaskStatus.submitted
                              ? 'Waiting for assigner approval'
                              : 'Due ${DateFormat.yMMMd().format(t.dueAt.toLocal())}',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+${t.rewardPoints}',
                            style: TextStyle(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TaskDetailScreen(taskId: t.id),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 6),
          ],
          if (upcoming.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Upcoming',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            ...upcoming.map(
              (e) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Card(
                  child: ListTile(
                    leading: Icon(Icons.event_rounded, color: scheme.primary),
                    title: Text(e.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      DateFormat.MMMd().add_jm().format(e.startAt.toLocal()),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CalendarScreen(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Recent memories',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (recentTop.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Text(
                'No stories yet — tap “New memory” to start the diary.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recentTop.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) {
                  final s = recentTop[i];
                  return _MemoryCard(story: s);
                },
              ),
            ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Tip: Swipe down to refresh. Drawer has timeline, calendar, vault, mood insights, and best moments.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isAnniversary(DateTime a, DateTime b) {
  if (a.year >= b.year) return false;
  return a.month == b.month && a.day == b.day;
}

String _greeting({String? custom}) {
  final c = custom?.trim();
  if (c != null && c.isNotEmpty) return c;
  final h = DateTime.now().hour;
  if (h < 5) return 'Up late';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  if (h < 21) return 'Good evening';
  return 'Good night';
}

String _dominantMood(List<Story> stories) {
  final counts = <String, int>{};
  for (final s in stories) {
    counts[s.mood] = (counts[s.mood] ?? 0) + 1;
  }
  if (counts.isEmpty) return 'happy';
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.first.key;
}

String _moodEmoji(String mood) {
  switch (mood) {
    case 'happy':
      return '😊';
    case 'fun':
      return '🎉';
    case 'love':
      return '❤️';
    case 'proud':
      return '🌟';
    case 'calm':
      return '🌿';
    case 'sad':
      return '💧';
    case 'angry':
      return '🔥';
  }
  return '✨';
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.greeting,
    required this.displayName,
    required this.avatarUrl,
    required this.memoriesThisWeek,
    required this.pendingTasks,
    this.memberAccent,
  });

  final String greeting;
  final String displayName;
  final String? avatarUrl;
  final int memoriesThisWeek;
  final int pendingTasks;

  /// Per-member accent (see [AppTheme.colorForMember]) — gives each family
  /// member a consistent "signature color" on their avatar across the app.
  final Color? memberAccent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AppGradient(
        opacity: 0.7,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  image: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: memberAccent ?? scheme.primary,
                ),
                child: avatarUrl == null || avatarUrl!.isEmpty
                    ? Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting,',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      displayName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pendingTasks == 0 && memoriesThisWeek == 0
                          ? 'A blank canvas for your family today.'
                          : pendingTasks == 0
                              ? '$memoriesThisWeek new memor${memoriesThisWeek == 1 ? 'y' : 'ies'} this week.'
                              : '$pendingTasks task${pendingTasks == 1 ? '' : 's'} waiting · '
                                  '$memoriesThisWeek memor${memoriesThisWeek == 1 ? 'y' : 'ies'} this week',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RitualItem {
  const _RitualItem({
    required this.title,
    required this.hint,
    required this.done,
    required this.icon,
  });

  final String title;
  final String hint;
  final bool done;
  final IconData icon;
}

/// Festival/tradition nudge — the "fun & family-specific" layer generic
/// organizer apps don't have. Tapping opens a diary entry pre-titled for
/// the occasion so adding a tradition/photo takes one tap, not a blank page.
class _FestivalBanner extends StatelessWidget {
  const _FestivalBanner({required this.festival});

  final IndianFestival festival;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = IndianFestivals.daysUntil(festival);
    final when = days <= 0
        ? 'today'
        : days == 1
            ? 'tomorrow'
            : 'in $days days';
    return Material(
      color: scheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CreateStoryScreen(
              initialTitle: 'Our ${festival.name} this year',
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(festival.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${festival.name} ${festival.approximate ? '(approx.) ' : ''}is $when',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: scheme.onTertiaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      'Tap to add a family tradition or photo',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onTertiaryContainer.withValues(alpha: 0.85),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streakDays, required this.progress});

  final int streakDays;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = progress.clamp(0, 1).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department_rounded,
                    color: scheme.tertiary),
                const SizedBox(width: 8),
                Text(
                  'Family streak',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '$streakDays day${streakDays == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: clamped,
              minHeight: 10,
              borderRadius: BorderRadius.circular(20),
            ),
            const SizedBox(height: 8),
            Text(
              streakDays >= 7
                  ? 'Reward unlocked: Family Flame badge'
                  : 'Keep activity going to unlock Family Flame at 7 days.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RitualCard extends StatelessWidget {
  const _RitualCard({
    required this.rituals,
    required this.completedCount,
    required this.progress,
  });

  final List<_RitualItem> rituals;
  final int completedCount;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = progress.clamp(0, 1).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.diversity_3_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Daily rituals',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$completedCount/${rituals.length}',
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: clamped,
              minHeight: 10,
              borderRadius: BorderRadius.circular(20),
            ),
            const SizedBox(height: 12),
            ...rituals.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      r.done ? Icons.check_circle : r.icon,
                      color: r.done ? Colors.green : scheme.outline,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${r.title} · ${r.hint}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (completedCount == rituals.length)
              Text(
                'Reward unlocked: +15 family vibe bonus',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SyncHealthBanner extends StatelessWidget {
  const _SyncHealthBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<SyncHealthSnapshot>(
      valueListenable: SyncHealth.notifier,
      builder: (context, state, _) {
        if (state.state == 'idle') {
          return const SizedBox.shrink();
        }
        final degraded = state.state == 'degraded';
        return Material(
          color: degraded ? scheme.errorContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  degraded
                      ? Icons.sync_problem_rounded
                      : Icons.cloud_done_rounded,
                  color: degraded ? scheme.onErrorContainer : scheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    degraded
                        ? 'Sync issue: ${state.message ?? 'Please retry'}'
                        : 'Sync healthy${state.message == null ? '' : ' · ${state.message}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChampionStrip extends ConsumerWidget {
  const _ChampionStrip({required this.champion});

  final WeeklyChampion champion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isMe = champion.uid != null &&
        myUid != null &&
        champion.uid == myUid;

    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.military_tech_rounded,
                    color: scheme.onSecondaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Champion · ${champion.name ?? ''} · ${champion.points} pts (${champion.weekId})',
                    style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (isMe) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                  onPressed: () async {
                    try {
                      await ref
                          .read(gamificationRepositoryProvider)
                          .claimWeeklyChampionTitle();
                      ref.invalidate(myMemberStatsProvider);
                      ref.invalidate(leaderboardProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Title set to "${TitleCatalog.weeklyChampionTitle}"',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                  child: const Text('Wear champion title'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  const _SnapshotTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      hint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 84,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnThisDayCard extends StatelessWidget {
  const _OnThisDayCard({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final years = DateTime.now().year - story.createdAt.year;
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StoryDetailScreen(storyId: story.id),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (story.imageUrls.isNotEmpty)
              SizedBox(
                width: 110,
                height: 110,
                child: Image.network(
                  story.imageUrls.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: scheme.surfaceContainerHigh,
                    child: Icon(Icons.image_not_supported_outlined,
                        color: scheme.outline),
                  ),
                ),
              )
            else
              Container(
                width: 110,
                height: 110,
                color: scheme.primaryContainer,
                child: Icon(Icons.cake_rounded,
                    color: scheme.onPrimaryContainer, size: 48),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$years year${years == 1 ? '' : 's'} ago today',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      story.title.isNotEmpty ? story.title : 'A memory',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      story.authorName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 240,
      child: Card(
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => StoryDetailScreen(storyId: story.id),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: story.imageUrls.isNotEmpty
                    ? Image.network(
                        story.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: scheme.surfaceContainerHigh,
                          child: Icon(Icons.image_not_supported_outlined,
                              color: scheme.outline),
                        ),
                      )
                    : Container(
                        color: scheme.primaryContainer,
                        child: Center(
                          child: Icon(
                            Icons.auto_stories_rounded,
                            color: scheme.onPrimaryContainer,
                            size: 48,
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title.isNotEmpty ? story.title : 'Memory',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      story.authorName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
    );
  }
}

int _familyActivityStreak(List<Story> stories, List<FamilyTask> tasks) {
  final days = <String>{};
  for (final s in stories) {
    final d = DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day);
    days.add('${d.year}-${d.month}-${d.day}');
  }
  for (final t in tasks) {
    final d = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
    days.add('${d.year}-${d.month}-${d.day}');
  }
  var streak = 0;
  var cursor = DateTime.now();
  while (true) {
    final d = DateTime(cursor.year, cursor.month, cursor.day);
    final key = '${d.year}-${d.month}-${d.day}';
    if (!days.contains(key)) break;
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

List<_RitualItem> _buildRituals({
  required List<Story> stories,
  required List<FamilyTask> tasks,
  required DateTime now,
}) {
  bool isToday(DateTime d) =>
      d.year == now.year && d.month == now.month && d.day == now.day;
  final memoryToday = stories.any((s) => isToday(s.createdAt));
  final taskToday = tasks.any((t) => isToday(t.createdAt));
  final moodToday =
      stories.any((s) => isToday(s.createdAt) && s.mood.isNotEmpty);
  return [
    _RitualItem(
      title: 'Share one memory',
      hint: memoryToday ? 'done today' : 'pending',
      done: memoryToday,
      icon: Icons.auto_stories_outlined,
    ),
    _RitualItem(
      title: 'Do one task action',
      hint: taskToday ? 'done today' : 'pending',
      done: taskToday,
      icon: Icons.task_alt_outlined,
    ),
    _RitualItem(
      title: 'Log your mood',
      hint: moodToday ? 'done today' : 'pending',
      done: moodToday,
      icon: Icons.mood_outlined,
    ),
  ];
}
