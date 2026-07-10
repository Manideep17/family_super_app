import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'dart:async';

import '../config/app_flags.dart';
import '../router/app_link.dart';
import 'fcm_background.dart';

/// One-stop FCM wiring:
///
/// * Requests notification permission.
/// * Registers the device's FCM token (and refreshes) on `users/{uid}`.
/// * Creates the `family_default` Android channel that Cloud Functions push
///   to (see `functions/src/push.ts`).
/// * Subscribes to foreground / background / cold-start notifications and
///   routes taps via [AppLink].
class FcmBootstrap {
  FcmBootstrap._();

  static const _channel = AndroidNotificationChannel(
    'family_default',
    'Family activity',
    description: 'Chats, tasks, memories, and game updates from your family',
    importance: Importance.high,
  );

  static final _local = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static StreamSubscription<User?>? _authSub;
  static bool _oneSignalInitDone = false;

  static Future<void> init() async {
    if (Firebase.apps.isEmpty) return;
    if (_initialized) return;
    _initialized = true;

    try {
      // Background handler must be set before any other listener so messages
      // received while the app isn't alive are correctly routed.
      FirebaseMessaging.onBackgroundMessage(familyBackgroundMessageHandler);

      await _initLocalNotifications();

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      await _initOneSignal();

      // Some devices/emulators (no Play Services, throttled FCM) leave
      // `getToken` hanging forever — never let that block app start.
      final token = await messaging
          .getToken()
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      await _persistToken(token);
      await _persistOneSignalSubscription();

      messaging.onTokenRefresh.listen(_persistToken);
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
      _authSub?.cancel();
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user == null) return;
        unawaited(syncForCurrentUser());
      });

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _routeFromMessage(initial);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FcmBootstrap.init failed: $e\n$st');
      }
    }
  }

  /// Forces token + OneSignal persistence for the currently signed-in user.
  ///
  /// Useful right after login because app startup init may run before auth.
  static Future<void> syncForCurrentUser() async {
    if (Firebase.apps.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      await _persistToken(token);
      await _initOneSignal();
      await _persistOneSignalSubscription();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FcmBootstrap.syncForCurrentUser failed: $e\n$st');
      }
    }
  }

  static Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload != null && payload.isNotEmpty) {
          AppLink.go(payload);
        }
      },
    );
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await android?.requestNotificationsPermission();
  }

  static Future<void> _persistToken(String? token) async {
    if (token == null || token.isEmpty) return;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    await FirebaseFirestore.instance.collection('users').doc(u.uid).set(
      {
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> _initOneSignal() async {
    if (AppFlags.oneSignalAppId.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!_oneSignalInitDone) {
      OneSignal.initialize(AppFlags.oneSignalAppId);
      OneSignal.Notifications.requestPermission(true);
      _oneSignalInitDone = true;
    }
    OneSignal.login(user.uid);
    await _persistOneSignalSubscription();
    OneSignal.User.pushSubscription.addObserver((_) {
      _persistOneSignalSubscription();
    });
  }

  static Future<void> _persistOneSignalSubscription() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final subId = OneSignal.User.pushSubscription.id;
    final token = OneSignal.User.pushSubscription.token;
    if (subId == null || subId.isEmpty) return;
    final users = FirebaseFirestore.instance.collection('users');
    final families = FirebaseFirestore.instance.collection('families');
    await users.doc(u.uid).set(
      {
        'onesignalSubscriptionId': subId,
        'onesignalToken': token,
        'onesignalUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    final userDoc = await users.doc(u.uid).get();
    final fid = userDoc.data()?['familyId']?.toString() ?? '';
    if (fid.isEmpty) return;
    await families.doc(fid).collection('members').doc(u.uid).set(
      {
        'onesignalSubscriptionId': subId,
        'onesignalUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    final route = message.data['route']?.toString();
    _local.show(
      message.messageId.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: route,
    );
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    _routeFromMessage(message);
  }

  static void _routeFromMessage(RemoteMessage message) {
    final route = message.data['route']?.toString();
    if (route == null || route.isEmpty) return;
    AppLink.go(route);
  }
}
