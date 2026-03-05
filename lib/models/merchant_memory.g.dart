// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'merchant_memory.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MerchantMemoryAdapter extends TypeAdapter<MerchantMemory> {
  @override
  final int typeId = 2;

  @override
  MerchantMemory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MerchantMemory(
      merchantName: fields[0] as String,
      category: fields[1] as Category,
      usageCount: fields[2] as int,
      lastUsed: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MerchantMemory obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.merchantName)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.usageCount)
      ..writeByte(3)
      ..write(obj.lastUsed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MerchantMemoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
