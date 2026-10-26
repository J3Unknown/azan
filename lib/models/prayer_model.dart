import 'package:hive_ce_flutter/hive_flutter.dart';

part 'prayer_model.g.dart';

@HiveType(typeId: 0)
class PrayerModel {
  @HiveField(0)
  int prayerID;
  @HiveField(1)
  String prayerName;
  @HiveField(2)
  DateTime prayerTime;
  @HiveField(3, defaultValue: true)
  bool isEnabled;

  PrayerModel(this.prayerID, this.prayerName, this.prayerTime, {this.isEnabled = true});

  @override
  bool operator ==(Object other) =>
      other is PrayerModel &&
      other.prayerID == prayerID &&
      other.prayerTime == prayerTime;

  @override
  int get hashCode => prayerID.hashCode;
}
