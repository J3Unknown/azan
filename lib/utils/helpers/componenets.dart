import 'dart:developer';
import 'dart:math' as math;
import 'package:adhan/adhan.dart';
import 'package:azan/main.dart';
import 'package:azan/models/prayer_model.dart';
import 'package:azan/models/reminder_model.dart';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geocoding/geocoding.dart' as gc;
import 'package:geolocator/geolocator.dart';
import 'package:timezone/timezone.dart' as tz;

// Kaaba Coordinates (Makkah Al-Mukarramah)
const double kaabaLatitude = 21.422487;
const double kaabaLongitude = 39.826206;

/// Calculate Qibla bearing (in degrees, 0..360 from True North) and distance (in km)
/// using spherical trigonometry from user's coordinates to the Kaaba in Makkah.
class QiblaData {
  final double bearing; // in degrees 0..360
  final double distanceKm; // in kilometers
  final String directionText;

  QiblaData({
    required this.bearing,
    required this.distanceKm,
    required this.directionText,
  });
}

QiblaData calculateQibla(double userLat, double userLng) {
  // Convert degrees to radians
  final phi1 = userLat * (math.pi / 180.0);
  final lambda1 = userLng * (math.pi / 180.0);
  final phi2 = kaabaLatitude * (math.pi / 180.0);
  final lambda2 = kaabaLongitude * (math.pi / 180.0);

  final deltaLambda = lambda2 - lambda1;

  final y = math.sin(deltaLambda);
  final x = math.cos(phi1) * math.tan(phi2) - math.sin(phi1) * math.cos(deltaLambda);

  double bearingRad = math.atan2(y, x);
  double bearingDeg = (bearingRad * (180.0 / math.pi) + 360.0) % 360.0;

  // Calculate distance using Haversine formula
  const earthRadiusKm = 6371.0;
  final dLat = phi2 - phi1;
  final dLon = lambda2 - lambda1;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(phi1) * math.cos(phi2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  final distance = earthRadiusKm * c;

  // Compass direction label
  String directionText = _bearingToDirection(bearingDeg);

  return QiblaData(
    bearing: bearingDeg,
    distanceKm: distance,
    directionText: directionText,
  );
}

String _bearingToDirection(double deg) {
  if (deg >= 337.5 || deg < 22.5) return 'N';
  if (deg >= 22.5 && deg < 67.5) return 'NE';
  if (deg >= 67.5 && deg < 112.5) return 'E';
  if (deg >= 112.5 && deg < 157.5) return 'SE';
  if (deg >= 157.5 && deg < 202.5) return 'S';
  if (deg >= 202.5 && deg < 247.5) return 'SW';
  if (deg >= 247.5 && deg < 292.5) return 'W';
  return 'NW';
}

/// Schedules adhan notification for an enabled prayer
Future<void> scheduleTask(PrayerModel model) async {
  if (!model.isEnabled) {
    await cancelNotification(model.prayerID);
    return;
  }

  if (model.prayerTime.isBefore(DateTime.now())) return;

  final bool isFajr = model.prayerName.toLowerCase() == 'fajr' || model.prayerID == 1;
  final String soundName = isFajr ? 'fajr' : 'other';
  final String channelId = isFajr ? 'adhan-fajr-channel' : 'adhan-other-channel';
  final String channelName = isFajr ? 'Fajr Prayer Adhan' : 'Other Prayers Adhan';

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: 'Play adhan at exact prayer time',
    importance: Importance.high,
    priority: Priority.max,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    sound: RawResourceAndroidNotificationSound(soundName),
    playSound: true,
  );

  try {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: model.prayerID,
      title: 'Prayer Time',
      body: 'It\'s time for ${model.prayerName} prayer',
      scheduledDate: tz.TZDateTime.from(model.prayerTime, tz.local),
      notificationDetails: NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  } catch (e) {
    log('Failed to schedule prayer notification: $e');
  }
}

Future<void> cancelNotification(int id) async {
  try {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  } catch (e) {
    log('Cancel notification error: $e');
  }
}

/// Schedule reminder notification
Future<void> scheduleReminderNotification(ReminderModel reminder) async {
  if (!reminder.isActive) {
    await cancelNotification(reminder.id.hashCode);
    return;
  }

  // Combine date and time
  DateTime scheduledDateTime = DateTime(
    reminder.reminderDate.year,
    reminder.reminderDate.month,
    reminder.reminderDate.day,
    reminder.reminderTime.hour,
    reminder.reminderTime.minute,
  );

  if (scheduledDateTime.isBefore(DateTime.now())) {
    // If repeat is daily/weekly/forever, schedule for next occurrence
    if (reminder.repeatTimes != 0) {
      if (reminder.repeatInterval == 'daily' || reminder.repeatTimes == -1) {
        while (scheduledDateTime.isBefore(DateTime.now())) {
          scheduledDateTime = scheduledDateTime.add(const Duration(days: 1));
        }
      } else if (reminder.repeatInterval == 'weekly') {
        while (scheduledDateTime.isBefore(DateTime.now())) {
          scheduledDateTime = scheduledDateTime.add(const Duration(days: 7));
        }
      }
    } else {
      return;
    }
  }

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'reminder-channel-id',
    'Daily Reminders',
    channelDescription: 'Reminders for daily dhikr, Quran and sunnah',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );

  try {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: reminder.id.hashCode,
      title: reminder.category,
      body: reminder.title,
      scheduledDate: tz.TZDateTime.from(scheduledDateTime, tz.local),
      notificationDetails: const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  } catch (e) {
    log('Failed to schedule reminder notification: $e');
  }
}

/// Get device city and coordinates with fallback to Cairo, Egypt
Future<String> getCity() async {
  final cachedCity = HiveManager.getMeta('city');
  if (cachedCity != null && (cachedCity as String).isNotEmpty) {
    return cachedCity;
  }

  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setDefaultCairo();
      return 'Cairo, Egypt';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _setDefaultCairo();
        return 'Cairo, Egypt';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _setDefaultCairo();
      return 'Cairo, Egypt';
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );

    List<gc.Placemark> places = await gc.Geocoding().placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    String cityName = 'Cairo';
    String countryName = 'Egypt';

    if (places.isNotEmpty) {
      gc.Placemark place = places.first;
      cityName = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? 'Cairo';
      countryName = place.country ?? 'Egypt';
    }

    final formattedLocation = '$cityName, $countryName';

    await HiveManager.addUpdateMetaData('lat', position.latitude);
    await HiveManager.addUpdateMetaData('long', position.longitude);
    await HiveManager.addUpdateMetaData('city', formattedLocation);
    await HiveManager.addUpdateMetaData('last-date', '');

    return formattedLocation;
  } catch (e) {
    _setDefaultCairo();
    return 'Cairo, Egypt';
  }
}

void _setDefaultCairo() {
  HiveManager.addUpdateMetaData('lat', 30.0444);
  HiveManager.addUpdateMetaData('long', 31.2357);
  HiveManager.addUpdateMetaData('city', 'Cairo, Egypt');
}

/// Calculate prayer times and update Hive store, preserving user enable/disable preferences
Future<void> recalculateAndStorePrayerTimes() async {
  try {
    double lat = (HiveManager.getMeta('lat') as num?)?.toDouble() ?? 30.0444;
    double lng = (HiveManager.getMeta('long') as num?)?.toDouble() ?? 31.2357;

    final Coordinates coordinates = Coordinates(lat, lng);
    final params = CalculationMethod.egyptian.getParameters();
    params.madhab = Madhab.shafi;

    final date = DateComponents.from(DateTime.now());
    final prayerTimes = PrayerTimes(coordinates, date, params);

    await setPrayerTimes(prayerTimes);

    final todayDate = DateTime.now().toIso8601String().split('T').first;
    await HiveManager.addUpdateMetaData('last-date', todayDate);
  } catch (e, stack) {
    log('Error recalculating prayer times: $e\n$stack');
  }
}

Future<void> setPrayerTimes(PrayerTimes prayerTimes) async {
  final existingPrayers = HiveManager.getPrayer();
  Map<int, bool> enabledMap = {};
  for (var p in existingPrayers) {
    enabledMap[p.prayerID] = p.isEnabled;
  }

  final prayersToSave = [
    PrayerModel(
      1,
      'Fajr',
      prayerTimes.fajr.toLocal(),
      isEnabled: enabledMap[1] ?? true,
    ),
    PrayerModel(
      2,
      'Dhuhr',
      prayerTimes.dhuhr.toLocal(),
      isEnabled: enabledMap[2] ?? true,
    ),
    PrayerModel(
      3,
      'Asr',
      prayerTimes.asr.toLocal(),
      isEnabled: enabledMap[3] ?? true,
    ),
    PrayerModel(
      4,
      'Maghrib',
      prayerTimes.maghrib.toLocal(),
      isEnabled: enabledMap[4] ?? true,
    ),
    PrayerModel(
      5,
      'Isha',
      prayerTimes.isha.toLocal(),
      isEnabled: enabledMap[5] ?? true,
    ),
  ];

  for (var prayer in prayersToSave) {
    await HiveManager.addUpdatePrayer(prayer);
    if (prayer.isEnabled) {
      await scheduleTask(prayer);
    } else {
      await cancelNotification(prayer.prayerID);
    }
  }
}

/// Checks if any prayer time has just been reached, and if so, resets Athkar counts.
Future<void> checkAndResetAthkarForPrayerTimes() async {
  final prayers = HiveManager.getPrayer();
  if (prayers.isEmpty) return;

  final now = DateTime.now();
  final lastResetPrayerId = HiveManager.getMeta('last_reset_prayer_id', defaultValue: -1);

  // Find if there is a prayer that happened recently and hasn't been reset yet
  for (var prayer in prayers) {
    // If prayer time is in the past (today) and this prayer was not yet marked as reset
    if (now.isAfter(prayer.prayerTime)) {
      final prayerDay = prayer.prayerTime.day;
      final lastResetDay = HiveManager.getMeta('last_reset_day', defaultValue: -1);

      if (lastResetPrayerId != prayer.prayerID || lastResetDay != prayerDay) {
        // Reset athkar count
        await HiveManager.resetAthkarCounts();
        await HiveManager.addUpdateMetaData('last_reset_prayer_id', prayer.prayerID);
        await HiveManager.addUpdateMetaData('last_reset_day', prayerDay);
        log('Athkar counts reset for prayer: ${prayer.prayerName}');
      }
    }
  }
}
