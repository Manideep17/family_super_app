import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rxdart/rxdart.dart';

import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../core/owner/owner_analytics_emails.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/family/presentation/screens/family_gate_screen.dart';
import '../../features/home/presentation/screens/home_shell_screen.dart';
import '../../features/owner_analytics/presentation/screens/owner_analytics_screen.dart';
import 'go_router_refresh.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

/// Streams `users/{uid}.familyId` so the router can react when the current
/// user creates / joins / leaves a family without a manual reload.
final _routerFamilyIdProvider = StreamProvider<String?>((ref) {
  final authStream = FirebaseAuth.instance.authStateChanges();
  return authStream.asyncExpand((user) {
    if (user == null) return Stream.value(null);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snap) {
      final fid = snap.data()?['familyId'];
      return fid is String && fid.isNotEmpty ? fid : null;
    });
  });
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  // Eagerly subscribe so `_routerFamilyIdProvider` is always live for the
  // synchronous read inside `redirect`.
  ref.listen<AsyncValue<String?>>(
    _routerFamilyIdProvider,
    (_, __) {},
    fireImmediately: true,
  );

  // Refresh on EITHER auth change OR familyId change.
  final familyChangeController = StreamController<Object?>.broadcast();
  final familySub = FirebaseAuth.instance.authStateChanges().asyncExpand((u) {
    if (u == null) return Stream<Object?>.value(null);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .snapshots()
        .map<Object?>((s) => s.data()?['familyId']);
  }).listen(familyChangeController.add);
  final mergedStream = MergeStream<dynamic>([
    auth.authStateChanges(),
    familyChangeController.stream,
  ]);
  final refresh = GoRouterRefreshStream(mergedStream);
  ref.onDispose(() {
    familySub.cancel();
    familyChangeController.close();
    refresh.dispose();
  });

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final loc = state.matchedLocation;
      final isLogin = loc == '/login';
      final isOnboarding = loc == '/onboarding';
      final isRouterError = loc == '/router-error';
      final isOwnerAnalyticsRoute = loc == '/owner-analytics';

      if (user == null) {
        return isLogin ? null : '/login';
      }

      final isOwner = isOwnerAnalyticsEmail(user.email);

      // Signed in: read familyId synchronously off the cached router stream.
      final fidAsync = ref.read(_routerFamilyIdProvider);
      final fid = fidAsync.valueOrNull;
      final isLoading = fidAsync.isLoading && !fidAsync.hasValue;
      final hasStreamError = fidAsync.hasError;

      if (isLoading) {
        // Stay where we are until the family stream emits its first value;
        // this avoids a flash of the gate when the user is already in a
        // family.
        return null;
      }
      if (hasStreamError) {
        return isRouterError ? null : '/router-error';
      }

      final hasFamily = fid != null && fid.isNotEmpty;

      if (isOwnerAnalyticsRoute && !isOwner) {
        return hasFamily ? '/home' : '/onboarding';
      }

      if (!hasFamily) {
        if (isOwner) {
          if (isOnboarding || isOwnerAnalyticsRoute) return null;
          return '/owner-analytics';
        }
        return isOnboarding ? null : '/onboarding';
      }

      if (isLogin || isOnboarding || isRouterError) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const FamilyGateScreen(),
      ),
      GoRoute(
        path: '/owner-analytics',
        builder: (context, state) => const OwnerAnalyticsScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeShellScreen(),
      ),
      GoRoute(
        path: '/router-error',
        builder: (context, state) => const _RouterErrorScreen(),
      ),
    ],
  );
});

class _RouterErrorScreen extends StatelessWidget {
  const _RouterErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 56),
                const SizedBox(height: 12),
                const Text(
                  'Could not load your family data.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your connection and try again. '
                  'If this continues, sign out and sign back in.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => GoRouter.of(context).go('/home'),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
