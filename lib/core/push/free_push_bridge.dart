import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../config/app_flags.dart';
import '../network/retry.dart';
import '../network/sync_health.dart';

class FreePushBridge {
  FreePushBridge._();

  static final _client = http.Client();

  static bool get isEnabled => AppFlags.pushBridgeConfigured;

  static Future<void> notifyFamily({
    required String familyId,
    required String title,
    required String body,
    required String route,
    String? actorUid,
    Map<String, dynamic> extraData = const {},
  }) async {
    if (!isEnabled) return;
    final memberSnap = await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('members')
        .get();
    final targets = <String>[];
    for (final doc in memberSnap.docs) {
      if (actorUid != null && doc.id == actorUid) continue;
      final id = doc.data()['onesignalSubscriptionId']?.toString() ?? '';
      if (id.isNotEmpty) targets.add(id);
    }
    if (targets.isEmpty) return;

    final payload = <String, dynamic>{
      'appId': AppFlags.oneSignalAppId,
      'subscriptionIds': targets,
      'title': title,
      'body': body,
      'data': <String, dynamic>{'route': route, ...extraData},
    };

    try {
      final res = await withRetry(
        () => _client.post(
          Uri.parse(AppFlags.pushWorkerEndpoint),
          headers: {
            'content-type': 'application/json',
            'x-worker-key': AppFlags.pushWorkerKey,
          },
          body: jsonEncode(payload),
        ),
        timeout: const Duration(seconds: 12),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw StateError('Push bridge failed (${res.statusCode}): ${res.body}');
      }
      SyncHealth.recordSuccess('Push dispatched');
    } catch (e) {
      SyncHealth.recordError(e);
      rethrow;
    }
  }
}
