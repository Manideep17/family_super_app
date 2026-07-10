import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Top-level background message handler. Must be a top-level function (not
/// a closure or class member) — Flutter spawns a fresh isolate to run it,
/// so we re-initialize Firebase before doing anything else.
///
/// On Android, when the message includes a `notification` payload, the
/// system shows the notification itself; we don't try to. We can use this
/// hook to update local caches / badges if we need to in the future.
@pragma('vm:entry-point')
Future<void> familyBackgroundMessageHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  if (kDebugMode) {
    debugPrint('FCM background message: ${message.messageId} '
        'data=${message.data}');
  }
}
