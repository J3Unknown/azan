package com.unknown.azan

import android.appwidget.AppWidgetManager
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.ComponentName
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar
import java.util.Locale
import java.text.SimpleDateFormat

class PrayerTimesWidgetProvider : HomeWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in listOf(
                ACTION_REFRESH,
                Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED,
                AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED,
            )) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, javaClass))
            if (ids.isNotEmpty()) onUpdate(context, manager, ids)
        }
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = refreshIntent(context, PendingIntent.FLAG_NO_CREATE)
        if (pending != null) {
            alarmManager.cancel(pending)
            pending.cancel()
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        try {
            updateWidgets(context, appWidgetManager, appWidgetIds, widgetData)
        } catch (error: Exception) {
            Log.e(TAG, "Unable to update prayer times widget", error)
            appWidgetIds.forEach { appWidgetId ->
                runCatching {
                    val views = RemoteViews(context.packageName, R.layout.prayer_times_widget)
                    val arabic = widgetData.getString("app_language", "en") == "ar"
                    views.setTextViewText(
                        R.id.next_prayer,
                        if (arabic) "مواقيت الصلاة غير متاحة" else "Prayer times unavailable",
                    )
                    views.setTextViewText(
                        R.id.countdown,
                        if (arabic) "افتح أذان للتحديث" else "Open Azan to refresh",
                    )
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }.onFailure { fallbackError ->
                    Log.e(TAG, "Unable to show prayer times widget fallback", fallbackError)
                }
            }
        }
    }

    private fun updateWidgets(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = System.currentTimeMillis()
        val arabic = widgetData.getString("app_language", "en") == "ar"
        val displayLocale = if (arabic) Locale("ar") else Locale.getDefault()
        val today = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val prayerNames = listOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")
        val prayers = prayerNames.mapIndexed { index, name ->
            val prayerId = index + 1
            PrayerTime(
                name = name,
                hour = widgetData.getInt("prayer_${prayerId}_hour", -1),
                minute = widgetData.getInt("prayer_${prayerId}_minute", -1),
            )
        }

        val upcoming = prayers.mapNotNull { prayer ->
            if (prayer.hour !in 0..23 || prayer.minute !in 0..59) return@mapNotNull null
            val time = (today.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, prayer.hour)
                set(Calendar.MINUTE, prayer.minute)
            }.timeInMillis
            if (time > now) prayer to time else null
        }.firstOrNull()
        val tomorrowFajr = prayers.firstOrNull {
            it.name == "Fajr" && it.hour in 0..23 && it.minute in 0..59
        }?.let { fajr ->
            val time = (today.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, fajr.hour)
                set(Calendar.MINUTE, fajr.minute)
            }.timeInMillis
            fajr to time
        }

        val nextPrayer = upcoming?.first ?: tomorrowFajr?.first
        val nextPrayerTime = upcoming?.second ?: tomorrowFajr?.second
        val exactAlarmAvailable = hasExactAlarmPermission(context)
        if (nextPrayerTime != null) {
            scheduleRefreshAtPrayerTime(context, nextPrayerTime)
        }
        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.prayer_times_widget)
            val prayerNameIds = listOf(
                R.id.prayer_1_name,
                R.id.prayer_2_name,
                R.id.prayer_3_name,
                R.id.prayer_4_name,
                R.id.prayer_5_name,
            )
            val prayerTimeIds = listOf(
                R.id.prayer_1_time,
                R.id.prayer_2_time,
                R.id.prayer_3_time,
                R.id.prayer_4_time,
                R.id.prayer_5_time,
            )
            val prayerContainerIds = listOf(
                R.id.prayer_1_container,
                R.id.prayer_2_container,
                R.id.prayer_3_container,
                R.id.prayer_4_container,
                R.id.prayer_5_container,
            )
            val timeFormatter = SimpleDateFormat("HH:mm", displayLocale)
            prayers.forEachIndexed { index, prayer ->
                views.setViewVisibility(
                    prayerContainerIds[index],
                    if (prayer.name == nextPrayer?.name) View.GONE else View.VISIBLE,
                )
                views.setTextViewText(prayerNameIds[index], displayName(prayer.name, arabic))
                val prayerTime = if (prayer.hour in 0..23 && prayer.minute in 0..59) {
                    Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, prayer.hour)
                        set(Calendar.MINUTE, prayer.minute)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    }.time
                } else {
                    null
                }
                views.setTextViewText(
                    prayerTimeIds[index],
                    prayerTime?.let(timeFormatter::format) ?: "--:--",
                )
            }
            if (nextPrayer != null && nextPrayerTime != null) {
                val nextPrayerClock = Calendar.getInstance().apply {
                    timeInMillis = nextPrayerTime
                }
                val remaining = (nextPrayerTime - now).coerceAtLeast(0L)
                val nextPrayerName = displayName(nextPrayer.name, arabic).uppercase(displayLocale)
                views.setTextViewText(R.id.next_prayer, nextPrayerName)
                views.setTextViewText(R.id.next_prayer_time, SimpleDateFormat("hh:mm", displayLocale).format(nextPrayerClock.time))
                views.setTextViewText(R.id.next_prayer_period, SimpleDateFormat("a", displayLocale).format(nextPrayerClock.time))
                views.setTextViewText(
                    R.id.countdown_until,
                    if (arabic) "حتى ${displayName(nextPrayer.name, true)}" else "until ${nextPrayer.name}",
                )
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && exactAlarmAvailable) {
                    views.setChronometer(
                        R.id.countdown,
                        SystemClock.elapsedRealtime() + remaining,
                        null,
                        true,
                    )
                    views.setChronometerCountDown(R.id.countdown, true)
                } else {
                    val seconds = remaining / 1000L
                    views.setTextViewText(
                        R.id.countdown,
                        String.format(displayLocale, "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60),
                    )
                }
            } else {
                views.setTextViewText(R.id.next_prayer, if (arabic) "الصلاة القادمة" else "NEXT PRAYER")
                views.setTextViewText(R.id.next_prayer_time, "--:--")
                views.setTextViewText(R.id.next_prayer_period, "")
                views.setTextViewText(R.id.countdown_until, "")
                views.setTextViewText(
                    R.id.countdown,
                    if (arabic) "افتح أذان للتحديث" else "Open Azan to refresh",
                )
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun displayName(name: String, arabic: Boolean): String {
        if (!arabic) return name
        return when (name) {
            "Fajr" -> "الفجر"
            "Dhuhr" -> "الظهر"
            "Asr" -> "العصر"
            "Maghrib" -> "المغرب"
            "Isha" -> "العشاء"
            else -> name
        }
    }

    private fun hasExactAlarmPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }

    private fun scheduleRefreshAtPrayerTime(
        context: Context,
        prayerTimeMillis: Long,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = refreshIntent(context, PendingIntent.FLAG_UPDATE_CURRENT) ?: return
        val triggerAtMillis = prayerTimeMillis

        if (hasExactAlarmPermission(context)) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        }
    }

    private fun refreshIntent(context: Context, baseFlags: Int): PendingIntent? {
        val intent = Intent(context, PrayerTimesWidgetProvider::class.java).apply {
            action = ACTION_REFRESH
        }
        return PendingIntent.getBroadcast(
            context,
            WIDGET_REFRESH_REQUEST_CODE,
            intent,
            baseFlags or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private data class PrayerTime(val name: String, val hour: Int, val minute: Int)

    private companion object {
        const val TAG = "PrayerTimesWidget"
        const val WIDGET_REFRESH_REQUEST_CODE = 2026
        const val ACTION_REFRESH = "com.example.azan.action.REFRESH_PRAYER_WIDGET"
    }
}
