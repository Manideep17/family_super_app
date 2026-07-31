import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Pushes fresh data to the Android home-screen widget (FamWidgetProvider,
/// see android/app/src/main/kotlin/.../FamWidgetProvider.kt). Best-effort
/// everywhere — a widget-sync failure must never surface to the user or
/// affect the rest of the app.
class HomeWidgetSync {
  HomeWidgetSync._();

  static const _androidProviderName = 'FamWidgetProvider';

  static Future<void> sync({
    required String familyName,
    required int openTaskCount,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('family_name', familyName);
      await HomeWidget.saveWidgetData<int>('open_task_count', openTaskCount);
      await HomeWidget.updateWidget(androidName: _androidProviderName);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HomeWidgetSync.sync failed: $e');
      }
    }
  }
}
