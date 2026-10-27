import 'package:azan/models/prayer_model.dart';
import 'package:home_widget/home_widget.dart';
import 'package:hijri/hijri_calendar.dart';

class PrayerHomeWidgetService {
  static const _providerName = 'PrayerTimesWidgetProvider';
  static const _providerClass = 'com.example.azan.PrayerTimesWidgetProvider';

  static Future<void> update(List<PrayerModel> prayers) async {
    if (prayers.isEmpty) return;

    final now = DateTime.now();
    final sorted = [...prayers]
      ..sort((a, b) => a.prayerID.compareTo(b.prayerID));
    final upcoming = sorted
        .map(
          (prayer) => (
            prayer: prayer,
            time: DateTime(
              now.year,
              now.month,
              now.day,
              prayer.prayerTime.hour,
              prayer.prayerTime.minute,
            ),
          ),
        )
        .where((entry) => entry.time.isAfter(now))
        .toList();

    final next = upcoming.isNotEmpty
        ? upcoming.first
        : (() {
            final fajr = sorted.firstWhere(
              (prayer) => prayer.prayerID == 1,
              orElse: () => sorted.first,
            );
            return (
              prayer: fajr,
              time: DateTime(
                now.year,
                now.month,
                now.day + 1,
                fajr.prayerTime.hour,
                fajr.prayerTime.minute,
              ),
            );
          })();

    final hijri = HijriCalendar.fromDate(now);
    final monthName = hijri.getLongMonthName();
    final hijriDate = '${hijri.hDay} $monthName ${hijri.hYear} AH';

    final values = <String, Object>{
      'hijri_date': hijriDate,
      'next_prayer_name': next.prayer.prayerName,
      'next_prayer_epoch': next.time.millisecondsSinceEpoch,
    };
    for (final prayer in sorted) {
      values['prayer_${prayer.prayerID}_hour'] = prayer.prayerTime.hour;
      values['prayer_${prayer.prayerID}_minute'] = prayer.prayerTime.minute;
    }

    await Future.wait(
      values.entries.map(
        (entry) => HomeWidget.saveWidgetData(entry.key, entry.value),
      ),
    );
    await HomeWidget.updateWidget(
      name: _providerName,
      androidName: _providerName,
      qualifiedAndroidName: _providerClass,
    );
  }

  static Future<void> requestPin() async {
    await HomeWidget.requestPinWidget(
      name: _providerName,
      androidName: _providerName,
      qualifiedAndroidName: _providerClass,
    );
  }
}
