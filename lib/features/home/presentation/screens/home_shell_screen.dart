import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/feedback_launch.dart';
import '../../../../core/owner/owner_analytics_emails.dart';
import '../../../../core/widget/home_widget_sync.dart';
import '../../../chat/presentation/screens/family_chat_screen.dart';
import '../../../family/domain/entities/family_member.dart';
import '../../../diary/presentation/screens/diary_feed_screen.dart';
import '../../../feed/presentation/screens/family_feed_screen.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../../family/presentation/screens/family_management_screen.dart';
import '../../../family/presentation/screens/invite_and_earn_screen.dart';
import '../../../insights/presentation/screens/ai_quiz_screen.dart';
import '../../../insights/presentation/screens/best_moments_screen.dart';
import '../../../insights/presentation/screens/mood_insights_screen.dart';
import '../../../tasks/presentation/screens/tasks_home_screen.dart';
import '../../../timeline/presentation/screens/timeline_screen.dart';
import '../../../calendar/presentation/screens/calendar_screen.dart';
import '../../../vault/presentation/screens/vault_screen.dart';
import '../../../gamification/presentation/providers/gamification_providers.dart';
import '../../../gamification/presentation/screens/leaderboard_screen.dart';
import '../../../games/presentation/screens/games_hub_screen.dart';
import '../../../lists/presentation/screens/shared_lists_home_screen.dart';
import '../../../polls/presentation/screens/family_polls_screen.dart';
import '../../../profile/presentation/providers/user_profile_providers.dart';
import '../../../tasks/domain/entities/family_task.dart';
import '../../../tasks/presentation/providers/tasks_providers.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../../core/router/app_router.dart';
import 'dashboard_screen.dart';

/// Home shell: dashboard + bottom tabs + drawer.
class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  int _index = 0;
  String? _warmedFamilyId;
  String? _lastWidgetSyncKey;

  static const _titles = ['Feed', 'Home', 'Family Chat', 'Diary', 'Tasks'];

  @override
  Widget build(BuildContext context) {
    final familyIdAsync = ref.watch(currentFamilyIdProvider);
    final familyId = familyIdAsync.valueOrNull;
    final waitingForFamily =
        familyIdAsync.isLoading || familyId == null || familyId.isEmpty;
    if (waitingForFamily) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_warmedFamilyId != familyId) {
      _warmedFamilyId = familyId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(gamificationRepositoryProvider).ensureMyProfile();
        ref.read(userProfileRepositoryProvider).ensureMyUserDoc();
      });
    }

    // Home-screen widget sync (Android) — fire-and-forget, only when the
    // family name or open-task count actually changed, so this doesn't
    // spam a native write on every unrelated rebuild.
    final widgetSyncFamily = ref.watch(currentFamilyProvider).valueOrNull;
    final widgetSyncTasks = ref.watch(myTasksStreamProvider).valueOrNull;
    if (widgetSyncFamily != null && widgetSyncTasks != null) {
      final openTaskCount = widgetSyncTasks
          .where((t) =>
              t.status == TaskStatus.pending ||
              t.status == TaskStatus.submitted)
          .length;
      final syncKey = '${widgetSyncFamily.name}|$openTaskCount';
      if (_lastWidgetSyncKey != syncKey) {
        _lastWidgetSyncKey = syncKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          HomeWidgetSync.sync(
            familyName: widgetSyncFamily.name,
            openTaskCount: openTaskCount,
          );
        });
      }
    }

    final auth = ref.watch(authRepositoryProvider);
    final showOwnerAnalytics =
        isOwnerAnalyticsEmail(auth.currentUserEmail);
    final me = ref.watch(currentMemberProvider).valueOrNull;
    final members =
        ref.watch(familyMembersProvider).valueOrNull ?? const <FamilyMember>[];
    final profileAsync = ref.watch(myUserProfileProvider);
    String memberInitial(FamilyMember? member) {
      final name = member?.displayName.trim();
      if (name != null && name.isNotEmpty) return name[0].toUpperCase();
      return '?';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(me?.displayName ?? 'Member'),
                accountEmail: Text(auth.currentUserEmail ?? ''),
                currentAccountPicture: profileAsync.maybeWhen(
                  data: (p) {
                    final url = p?.avatarUrl;
                    final initial = memberInitial(me);
                    if (url != null && url.isNotEmpty) {
                      return CircleAvatar(
                        backgroundImage: NetworkImage(url),
                        onBackgroundImageError: (_, __) {},
                      );
                    }
                    return CircleAvatar(child: Text(initial));
                  },
                  orElse: () {
                    final initial = memberInitial(me);
                    return CircleAvatar(child: Text(initial));
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('My profile'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const ProfileScreen()),
                  );
                },
              ),
              if (showOwnerAnalytics)
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: const Text('Owner analytics'),
                  subtitle: const Text('App-wide metrics'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/owner-analytics');
                  },
                ),
              ListTile(
                leading: const Icon(Icons.groups_rounded),
                title: const Text('My family'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FamilyManagementScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.card_giftcard_rounded),
                title: const Text('Invite & earn'),
                subtitle: const Text('Share your code, get free Premium'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const InviteAndEarnScreen(),
                    ),
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Family roster'),
              ),
              ...members.map(
                (m) => ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      m.displayName.isNotEmpty
                          ? m.displayName[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(m.displayName),
                  subtitle: Text(m.email),
                  trailing: const Chip(
                    label: Text('Member'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Explore'),
              ),
              ListTile(
                leading: const Icon(Icons.timeline),
                title: const Text('Memory timeline'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const TimelineScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_rounded),
                title: const Text('Calendar'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const CalendarScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Media vault'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const VaultScreen()),
                  );
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Plan together'),
              ),
              ListTile(
                leading: const Icon(Icons.checklist_rounded),
                title: const Text('Lists & meal planner'),
                subtitle: const Text('Shared grocery/to-do lists, weekly meals'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SharedListsHomeScreen(),
                    ),
                  );
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Play & points'),
              ),
              ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: const Text('Leaderboard'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const LeaderboardScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.sports_esports_outlined),
                title: const Text('Games'),
                subtitle: const Text('Predictions, reels, and more'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const GamesHubScreen()),
                  );
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Insights'),
              ),
              ListTile(
                leading: const Icon(Icons.insights_rounded),
                title: const Text('Mood insights'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MoodInsightsScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: const Text('Best moments'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BestMomentsScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.psychology_alt_rounded),
                title: const Text('Memories quiz'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const AiQuizScreen()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.poll_outlined),
                title: const Text('Family polls'),
                subtitle: const Text('Quick votes for the crew'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FamilyPollsScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: const Text('Send feedback'),
                subtitle: const Text('Opens your email app'),
                onTap: () async {
                  Navigator.pop(context);
                  final launched = await FeedbackLaunch.open(
                    body: 'FAM feedback (device / OS):\n\n',
                  );
                  if (!context.mounted) return;
                  if (!launched) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open email — add a mail app.'),
                      ),
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign out'),
                onTap: () async {
                  Navigator.pop(context);
                  await auth.signOut();
                },
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          FamilyFeedScreen(),
          DashboardScreen(),
          FamilyChatScreen(),
          DiaryFeedScreen(),
          TasksHomeScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed_rounded),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories_rounded),
            label: 'Diary',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_outlined),
            selectedIcon: Icon(Icons.task_alt_rounded),
            label: 'Tasks',
          ),
        ],
      ),
    );
  }
}
