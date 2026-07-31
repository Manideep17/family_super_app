import 'dart:async';

Future<T> withRetry<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration baseDelay = const Duration(milliseconds: 350),
  Duration? timeout,
  bool Function(Object error)? shouldRetry,
}) async {
  Object? lastError;
  StackTrace? lastStack;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      final future = operation();
      if (timeout != null) {
        return await future.timeout(timeout);
      }
      return await future;
    } catch (e, st) {
      lastError = e;
      lastStack = st;
      final retryable = shouldRetry?.call(e) ?? true;
      if (!retryable || attempt == maxAttempts) rethrow;
      final backoff = Duration(
        milliseconds: baseDelay.inMilliseconds * attempt,
      );
      await Future<void>.delayed(backoff);
    }
  }
  Error.throwWithStackTrace(
    StateError('Retry loop ended unexpectedly: $lastError'),
    lastStack ?? StackTrace.current,
  );
}

/// Re-creates the stream from [streamFactory] whenever it errors, instead of
/// leaving a single early error permanently stuck.
///
/// Why this exists: right after a fresh sign-in (or a cold app start that
/// restores a cached session), there's a brief window where
/// `FirebaseAuth.instance.currentUser` is already non-null but the ID token
/// hasn't yet propagated to Firestore's own listener registration. A
/// `.snapshots()` subscription opened in that window can get a one-time
/// `permission-denied` — and unlike transient network errors, the Firestore
/// SDK does **not** auto-retry `permission-denied` internally, so that
/// subscription is dead forever. Any provider built directly on that stream
/// (family id, family doc, member docs, ...) then stays in an error state
/// until the whole app process restarts and opens a brand-new listener
/// after the token is in place. This wraps the same symptom users see as
/// "Could not load your family data" right after signing in, fixed by
/// force-closing and reopening the app.
///
/// [streamFactory] is called again (fresh subscription, fresh token by
/// then) after a short backoff on every error until [maxAttempts] is
/// reached, at which point the error is finally forwarded downstream.
Stream<T> retryStream<T>(
  Stream<T> Function() streamFactory, {
  int maxAttempts = 5,
  Duration baseDelay = const Duration(milliseconds: 500),
}) {
  late StreamController<T> controller;
  StreamSubscription<T>? sub;
  var attempt = 0;

  void startListen() {
    attempt++;
    sub = streamFactory().listen(
      controller.add,
      onError: (Object e, StackTrace st) {
        if (attempt >= maxAttempts) {
          controller.addError(e, st);
          return;
        }
        final delay = Duration(milliseconds: baseDelay.inMilliseconds * attempt);
        Future<void>.delayed(delay, () {
          if (!controller.isClosed) startListen();
        });
      },
      onDone: controller.close,
    );
  }

  controller = StreamController<T>(
    onListen: () {
      attempt = 0;
      startListen();
    },
    onCancel: () => sub?.cancel(),
  );
  return controller.stream;
}
