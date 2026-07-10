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
