import 'package:adhan/adhan.dart';
import 'package:azan/main.dart';
import 'dart:developer';
import 'package:azan/models/prayer_model.dart';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geocoding/geocoding.dart' as gc;
import 'package:geolocator/geolocator.dart';
import 'package:timezone/timezone.dart';

Future<void> scheduleTask(PrayerModel model) async {
  if (model.prayerTime.isBefore(DateTime.now())) return;

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'adhan-channel-id',
    'prayer Times',
    channelDescription: 'Play adhan at exact prayer time',
    importance: .high,
    priority: .max,
    audioAttributesUsage: .alarm,
    sound: RawResourceAndroidNotificationSound('adhan'),
    playSound: true,
  );

  await flutterLocalNotificationsPlugin.zonedSchedule(
    id: model.prayerID,
    notificationDetails: const NotificationDetails(android: androidDetails),
    androidScheduleMode: .exactAllowWhileIdle,
    scheduledDate: TZDateTime.from(model.prayerTime, local),
    body: 'It\'s time for ${model.prayerName} prayer',
    title: 'Prayer Time',
  );
}

Future<String> getCity() async {
  if (HiveManager.metaDataBox.containsKey('city'))
    return HiveManager.metaDataBox.get('city');
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return 'Giza';

  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == .denied) {
    permission = await Geolocator.requestPermission();
    if (permission == .denied) {
      return 'Giza';
    }
  }

  if (permission == .deniedForever) return 'Giza';

  Position position = await Geolocator.getCurrentPosition(
    desiredAccuracy: .medium,
  );

  List<gc.Placemark> places = await gc.Geocoding().placemarkFromCoordinates(
    position.latitude,
    position.longitude,
  );

  if (places.isEmpty) return 'Giza';

  gc.Placemark place = places.first;
  final cityName = place.locality ?? place.administrativeArea ?? 'Giza';

  HiveManager.addUpdateMetaData('lat', position.latitude);
  HiveManager.addUpdateMetaData('long', position.longitude);
  HiveManager.addUpdateMetaData('city', cityName);

  HiveManager.addUpdateMetaData('last-date', '');

  return cityName;
}

Future<void> setPrayerTimes(PrayerTimes prayerTimes) async {
  final prayers = await HiveManager.getPrayer();
  final fajr = prayers.first;
  final dhuhr = prayers[1];
  final asr = prayers[2];
  final maghrib = prayers[3];
  final isha = prayers[4];
  final PrayerModel fajrModel = PrayerModel(
    1,
    'Fajr',
    prayerTimes.fajr.toLocal(),
  );
  if (fajr != fajrModel) {
    await scheduleTask(fajrModel);
    log('set fajr');
    HiveManager.addUpdatePrayer(fajrModel);
  }

  final PrayerModel dhuhrModel = PrayerModel(
    2,
    'dhuhr',
    prayerTimes.dhuhr.toLocal(),
  );
  if (dhuhr != dhuhrModel) {
    await scheduleTask(dhuhrModel);
    log('set dhuhr');
    HiveManager.addUpdatePrayer(dhuhrModel);
  }

  final PrayerModel asrModel = PrayerModel(3, 'Asr', prayerTimes.asr.toLocal());
  if (asr != asrModel) {
    await scheduleTask(asrModel);
    log('set asr');
    HiveManager.addUpdatePrayer(asrModel);
  }

  final PrayerModel maghribModel = PrayerModel(
    4,
    'Maghrib',
    prayerTimes.maghrib.toLocal(),
  );
  if (maghrib != maghribModel) {
    await scheduleTask(maghribModel);
    log('set magrhib');
    HiveManager.addUpdatePrayer(maghribModel);
  }

  final PrayerModel ishaModel = PrayerModel(
    5,
    'Isha',
    prayerTimes.isha.toLocal(),
  );
  if (isha != ishaModel) {
    await scheduleTask(ishaModel);
    log('set isha');
    HiveManager.addUpdatePrayer(ishaModel);
  }
}
