import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Single point of entry to navigate the app from outside the widget tree
/// (push notification taps, deep links, etc.). The router instance is
/// populated by [FamilySuperApp] on first build.
///
/// Calls to [go] before the router is attached are queued and replayed on
/// attach — this matters for cold-start FCM taps where
/// [FirebaseMessaging.getInitialMessage] can resolve before the first frame.
class AppLink {
  AppLink._();

  static GoRouter? _router;
  static String? _pending;

  static void attach(GoRouter router) {
    _router = router;
    final p = _pending;
    if (p != null) {
      _pending = null;
      // Defer to the next microtask so the router has finished its initial
      // routing before we override.
      Future.microtask(() => router.go(p));
    }
  }

  static void detach(GoRouter router) {
    if (identical(_router, router)) _router = null;
  }

  /// Navigate to [path]. If the router isn't attached yet, the most recent
  /// pending path is remembered and replayed on attach.
  static void go(String path) {
    final r = _router;
    if (r == null) {
      _pending = path;
      if (kDebugMode) {
        debugPrint('AppLink.go($path) queued — router not attached yet');
      }
      return;
    }
    r.go(path);
  }
}
