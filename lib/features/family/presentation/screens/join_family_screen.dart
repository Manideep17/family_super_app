import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/family_providers.dart';

class JoinFamilyScreen extends ConsumerStatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  ConsumerState<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends ConsumerState<JoinFamilyScreen> {
  final _code = TextEditingController();
  final _displayName = TextEditingController();
  final _greeting = TextEditingController(text: '');
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyPendingCode());
  }

  Future<void> _applyPendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('pending_join_code');
    if (raw == null || raw.length != 6) return;
    await prefs.remove('pending_join_code');
    if (!mounted) return;
    setState(() => _code.text = raw.toUpperCase());
  }

  @override
  void dispose() {
    _code.dispose();
    _displayName.dispose();
    _greeting.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final normalizedCode = _code.text.trim().toUpperCase();
    final displayName = _displayName.text.trim();
    if (normalizedCode.length != 6) {
      setState(() => _error = 'Invite code must be exactly 6 characters.');
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
      await ref.read(familyRepositoryProvider).joinFamily(
            joinCode: normalizedCode,
            displayName: displayName,
            greeting: _greeting.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    if (raw.contains('No family found for that code')) {
      return 'No family was found for that code. Check the code and try again.';
    }
    if (raw.contains('already belong to a family')) {
      return 'This account is already linked to a family. Leave that family first, then try again.';
    }
    if (raw.contains('Invite codes are 6 characters')) {
      return 'Invite code must be exactly 6 characters.';
    }
    if (raw.contains('Add your display name')) {
      return 'Enter your display name to continue.';
    }
    if (raw.contains('Account is missing an email')) {
      return 'Your account is missing an email address. Please sign in again with an email-based account.';
    }
    return 'Could not join family right now. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Join a family')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(letterSpacing: 4, fontSize: 22),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'Invite code',
              hintText: 'ABC123',
              counterText: '',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ask the person who set up your family for the 6-character invite '
            'code. They can find it in the "My family" drawer entry.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const Divider(height: 32),
          Text('You', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          TextField(
            controller: _displayName,
            decoration: const InputDecoration(
              labelText: 'Display name',
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
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: scheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _join,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login_rounded),
            label: const Text('Join family'),
          ),
        ],
      ),
    );
  }
}
