import 'package:azan/utils/helpers/componenets.dart';
import 'package:azan/utils/helpers/hive_manager.dart';
import 'package:azan/utils/routing/routing_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:workmanager/workmanager.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      tz_data.initializeTimeZones();
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );
      await flutterLocalNotificationsPlugin.initialize(
        settings: initSettings,
      );

      await HiveManager.init();

      // Recalculate prayer times every 8 hours
      await recalculateAndStorePrayerTimes();

      // Check athkar reset if a prayer time has arrived
      await checkAndResetAthkarForPrayerTimes();

      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.unknown.azan.quran.audio',
    androidNotificationChannelName: 'Quran playback',
    androidNotificationOngoing: true,
  );

  // Initialize TimeZone database
  tz_data.initializeTimeZones();

  // Initialize Hive and its adapters/boxes
  await HiveManager.init();

  // Initialize notifications
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: androidSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );
  final androidNotifications = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidNotifications?.requestNotificationsPermission();
  await androidNotifications?.requestExactAlarmsPermission();

  // Initialize Workmanager for 8-hour periodic recalculation
  try {
    Workmanager().initialize(callbackDispatcher);
    Workmanager().registerPeriodicTask(
      'prayer-recalculate-8h',
      'daily-prayer-fetch-task',
      frequency: const Duration(hours: 8),
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
  } catch (e) {
    debugPrint('Workmanager init error: $e');
  }

  // App launch handling: ensure city is fetched and prayer times are calculated immediately
  try {
    await getCity();
    await recalculateAndStorePrayerTimes();
    await checkAndResetAthkarForPrayerTimes();
  } catch (e) {
    debugPrint('App launch setup error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Azan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF191A19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFCFB68E),
          surface: Color(0xFF282826),
        ),
      ),
      routerConfig: GoRouterConfig.routes,
    );
  }
}
