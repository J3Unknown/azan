import 'package:adhan/adhan.dart';
import 'package:azan/utils/helpers/componenets.dart';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:azan/utils/routing/routing_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/browser.dart';
import 'package:workmanager/workmanager.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() async {
  Workmanager().executeTask((task, inputdata) async {
    try {
      initializeTimeZone();
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );
      await flutterLocalNotificationsPlugin.initialize(settings: initSettings);

      final metaData = await HiveManager.getMetaData();
      String? city = metaData['city'];
      if (city == null || city.isEmpty) city = await getCity();
      final todayDate = DateTime.now().toIso8601String().split('T').first;
      final lastDate = metaData['last-date'];

      if (lastDate == todayDate) return Future.value(true);

      final Coordinates coordinates = Coordinates(
        metaData['lat'] ?? 30.013056,
        metaData['long'] ?? 31.208853,
      );

      final params = CalculationMethod.muslim_world_league.getParameters();

      final date = DateComponents.from(DateTime.now());

      final prayerTimes = PrayerTimes(coordinates, date, params);

      setPrayerTimes(prayerTimes);

      await HiveManager.addUpdateMetaData('last-date', todayDate);
      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveManager.init();
  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask(
    'daily-prayer-fetch',
    'daily-prayer-fetch-task',
    frequency: Duration(hours: 12),
    constraints: Constraints(networkType: NetworkType.notRequired),
  );
  initializeTimeZone();
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: androidSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(routerConfig: GoRouterConfig.routes);
  }
}
