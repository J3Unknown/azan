// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReminderModelAdapter extends TypeAdapter<ReminderModel> {
  @override
  final typeId = 1;

  @override
  ReminderModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReminderModel(
      id: fields[0] as String,
      title: fields[1] as String,
      reminderTime: fields[2] as DateTime,
      reminderDate: fields[3] as DateTime,
      category: fields[4] as String,
      repeatTimes: fields[5] == null ? 0 : (fields[5] as num).toInt(),
      repeatInterval: fields[6] == null ? 'none' : fields[6] as String,
      isPinned: fields[7] == null ? false : fields[7] as bool,
      isActive: fields[8] == null ? true : fields[8] as bool,
      isCompleted: fields[9] == null ? false : fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ReminderModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.reminderTime)
      ..writeByte(3)
      ..write(obj.reminderDate)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.repeatTimes)
      ..writeByte(6)
      ..write(obj.repeatInterval)
      ..writeByte(7)
      ..write(obj.isPinned)
      ..writeByte(8)
      ..write(obj.isActive)
      ..writeByte(9)
      ..write(obj.isCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
