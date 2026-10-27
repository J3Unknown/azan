import 'package:hive_ce_flutter/hive_flutter.dart';

part 'reminder_model.g.dart';

@HiveType(typeId: 1)
class ReminderModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime reminderTime;

  @HiveField(3)
  DateTime reminderDate;

  @HiveField(4)
  String category;

  @HiveField(5)
  int repeatTimes; // -1 means forever, 0 means no repeat, >0 means N times

  @HiveField(6)
  String repeatInterval; // 'daily', 'weekly', 'monthly', 'custom', 'none'

  @HiveField(7)
  bool isPinned;

  @HiveField(8)
  bool isActive;

  @HiveField(9)
  bool isCompleted;

  ReminderModel({
    required this.id,
    required this.title,
    required this.reminderTime,
    required this.reminderDate,
    required this.category,
    this.repeatTimes = 0,
    this.repeatInterval = 'none',
    this.isPinned = false,
    this.isActive = true,
    this.isCompleted = false,
  });
}
