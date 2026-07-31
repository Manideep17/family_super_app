import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/family_providers.dart';

/// Create a family, then invite members using the join code.
class CreateFamilyScreen extends ConsumerStatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  ConsumerState<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends ConsumerState<CreateFamilyScreen> {
  final _name = TextEditingController(text: 'Our Family');
  final _displayName = TextEditingController();
  final _greeting = TextEditingController(text: '');
  final _referralCode = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _displayName.dispose();
    _greeting.dispose();
    _referralCode.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final displayName = _displayName.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a family name to continue.');
      return;
    }
    if (displayName.isEmpty) {
      setState(() => _error = 'Enter your display name to continue.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final familyId = await ref.read(familyRepositoryProvider).createFamily(
            name: name,
            displayName: displayName,
            greeting: _greeting.text,
          );
      // Best-effort, never blocks family creation: a typo'd or already-used
      // referral code shouldn't stop someone from finishing onboarding.
      final referral = _referralCode.text.trim();
      if (referral.isNotEmpty) {
        try {
          await ref.read(familyRepositoryProvider).redeemReferralCode(
                familyId: familyId,
                referralCode: referral,
              );
        } catch (_) {
          // Silently skipped — the "Invite & earn" screen lets them retry.
        }
      }
      if (mounted) {
        // Router auto-redirects to /home as soon as familyId appears.
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    if (raw.contains('already belong to a family')) {
      return 'This account is already linked to a family. Leave that family first, then try again.';
    }
    if (raw.contains('Account is missing an email')) {
      return 'Your account is missing an email address. Please sign in again with an email-based account.';
    }
    if (raw.contains('Pick a family name')) {
      return 'Enter a family name to continue.';
    }
    if (raw.contains('Add your display name')) {
      return 'Enter your display name to continue.';
    }
    return 'Could not create family right now. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create your family')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Family details',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Family name',
              prefixIcon: Icon(Icons.home_rounded),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.group_outlined),
            title: Text('Open membership'),
            subtitle: Text(
              'Anyone with your invite code can join this family.',
            ),
          ),
          const Divider(height: 32),
          Text(
            'You',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _displayName,
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: 'Alex · Sam · Jordan',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _greeting,
            decoration: const InputDecoration(
              labelText: 'Greeting on your dashboard (optional)',
              hintText: 'Hey rockstar · Welcome home · Yo Captain',
              prefixIcon: Icon(Icons.waving_hand_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 6),
          Text(
            'This is what your home screen will say when you open the app. '
            'Leave blank for a time-aware "Good morning".',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const Divider(height: 32),
          TextField(
            controller: _referralCode,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(letterSpacing: 4),
            decoration: const InputDecoration(
              labelText: 'Referral code (optional)',
              hintText: 'ABC123',
              prefixIcon: Icon(Icons.card_giftcard_outlined),
              counterText: '',
            ),
          ),
          Text(
            'Got invited by another family? Add their code and you both get '
            'a week of Premium free.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: scheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _create,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Create family'),
          ),
        ],
      ),
    );
  }
}
