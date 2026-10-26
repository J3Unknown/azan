import 'package:hive_ce_flutter/hive_flutter.dart';

part 'athkar_model.g.dart';

@HiveType(typeId: 2)
class AthkarModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String arabicText;

  @HiveField(2)
  String transliteration;

  @HiveField(3)
  String translation;

  @HiveField(4)
  int totalCount;

  @HiveField(5)
  int currentCount;

  @HiveField(6)
  String prayerName; // associated prayer name

  AthkarModel({
    required this.id,
    required this.arabicText,
    required this.transliteration,
    required this.translation,
    required this.totalCount,
    this.currentCount = 0,
    required this.prayerName,
  });
}
