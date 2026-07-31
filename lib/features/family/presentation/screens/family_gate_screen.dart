import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/owner/owner_analytics_emails.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/family_providers.dart';
import 'create_family_screen.dart';
import 'join_family_screen.dart';
import 'trust_promise_screen.dart';

/// Shown after sign-in when the user has no familyId yet. Lets them either
/// create a brand-new family or join an existing one with an invite code.
class FamilyGateScreen extends ConsumerStatefulWidget {
  const FamilyGateScreen({super.key});

  @override
  ConsumerState<FamilyGateScreen> createState() => _FamilyGateScreenState();
}

class _FamilyGateScreenState extends ConsumerState<FamilyGateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOnboarding());
  }

  /// Trust screen first (one-time), then the existing welcome tips dialog —
  /// both gated on their own SharedPreferences flag so returning users never
  /// see either again.
  ///
  /// Both also re-check `currentFamilyIdProvider` right before showing:
  /// this screen pushes them imperatively on top of `/onboarding` while
  /// go_router's own redirect (app_router.dart) is *reactively* watching
  /// familyId and will swap to `/home` the instant it becomes non-empty
  /// (e.g. another device finishing a join for this same account). Mixing
  /// imperative pushes with a declarative redirect underneath them can't be
  /// fully race-proof, but skipping the push entirely once we already have
  /// a family closes the common case.
  Future<void> _maybeShowOnboarding() async {
    await _maybeShowTrustPromise();
    if (!mounted) return;
    await _maybeShowWelcome();
  }

  bool get _alreadyHasFamily =>
      (ref.read(currentFamilyIdProvider).valueOrNull ?? '').isNotEmpty;

  Future<void> _maybeShowTrustPromise() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _alreadyHasFamily) return;
    if (prefs.getBool('fam_trust_promise_v1') == true) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TrustPromiseScreen(),
        fullscreenDialog: true,
      ),
    );
    if (!mounted) return;
    await prefs.setBool('fam_trust_promise_v1', true);
  }

  Future<void> _maybeShowWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _alreadyHasFamily) return;
    if (prefs.getBool('fam_gate_tips_v1') == true) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Welcome to FAM'),
        content: const Text(
          'You can start a brand-new family and invite others with a short '
          'code — or join someone else’s family if they already sent you a '
          'code.\n\nEverything in a family (chat, diary, tasks) stays private '
          'to that family.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await prefs.setBool('fam_gate_tips_v1', true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authRepositoryProvider);
    final showOwnerEntry =
        isOwnerAnalyticsEmail(auth.currentUserEmail);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async => auth.signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (_showEmailVerifyBanner())
            Card(
              color: scheme.secondaryContainer,
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify your email',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Check your inbox for the link from Firebase. Verified '
                      'email helps with account recovery.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () async {
                        try {
                          await ref
                              .read(authRepositoryProvider)
                              .sendEmailVerification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Verification email sent.'),
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
                      child: const Text('Resend verification email'),
                    ),
                  ],
                ),
              ),
            ),
          if (showOwnerEntry) ...[
            Card(
              child: ListTile(
                leading: Icon(Icons.analytics_outlined, color: scheme.primary),
                title: const Text('Owner analytics'),
                subtitle: const Text(
                  'View app-wide metrics without joining a family.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.go('/owner-analytics'),
              ),
            ),
            const SizedBox(height: 14),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AppGradient(
              opacity: 0.85,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.favorite_rounded,
                        size: 36, color: scheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Hi ${auth.currentUserEmail ?? 'there'} 👋',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Each family on this app is its own private space. '
                      'Start a new one — or join the family that already '
                      'invited you.',
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 320.ms),
          const SizedBox(height: 18),
          _OptionCard(
            icon: Icons.add_home_rounded,
            color: scheme.primary,
            title: 'Create a family',
            subtitle: 'Pick a name and we\'ll generate a 6-char invite code.',
            actionLabel: 'Create',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CreateFamilyScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            icon: Icons.key_rounded,
            color: scheme.tertiary,
            title: 'Join a family',
            subtitle:
                'Got an invite code? Pop it in and pick how you want to be greeted.',
            actionLabel: 'Join',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const JoinFamilyScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Privacy: only members of a family can see that family\'s chats, '
            'memories, photos, and games.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

bool _showEmailVerifyBanner() {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null || u.emailVerified) return false;
  return u.providerData.any((p) => p.providerId == 'password');
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: color.withValues(alpha: 0.16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onTap,
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
