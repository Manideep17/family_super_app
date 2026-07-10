import 'package:flutter/foundation.dart';

class SyncHealthSnapshot {
  const SyncHealthSnapshot({
    required this.state,
    this.message,
    this.at,
  });

  final String state;
  final String? message;
  final DateTime? at;
}

class SyncHealth {
  SyncHealth._();

  static final ValueNotifier<SyncHealthSnapshot> notifier = ValueNotifier(
    const SyncHealthSnapshot(state: 'idle'),
  );

  static void recordSuccess([String? message]) {
    notifier.value = SyncHealthSnapshot(
      state: 'healthy',
      message: message,
      at: DateTime.now(),
    );
  }

  static void recordError(Object error) {
    notifier.value = SyncHealthSnapshot(
      state: 'degraded',
      message: error.toString(),
      at: DateTime.now(),
    );
  }
}
