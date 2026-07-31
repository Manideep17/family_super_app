package com.family.superapp

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Small home-screen widget: shows the family name and the signed-in
 * member's open-task count, synced from Flutter whenever tasks or the
 * family doc change (see lib/core/widget/home_widget_sync.dart, which
 * calls `HomeWidget.saveWidgetData` + `HomeWidget.updateWidget`). Tapping
 * the widget opens the app.
 *
 * This is the one file in the July/August 2026 build batch that could not
 * be compiled or tested in the sandbox that authored it (no Android SDK
 * or Gradle available there) -- the first real check is the next "Build
 * APK" GitHub Actions run. If that run fails specifically on this file,
 * the error will point at exactly what's wrong (most likely the
 * `es.antonborri.home_widget` package name, if the `home_widget` plugin
 * ever renamed its Android namespace).
 */
class FamWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.fam_widget_layout)

            val familyName = widgetData.getString("family_name", null) ?: "FAM"
            val openTasks = widgetData.getInt("open_task_count", 0)
            val summary = when {
                openTasks <= 0 -> "All caught up 🎉"
                openTasks == 1 -> "1 open task"
                else -> "$openTasks open tasks"
            }

            views.setTextViewText(R.id.fam_widget_title, familyName)
            views.setTextViewText(R.id.fam_widget_subtitle, summary)

            // Plain launch-the-app PendingIntent -- deliberately not using
            // any home_widget click-handling helper, to keep this file's
            // one real dependency on the plugin limited to the
            // HomeWidgetProvider base class + widgetData param above.
            val launchIntent =
                context.packageManager.getLaunchIntentForPackage(context.packageName)
                    ?: Intent(context, MainActivity::class.java)
            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.fam_widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
