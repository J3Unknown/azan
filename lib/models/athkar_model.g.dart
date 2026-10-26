// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'athkar_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AthkarModelAdapter extends TypeAdapter<AthkarModel> {
  @override
  final typeId = 2;

  @override
  AthkarModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AthkarModel(
      id: fields[0] as String,
      arabicText: fields[1] as String,
      transliteration: fields[2] as String,
      translation: fields[3] as String,
      totalCount: (fields[4] as num).toInt(),
      currentCount: fields[5] == null ? 0 : (fields[5] as num).toInt(),
      prayerName: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AthkarModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.arabicText)
      ..writeByte(2)
      ..write(obj.transliteration)
      ..writeByte(3)
      ..write(obj.translation)
      ..writeByte(4)
      ..write(obj.totalCount)
      ..writeByte(5)
      ..write(obj.currentCount)
      ..writeByte(6)
      ..write(obj.prayerName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AthkarModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
