import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../../core/ai/family_digest_service.dart';
import '../../../../core/config/app_flags.dart';
import '../../../billing/presentation/providers/billing_providers.dart';
import '../../../billing/presentation/screens/paywall_screen.dart';
import '../../../calendar/presentation/providers/calendar_providers.dart';
import '../../../diary/presentation/providers/diary_providers.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../../../tasks/domain/entities/family_task.dart';
import '../../../tasks/presentation/providers/tasks_providers.dart';

/// Gemini-powered weekly recap — built on Firebase AI Logic's free Gemini
/// Developer API backend (no Blaze/billing needed, see
/// docs/AI_LOGIC_SETUP.md). Reads the same live data as the Home dashboard
/// (stories, tasks, upcoming events) and asks Gemini for a short, warm
/// summary instead of the family having to piece the week together
/// themselves.
class WeeklyDigestScreen extends ConsumerStatefulWidget {
  const WeeklyDigestScreen({super.key});

  @override
  ConsumerState<WeeklyDigestScreen> createState() => _WeeklyDigestScreenState();
}

class _WeeklyDigestScreenState extends ConsumerState<WeeklyDigestScreen> {
  final _service = FamilyDigestService();
  final _tts = FlutterTts();
  bool _loading = false;
  bool _speaking = false;
  String? _error;
  String? _digest;

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _speaking = false);
    });
    if (AppFlags.aiDigestEnabled && ref.read(isPremiumProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  /// Reads the digest aloud on-device — the "Sunday recap" ritual works
  /// even for family members who'd rather listen than read. Free, no
  /// server cost (see docs/PRODUCT_STRATEGY_AND_ENGAGEMENT.md, "one weekly
  /// ritual").
  Future<void> _togglePlayback() async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final text = _digest;
    if (text == null || text.isEmpty) return;
    setState(() => _speaking = true);
    final result = await _tts.speak(text);
    if (result != 1 && mounted) {
      setState(() => _speaking = false);
    }
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final stories = ref.read(storiesStreamProvider).value ?? const [];
      final storySnippets = stories
          .where((s) => s.createdAt.isAfter(weekAgo))
          .take(12)
          .map((s) {
            final body = s.body.trim();
            final snippet = body.length > 140 ? '${body.substring(0, 137)}...' : body;
            return '${s.authorName}: ${s.title.isNotEmpty ? s.title : snippet} (mood: ${s.mood})';
          })
          .toList();

      final tasks = ref.read(myTasksStreamProvider).value ?? const <FamilyTask>[];
      final completedTasks = tasks
          .where((t) =>
              t.status == TaskStatus.approved && t.createdAt.isAfter(weekAgo))
          .take(12)
          .map((t) => '${t.title} (${t.assigneeName})')
          .toList();

      final events = ref.read(calendarEventsProvider).value ?? const [];
      final upcoming = events
          .where((e) => e.startAt.isAfter(now))
          .take(6)
          .map((e) => e.title)
          .toList();

      final members = ref.read(familyMembersProvider).value ?? const [];
      final memberNames = members.map((m) => m.displayName).toList();

      final result = await _service.generateWeeklyDigest(
        storySnippets: storySnippets,
        completedTaskTitles: completedTasks,
        upcomingEventTitles: upcoming,
        memberNames: memberNames,
      );
      if (!mounted) return;
      setState(() => _digest = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly family digest')),
      body: !AppFlags.aiDigestEnabled
          ? _NotConfigured(scheme: scheme)
          : !isPremium
              ? _PremiumRequired(scheme: scheme)
              : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Couldn\'t generate a digest: $_error',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: scheme.error),
                                  ),
                                ),
                              )
                            : _digest == null
                                ? Center(
                                    child: Text(
                                      'Tap "Generate" to summarize this week.',
                                      style: TextStyle(color: scheme.onSurfaceVariant),
                                    ),
                                  )
                                : SingleChildScrollView(
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.auto_awesome_rounded,
                                                color: scheme.primary),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _digest!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(height: 1.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _generate,
                          icon: const Icon(Icons.refresh_rounded),
                          label:
                              Text(_digest == null ? 'Generate' : 'Regenerate'),
                        ),
                      ),
                      if (_digest != null) ...[
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _togglePlayback,
                          icon: Icon(
                            _speaking
                                ? Icons.stop_rounded
                                : Icons.volume_up_rounded,
                          ),
                          label: Text(_speaking ? 'Stop' : 'Play recap'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _PremiumRequired extends StatelessWidget {
  const _PremiumRequired({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Premium feature', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'The AI weekly digest is part of FAM Premium.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
              ),
              child: const Text('See Premium'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 56, color: scheme.outline),
            const SizedBox(height: 16),
            Text('AI digest is off in this build', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'This uses Firebase AI Logic\'s free Gemini Developer API — no '
              'billing needed, just a one-time setup in the Firebase console. '
              'See docs/AI_LOGIC_SETUP.md, then rebuild with '
              '--dart-define=AI_DIGEST_ENABLED=true.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
