import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Shown once, before a person creates or joins their first family — states
/// the privacy promise out loud instead of leaving it in a footer link.
///
/// This is the differentiator most competitor family/location apps can't
/// copy without abandoning their own business model (many "free" family
/// apps monetize location or behavioral data) — see
/// docs/PRODUCT_STRATEGY_AND_ENGAGEMENT.md, "State the trust promise out
/// loud." Making it a real screen instead of a privacy-policy footnote is
/// the whole point.
class TrustPromiseScreen extends StatelessWidget {
  const TrustPromiseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AppGradient(
                        opacity: 0.85,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.verified_user_rounded,
                                  size: 40, color: scheme.primary),
                              const SizedBox(height: 14),
                              Text(
                                'Just for your family',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Before you start — a promise, not just a '
                                'privacy-policy footnote.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _PromiseRow(
                      icon: Icons.block_flipped,
                      title: 'No ads, ever',
                      body:
                          'Nothing in FAM is sponsored, and nothing here is '
                          'for sale to advertisers.',
                    ),
                    const _PromiseRow(
                      icon: Icons.lock_outline_rounded,
                      title: 'Private by default',
                      body:
                          'Chats, memories, photos, and games are only ever '
                          'visible to the members of your family group — '
                          'never to other families, never to us for '
                          'marketing.',
                    ),
                    const _PromiseRow(
                      icon: Icons.sell_outlined,
                      title: 'Your data is not sold',
                      body:
                          'What you share here stays here. It is not '
                          'packaged, profiled, or sold to third parties.',
                    ),
                    const _PromiseRow(
                      icon: Icons.delete_outline_rounded,
                      title: 'You can leave, cleanly',
                      body:
                          'Delete your account any time from your profile — '
                          'it actually deletes your data, not just hides it.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it — let\'s go'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromiseRow extends StatelessWidget {
  const _PromiseRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer),
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
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
