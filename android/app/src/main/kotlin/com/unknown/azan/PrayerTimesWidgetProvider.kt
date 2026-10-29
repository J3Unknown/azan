package com.unknown.azan

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate
import java.time.ZoneId
import java.time.chrono.HijrahDate
import java.time.format.DateTimeFormatter
import java.util.Locale

class PrayerTimesWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = System.currentTimeMillis()
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now(zone)

        val prayerNames = listOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")
        val prayerTimes = prayerNames.mapIndexed { index, name ->
            val id = index + 1
            val hour = widgetData.getInt("prayer_${id}_hour", -1)
            val minute = widgetData.getInt("prayer_${id}_minute", -1)
            val timeViewId = listOf(
                R.id.fajr_time,
                R.id.dhuhr_time,
                R.id.asr_time,
                R.id.maghrib_time,
                R.id.isha_time,
            )[index]
            val labelViewId = listOf(
                R.id.fajr_label,
                R.id.dhuhr_label,
                R.id.asr_label,
                R.id.maghrib_label,
                R.id.isha_label,
            )[index]

            val formatted = if (hour in 0..23 && minute in 0..59) {
                String.format(Locale.getDefault(), "%02d:%02d", hour, minute)
            } else {
                "--:--"
            }

            PrayerTime(name, hour, minute, timeViewId, labelViewId, formatted)
        }

        val upcoming = prayerTimes.firstOrNull { prayer ->
            prayer.hour in 0..23 && prayer.minute in 0..59 &&
                today.atTime(prayer.hour, prayer.minute).atZone(zone).toInstant().toEpochMilli() > now
        } ?: prayerTimes.firstOrNull {
            it.name == "Fajr" && it.hour in 0..23 && it.minute in 0..59
        }

        val nextTimeMillis = upcoming?.let { prayer ->
            val date = if (today.atTime(prayer.hour, prayer.minute).atZone(zone)
                    .toInstant().toEpochMilli() > now) today else today.plusDays(1)
            date.atTime(prayer.hour, prayer.minute).atZone(zone).toInstant().toEpochMilli()
        } ?: now

        appWidgetIds.forEach { appWidgetId ->
            val views = RemoteViews(context.packageName, R.layout.prayer_times_widget)
            prayerTimes.forEach { prayer ->
                views.setTextViewText(prayer.labelViewId, prayer.name)
                views.setTextViewText(prayer.timeViewId, prayer.formatted)
            }
            views.setTextViewText(
                R.id.hijri_date,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    HijrahDate.now().format(DateTimeFormatter.ofPattern("d MMMM yyyy", Locale("ar"))) + " هـ"
                } else {
                    widgetData.getString("hijri_date", "") ?: ""
                },
            )

            if (upcoming != null) {
                views.setTextViewText(R.id.next_prayer, "Next prayer · ${upcoming.name}")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    val remaining = (nextTimeMillis - now).coerceAtLeast(0L)
                    views.setChronometer(
                        R.id.countdown,
                        SystemClock.elapsedRealtime() + remaining,
                        null,
                        true,
                    )
                    views.setChronometerCountDown(R.id.countdown, true)
                } else {
                    val minutes = ((nextTimeMillis - now).coerceAtLeast(0L) / 60_000L)
                    views.setTextViewText(R.id.countdown, "${minutes / 60}h ${minutes % 60}m")
                }
            } else {
                views.setTextViewText(R.id.next_prayer, "Prayer times")
                views.setTextViewText(R.id.countdown, "Open the app to refresh")
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private data class PrayerTime(
        val name: String,
        val hour: Int,
        val minute: Int,
        val timeViewId: Int,
        val labelViewId: Int,
        val formatted: String,
    )
}
