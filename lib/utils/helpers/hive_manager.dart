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
    // Seed the complete post-prayer set for both new and existing installs.
    // Keep counters for entries already stored by the user.
    final defaultList = [
        AthkarModel(
          id: 'prayer_athkar_1',
          arabicText: 'أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ، أَسْتَغْفِرُ اللَّهَ.\nاللَّهُمَّ أَنْتَ السَّلَامُ، وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ.',
          transliteration: 'Astaghfirullah (three times). Allahumma anta as-salam wa minka as-salam, tabarakta ya dhal-jalali wal-ikram.',
          translation: 'I seek Allah’s forgiveness (three times). O Allah, You are Peace and from You is peace. Blessed are You, O Possessor of majesty and honor.',
          totalCount: 1,
          currentCount: 0,
          prayerName: 'All prayers',
        ),
        AthkarModel(
          id: 'prayer_athkar_2',
          arabicText: 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، اللَّهُمَّ لَا مَانِعَ لِمَا أَعْطَيْتَ، وَلَا مُعْطِيَ لِمَا مَنَعْتَ، وَلَا يَنْفَعُ ذَا الْجَدِّ مِنْكَ الْجَدُّ.',
          transliteration: 'La ilaha illa Allah wahdahu la sharika lahu, lahul-mulku wa lahul-hamd...',
          translation: 'None has the right to be worshipped except Allah alone, without partner. His is the dominion and praise, and He is capable of all things. O Allah, none can withhold what You give, nor give what You withhold; wealth cannot benefit its possessor against You.',
          totalCount: 1,
          currentCount: 0,
          prayerName: 'All prayers',
        ),
        AthkarModel(
          id: 'prayer_athkar_3',
          arabicText: 'لَا إِلَهَ إِلَّا اللَّهُ، وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ، لَا إِلَهَ إِلَّا اللَّهُ، وَلَا نَعْبُدُ إِلَّا إِيَّاهُ، لَهُ النِّعْمَةُ وَلَهُ الْفَضْلُ وَلَهُ الثَّنَاءُ الْحَسَنُ، لَا إِلَهَ إِلَّا اللَّهُ مُخْلِصِينَ لَهُ الدِّينَ وَلَوْ كَرِهَ الْكَافِرُونَ.',
          transliteration: 'La ilaha illa Allah wahdahu la sharika lahu... mukhlisina lahud-dina wa law karihal-kafirun.',
          translation: 'None has the right to be worshipped except Allah alone. His is the dominion and praise. There is no might or power except through Allah. We worship none but Him; to Him belong favor, bounty, and good praise. We sincerely devote the religion to Him, even if the disbelievers dislike it.',
          totalCount: 1,
          currentCount: 0,
          prayerName: 'All prayers',
        ),
        AthkarModel(
          id: 'prayer_athkar_4', arabicText: 'سُبْحَانَ اللَّهِ', transliteration: 'SubhanAllah', translation: 'Glory be to Allah.', totalCount: 33, currentCount: 0, prayerName: 'All prayers',
        ),
        AthkarModel(
          id: 'prayer_athkar_5', arabicText: 'وَالْحَمْدُ لِلَّهِ', transliteration: 'Alhamdulillah', translation: 'Praise be to Allah.', totalCount: 33, currentCount: 0, prayerName: 'All prayers',
        ),
        AthkarModel(
          id: 'prayer_athkar_6', arabicText: 'وَاللَّهُ أَكْبَرُ', transliteration: 'Allahu akbar', translation: 'Allah is the Greatest.', totalCount: 33, currentCount: 0, prayerName: 'All prayers',
        ),
        AthkarModel(
          id: 'prayer_athkar_7', arabicText: 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.', transliteration: 'La ilaha illa Allah wahdahu la sharika lahu, lahul-mulku wa lahul-hamd...', translation: 'None has the right to be worshipped except Allah alone, without partner. His is the dominion and praise, and He is capable of all things.', totalCount: 1, currentCount: 0, prayerName: 'All prayers',
        ),
        AthkarModel(
          id: 'prayer_athkar_8', arabicText: 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ\nقُلْ هُوَ اللَّهُ أَحَدٌ، اللَّهُ الصَّمَدُ، لَمْ يَلِدْ وَلَمْ يُولَدْ، وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ.\n\nبِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ\nقُلْ أَعُوذُ بِرَبِّ الْفَلَقِ، مِن شَرِّ مَا خَلَقَ، وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ، وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ، وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ.\n\nبِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ\nقُلْ أَعُوذُ بِرَبِّ النَّاسِ، مَلِكِ النَّاسِ، إِلَٰهِ النَّاسِ، مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ، الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ، مِنَ الْجِنَّةِ وَالنَّاسِ.', transliteration: 'Surat Al-Ikhlas, Al-Falaq, and An-Nas.', translation: 'Recite each of these three chapters three times after Fajr and Maghrib, and once after the other prayers.', totalCount: 3, currentCount: 0, prayerName: 'Three after Fajr and Maghrib; once after other prayers',
        ),
        AthkarModel(
          id: 'prayer_athkar_9', arabicText: 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ\nاللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ. [آيَةُ الْكُرْسِيِّ - الْبَقَرَةُ 255]', transliteration: 'A’udhu billahi minash-shaytanir-rajim. Ayat al-Kursi.', translation: 'I seek refuge in Allah from Satan, the accursed. Allah—there is no deity except Him, the Ever-Living, the Sustainer... (Al-Baqarah 2:255).', totalCount: 1, currentCount: 0, prayerName: 'All prayers',
        ),
        AthkarModel(
          id: 'prayer_athkar_10', arabicText: 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، يُحْيِي وَيُمِيتُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ.', transliteration: 'La ilaha illa Allah wahdahu la sharika lahu, yuhyi wa yumit...', translation: 'None has the right to be worshipped except Allah alone, without partner. His is the dominion and praise; He gives life and causes death, and He is capable of all things.', totalCount: 10, currentCount: 0, prayerName: 'Ten after Maghrib and Fajr; once after other prayers',
        ),
        AthkarModel(
          id: 'prayer_athkar_11', arabicText: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا.', transliteration: 'Allahumma inni as’aluka ilman nafi’an wa rizqan tayyiban wa amalan mutaqabbalan.', translation: 'O Allah, I ask You for beneficial knowledge, good provision, and accepted deeds.', totalCount: 1, currentCount: 0, prayerName: 'After Fajr prayer salam',
        ),
        AthkarModel(
          id: 'prayer_athkar_12', arabicText: 'اللَّهُمَّ أَجِرْنِي مِنَ النَّارِ.', transliteration: 'Allahumma ajirni min an-nar.', translation: 'O Allah, protect me from the Fire.', totalCount: 7, currentCount: 0, prayerName: 'After Fajr and Maghrib',
        ),
        AthkarModel(
          id: 'prayer_athkar_13', arabicText: 'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ.', transliteration: 'Allahumma a’inni ala dhikrika wa shukrika wa husni ibadatik.', translation: 'O Allah, help me to remember You, thank You, and worship You well.', totalCount: 1, currentCount: 0, prayerName: 'All prayers',
        ),
      ];
    for (final item in defaultList) {
      if (!athkarBox.containsKey(item.id)) await athkarBox.put(item.id, item);
    }
    // Remove the old abbreviated seed entries so they are not shown beside the full set.
    for (var i = 1; i <= 5; i++) {
      await athkarBox.delete('athkar_$i');
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
