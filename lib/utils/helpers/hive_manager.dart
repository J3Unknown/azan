import 'dart:developer';

import 'package:azan/models/prayer_model.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

class HiveManager {
  static late final Box<PrayerModel> prayerBox;
  static late final Box metaDataBox;

  static Future<void> init() async {
    try {
      Hive.initFlutter();
      Hive.registerAdapter(PrayerModelAdapter());
      metaDataBox = await Hive.openBox('meta-data-box');
      prayerBox = await Hive.openBox<PrayerModel>('prayer-times');
    } catch (e) {
      log(e.toString());
    }
  }

  static Future<void> addUpdatePrayer(PrayerModel model) async {
    await prayerBox.put(model.prayerID, model);
  }

  static Future<void> addUpdateMetaData(String key, value) async {
    await metaDataBox.put(key, value);
  }

  static Future<dynamic> getMetaData() async {
    metaDataBox.values;
  }

  static Future<List<PrayerModel>> getPrayer() async {
    return prayerBox.values.toList();
  }
}
