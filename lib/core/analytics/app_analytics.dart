import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AppAnalytics {
  AppAnalytics._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> logEvent(
    String name, {
    Map<String, Object>? params,
  }) async {
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Analytics logEvent failed for $name: $e');
      }
    }
  }
}
