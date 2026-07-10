import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../../data/auth_repository_impl.dart';

/// Email + password and Google sign-in. New users land here, then on
/// [FamilyGateScreen] to create or join a family.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _loading = false;
  bool _registering = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _emailSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      if (_registering) {
        await auth.registerWithEmail(
          email: _email.text,
          password: _password.text,
        );
      } else {
        await auth.signInWithEmail(
          email: _email.text,
          password: _password.text,
        );
      }
    } on FamilyAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on FamilyAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _humanize(Object e) {
    final s = e.toString();
    if (s.contains('user-not-found')) return 'No account for that email.';
    if (s.contains('wrong-password')) return 'Wrong password.';
    if (s.contains('email-already-in-use')) {
      return 'That email already has an account — try signing in.';
    }
    if (s.contains('weak-password')) return 'Pick a longer password.';
    if (s.contains('invalid-email')) return 'That email looks malformed.';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.38),
              scheme.secondaryContainer.withValues(alpha: 0.42),
              scheme.tertiaryContainer.withValues(alpha: 0.32),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FamWordmark(scheme: scheme)
                        .animate()
                        .fadeIn(duration: 450.ms)
                        .scale(begin: const Offset(0.92, 0.92)),
                    const SizedBox(height: 20),
                    Text(
                      _registering
                          ? 'Create an account, then start your space.'
                          : 'Welcome back',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Sign in'),
                          icon: Icon(Icons.login_rounded),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Create account'),
                          icon: Icon(Icons.person_add_outlined),
                        ),
                      ],
                      selected: {_registering},
                      onSelectionChanged: (s) {
                        if (_loading) return;
                        setState(() {
                          _registering = s.first;
                          _error = null;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter email';
                        if (!v.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter password';
                        if (v.length < 6) return 'At least 6 characters';
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: scheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (!_registering) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading
                              ? null
                              : () async {
                                  final email = _email.text.trim();
                                  if (email.isEmpty) {
                                    setState(() => _error =
                                        'Enter your email, then tap Forgot password.');
                                    return;
                                  }
                                  setState(() {
                                    _loading = true;
                                    _error = null;
                                  });
                                  try {
                                    await ref
                                        .read(authRepositoryProvider)
                                        .sendPasswordResetEmail(email);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'If that email is registered, a reset link is on the way.',
                                        ),
                                      ),
                                    );
                                  } on FamilyAuthException catch (e) {
                                    setState(() => _error = e.message);
                                  } catch (e) {
                                    setState(() => _error = _humanize(e));
                                  } finally {
                                    if (mounted) {
                                      setState(() => _loading = false);
                                    }
                                  }
                                },
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _emailSubmit,
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_registering ? 'Create account' : 'Sign in'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _googleSignIn,
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('Continue with Google'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Each family is private — after sign-in you can either '
                      'create your own family or join one with a 6-character '
                      'invite code.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FamWordmark extends StatelessWidget {
  const _FamWordmark({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final display = Theme.of(context).textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 6,
          height: 1,
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface.withValues(alpha: 0.75),
            scheme.primaryContainer.withValues(alpha: 0.45),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.tertiary, 0.55)!,
          ],
        ).createShader(bounds),
        child: Text('FAM', style: display),
      ),
    );
  }
}
