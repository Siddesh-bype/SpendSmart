// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lending.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LendingAdapter extends TypeAdapter<Lending> {
  @override
  final int typeId = 5;

  @override
  Lending read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Lending(
      id: fields[0] as String,
      friendName: fields[1] as String,
      amount: fields[2] as double,
      isIGave: fields[3] as bool,
      date: fields[4] as DateTime,
      note: fields[5] as String,
      isSettled: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Lending obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.friendName)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.isIGave)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.isSettled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LendingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
