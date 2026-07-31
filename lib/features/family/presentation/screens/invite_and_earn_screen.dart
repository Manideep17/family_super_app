import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/analytics/app_analytics.dart';
import '../providers/family_providers.dart';

/// Referral / growth loop: share your family's code, or redeem someone
/// else's — both sides get a free premium bonus. See
/// functions/src/referrals.ts for the server-side rules.
class InviteAndEarnScreen extends ConsumerStatefulWidget {
  const InviteAndEarnScreen({super.key});

  @override
  ConsumerState<InviteAndEarnScreen> createState() =>
      _InviteAndEarnScreenState();
}

class _InviteAndEarnScreenState extends ConsumerState<InviteAndEarnScreen> {
  final _redeemCtrl = TextEditingController();
  bool _allocating = false;
  bool _redeeming = false;
  String? _redeemError;

  @override
  void dispose() {
    _redeemCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureCode(String familyId) async {
    if (_allocating) return;
    setState(() => _allocating = true);
    try {
      await ref.read(familyRepositoryProvider).allocateMyReferralCode(familyId);
    } catch (_) {
      // Silent — the button below just won't have a code to share yet;
      // the user can retry by reopening this screen.
    } finally {
      if (mounted) setState(() => _allocating = false);
    }
  }

  Future<void> _share(String code) async {
    AppAnalytics.logEvent('referral_code_shared');
    await SharePlus.instance.share(
      ShareParams(
        text: 'Join me on FAM, our family\'s private app! Use my invite '
            'code $code when you set up your own family and we both get a '
            'week of Premium free 🎉',
      ),
    );
  }

  Future<void> _redeem(String familyId) async {
    final code = _redeemCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _redeemError = 'Enter the 6-character code.');
      return;
    }
    setState(() {
      _redeeming = true;
      _redeemError = null;
    });
    try {
      await ref.read(familyRepositoryProvider).redeemReferralCode(
            familyId: familyId,
            referralCode: code,
          );
      AppAnalytics.logEvent('referral_code_redeemed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code redeemed — enjoy a week of Premium!'),
          ),
        );
        _redeemCtrl.clear();
      }
    } catch (e) {
      setState(() => _redeemError = '$e');
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final familyAsync = ref.watch(currentFamilyProvider);
    final family = familyAsync.valueOrNull;

    if (family == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (family.referralCode.isEmpty && !_allocating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureCode(family.id);
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Invite & earn')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your invite code',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share it with another family — when they use it while '
                    'setting up FAM, you both get a week of Premium free.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  if (family.referralCode.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    Center(
                      child: Text(
                        family.referralCode,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _share(family.referralCode),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share invite'),
                    ),
                  ],
                  if (family.referralCount > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${family.referralCount} famil${family.referralCount == 1 ? 'y has' : 'ies have'} joined using your code 🎉',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  if (family.hasActiveReferralBonus) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.workspace_premium_rounded,
                              color: scheme.onTertiaryContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Referral Premium bonus active until '
                              '${DateFormat.yMMMd().format(family.referralBonusExpiresAt!)}',
                              style: TextStyle(
                                  color: scheme.onTertiaryContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Got a code from someone else?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  if (family.referredByFamilyId.isNotEmpty)
                    Text(
                      'This family already redeemed a referral code.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    )
                  else ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _redeemCtrl,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      style: const TextStyle(letterSpacing: 4, fontSize: 20),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Their invite code',
                        hintText: 'ABC123',
                        counterText: '',
                      ),
                    ),
                    if (_redeemError != null) ...[
                      const SizedBox(height: 8),
                      Text(_redeemError!, style: TextStyle(color: scheme.error)),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _redeeming ? null : () => _redeem(family.id),
                      icon: _redeeming
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.redeem_rounded),
                      label: const Text('Redeem'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
