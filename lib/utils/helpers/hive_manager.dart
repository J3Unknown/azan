import 'dart:developer';
import 'package:azan/models/athkar_model.dart';
import 'package:azan/models/prayer_model.dart';
import 'package:azan/models/reminder_model.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

class HiveManager {
  static late final Box<PrayerModel> prayerBox;
  static late final Box metaDataBox;
  static late final Box<ReminderModel> reminderBox;
  static late final Box<AthkarModel> athkarBox;
  static late final Box surahCacheBox;

  static const String metaBoxName = 'meta-data-box';
  static const String prayerBoxName = 'prayer-times';
  static const String reminderBoxName = 'reminders-box';
  static const String athkarBoxName = 'athkar-box';
  static const String surahCacheBoxName = 'surah-cache-box';

  static Future<void> init() async {
    try {
      await Hive.initFlutter();

      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(PrayerModelAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ReminderModelAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(AthkarModelAdapter());
      }

      metaDataBox = await Hive.openBox(metaBoxName);
      prayerBox = await Hive.openBox<PrayerModel>(prayerBoxName);
      reminderBox = await Hive.openBox<ReminderModel>(reminderBoxName);
      athkarBox = await Hive.openBox<AthkarModel>(athkarBoxName);
      surahCacheBox = await Hive.openBox(surahCacheBoxName);

      await _seedDefaultAthkarIfEmpty();
      await _seedDefaultRemindersIfEmpty();
    } catch (e, stack) {
      log('Hive initialization error: $e\n$stack');
    }
  }

  // --- MetaData Helpers ---
  static Future<void> addUpdateMetaData(String key, dynamic value) async {
    await metaDataBox.put(key, value);
  }

  static dynamic getMeta(String key, {dynamic defaultValue}) {
    return metaDataBox.get(key, defaultValue: defaultValue);
  }

  static Future<Map<String, dynamic>> getMetaData() async {
    final Map<String, dynamic> map = {};
    for (var key in metaDataBox.keys) {
      map[key.toString()] = metaDataBox.get(key);
    }
    return map;
  }

  // --- Prayer Helpers ---
  static Future<void> addUpdatePrayer(PrayerModel model) async {
    await prayerBox.put(model.prayerID, model);
  }

  static List<PrayerModel> getPrayer() {
    return prayerBox.values.toList();
  }

  static Future<void> togglePrayerEnabled(int prayerID, bool isEnabled) async {
    final prayer = prayerBox.get(prayerID);
    if (prayer != null) {
      prayer.isEnabled = isEnabled;
      await prayerBox.put(prayerID, prayer);
    }
  }

  // --- Reminder Helpers ---
  static List<ReminderModel> getReminders() {
    return reminderBox.values.toList();
  }

  static Future<void> addReminder(ReminderModel reminder) async {
    await reminderBox.put(reminder.id, reminder);
  }

  static Future<void> updateReminder(ReminderModel reminder) async {
    await reminderBox.put(reminder.id, reminder);
  }

  static Future<void> deleteReminder(String id) async {
    await reminderBox.delete(id);
  }

  static Future<void> togglePinReminder(String id) async {
    final reminder = reminderBox.get(id);
    if (reminder != null) {
      reminder.isPinned = !reminder.isPinned;
      await reminderBox.put(id, reminder);
    }
  }

  static Future<void> toggleReminderActive(String id) async {
    final reminder = reminderBox.get(id);
    if (reminder != null) {
      reminder.isActive = !reminder.isActive;
      await reminderBox.put(id, reminder);
    }
  }

  // --- Athkar Helpers ---
  static List<AthkarModel> getAthkar() {
    return athkarBox.values.toList();
  }

  static Future<void> updateAthkar(AthkarModel athkar) async {
    await athkarBox.put(athkar.id, athkar);
  }

  static Future<void> resetAthkarCounts() async {
    for (var athkar in athkarBox.values) {
      athkar.currentCount = 0;
      await athkarBox.put(athkar.id, athkar);
    }
  }

  // --- Surah Cache Helpers ---
  static bool isSurahCached(int surahNumber) {
    return surahCacheBox.containsKey('surah_$surahNumber');
  }

  static dynamic getCachedSurah(int surahNumber) {
    return surahCacheBox.get('surah_$surahNumber');
  }

  static Future<void> cacheSurah(int surahNumber, dynamic data) async {
    await surahCacheBox.put('surah_$surahNumber', data);
  }

  static Future<void> _seedDefaultAthkarIfEmpty() async {
    if (athkarBox.isEmpty) {
      final defaultList = [
        AthkarModel(
          id: 'athkar_1',
          arabicText: 'سُبْحَانَ ٱللَّٰهِ',
          transliteration: 'SubhanAllah',
          translation: 'Glory be to Allah',
          totalCount: 33,
          currentCount: 0,
          prayerName: 'All',
        ),
        AthkarModel(
          id: 'athkar_2',
          arabicText: 'ٱلْحَمْدُ لِلَّٰهِ',
          transliteration: 'Alhamdulillah',
          translation: 'Praise be to Allah',
          totalCount: 33,
          currentCount: 0,
          prayerName: 'All',
        ),
        AthkarModel(
          id: 'athkar_3',
          arabicText: 'ٱللَّٰهُ أَكْبَرُ',
          transliteration: 'Allahu Akbar',
          translation: 'Allah is the Greatest',
          totalCount: 33,
          currentCount: 0,
          prayerName: 'All',
        ),
        AthkarModel(
          id: 'athkar_4',
          arabicText: 'لَا إِلَٰهَ إِلَّا ٱللَّٰهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ ٱلْمُلْكُ وَلَهُ ٱلْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ',
          transliteration: 'La ilaha illallah wahdahu la sharika lahu...',
          translation: 'None has the right to be worshipped except Allah alone, without partner...',
          totalCount: 1,
          currentCount: 0,
          prayerName: 'All',
        ),
        AthkarModel(
          id: 'athkar_5',
          arabicText: 'أَسْتَغْفِرُ ٱللَّٰهَ',
          transliteration: 'Astaghfirullah',
          translation: 'I seek the forgiveness of Allah',
          totalCount: 3,
          currentCount: 0,
          prayerName: 'All',
        ),
      ];
      for (var item in defaultList) {
        await athkarBox.put(item.id, item);
      }
    }
  }

  static Future<void> _seedDefaultRemindersIfEmpty() async {
    if (reminderBox.isEmpty) {
      final now = DateTime.now();
      final defaultReminders = [
        ReminderModel(
          id: 'reminder_1',
          title: 'Read Surah Al-Kahf',
          reminderTime: DateTime(now.year, now.month, now.day, 8, 0),
          reminderDate: DateTime(now.year, now.month, now.day),
          category: 'Quran',
          repeatTimes: -1,
          repeatInterval: 'weekly',
          isPinned: true,
          isActive: true,
        ),
        ReminderModel(
          id: 'reminder_2',
          title: 'Morning Athkar',
          reminderTime: DateTime(now.year, now.month, now.day, 6, 0),
          reminderDate: DateTime(now.year, now.month, now.day),
          category: 'Sunnah',
          repeatTimes: -1,
          repeatInterval: 'daily',
          isPinned: true,
          isActive: true,
        ),
        ReminderModel(
          id: 'reminder_3',
          title: 'Mondays & Thursdays',
          reminderTime: DateTime(now.year, now.month, now.day, 4, 30),
          reminderDate: DateTime(now.year, now.month, now.day),
          category: 'Fasting',
          repeatTimes: -1,
          repeatInterval: 'custom',
          isPinned: false,
          isActive: true,
        ),
        ReminderModel(
          id: 'reminder_4',
          title: 'Daily Dhikr',
          reminderTime: DateTime(now.year, now.month, now.day, 17, 30),
          reminderDate: DateTime(now.year, now.month, now.day),
          category: 'Sunnah',
          repeatTimes: -1,
          repeatInterval: 'daily',
          isPinned: false,
          isActive: true,
        ),
      ];
      for (var item in defaultReminders) {
        await reminderBox.put(item.id, item);
      }
    }
  }
}
