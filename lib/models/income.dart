import 'package:hive/hive.dart';

class Income extends HiveObject {
  final String id;
  final double amount;
  final String source; // e.g. "Salary", "Freelance", "Other"
  final DateTime date;
  final String note;

  Income({
    required this.id,
    required this.amount,
    required this.source,
    required this.date,
    this.note = '',
  });
}

// Manual TypeAdapter — typeId 4 (not used by any existing model)
class IncomeAdapter extends TypeAdapter<Income> {
  @override
  final int typeId = 4;

  @override
  Income read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Income(
      id: fields[0] as String,
      amount: (fields[1] as num).toDouble(),
      source: fields[2] as String,
      date: fields[3] as DateTime,
      note: fields[4] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, Income obj) {
    writer.writeByte(5); // field count
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.amount);
    writer.writeByte(2); writer.write(obj.source);
    writer.writeByte(3); writer.write(obj.date);
    writer.writeByte(4); writer.write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncomeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
