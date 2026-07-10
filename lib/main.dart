import 'dart:async';
import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/deep_link/deep_link_bootstrap.dart';
import 'core/fcm/fcm_bootstrap.dart';
import 'core/firebase/firebase_bootstrap.dart';

/// Entry point. We always reach [runApp] — even if Firebase init fails — so
/// the user sees real UI (or a recoverable error screen) instead of the bare
/// native launch background.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeepLinkBootstrap.init();
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return _RecoverableErrorView(details: details);
  };

  Object? bootError;
  StackTrace? bootStack;
  try {
    await FirebaseBootstrap.init();
    await _configureCrashReporting();
  } catch (e, st) {
    bootError = e;
    bootStack = st;
    if (kDebugMode) {
      debugPrint('FirebaseBootstrap.init failed: $e\n$st');
    }
  }

  // Run FCM setup off the critical path; it must never block first frame.
  unawaited(FcmBootstrap.init());

  runZonedGuarded(() {
    runApp(
      ProviderScope(
        child: bootError == null
            ? const FamilySuperApp()
            : _BootErrorApp(error: bootError, stack: bootStack),
      ),
    );
  }, (error, stack) {
    if (kDebugMode) {
      debugPrint('Uncaught zone error: $error\n$stack');
    }
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: true,
      reason: 'runZonedGuarded uncaught error',
    );
  });
}

Future<void> _configureCrashReporting() async {
  const enabled = !kDebugMode;
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: true,
      reason: 'PlatformDispatcher uncaught error',
    );
    return true;
  };
}

class _BootErrorApp extends StatelessWidget {
  const _BootErrorApp({required this.error, this.stack});

  final Object error;
  final StackTrace? stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Couldn’t start Firebase',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The app started but Firebase failed to initialize. '
                  'Check google-services.json and lib/firebase_options.dart.',
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText('$error\n\n${stack ?? ''}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecoverableErrorView extends StatelessWidget {
  const _RecoverableErrorView({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 44),
                  const SizedBox(height: 8),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try navigating back or reopening this screen. '
                    'If this keeps happening, restart the app.',
                    textAlign: TextAlign.center,
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 12),
                    SelectableText(
                      '${details.exceptionAsString()}\n${details.stack ?? ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
