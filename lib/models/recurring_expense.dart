import 'package:hive/hive.dart';
import 'category.dart';

class RecurringExpense extends HiveObject {
  final String id;
  final String title;
  final double amount;
  final Category category;
  final String frequency; // 'daily' | 'weekly' | 'monthly' | 'yearly'
  final DateTime startDate;
  DateTime nextDue;
  bool isActive;

  RecurringExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.startDate,
    required this.nextDue,
    this.isActive = true,
  });

  DateTime computeNextDue(DateTime from) {
    switch (frequency) {
      case 'daily':
        return from.add(const Duration(days: 1));
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'yearly':
        return DateTime(from.year + 1, from.month, from.day);
      case 'monthly':
      default:
        final next = DateTime(from.year, from.month + 1, from.day);
        return next;
    }
  }
}

class RecurringExpenseAdapter extends TypeAdapter<RecurringExpense> {
  @override
  final int typeId = 6;

  @override
  RecurringExpense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecurringExpense(
      id:        fields[0] as String,
      title:     fields[1] as String,
      amount:    (fields[2] as num).toDouble(),
      category:  fields[3] as Category,
      frequency: fields[4] as String,
      startDate: fields[5] as DateTime,
      nextDue:   fields[6] as DateTime,
      isActive:  fields[7] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, RecurringExpense obj) {
    writer.writeByte(8);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.title);
    writer.writeByte(2); writer.write(obj.amount);
    writer.writeByte(3); writer.write(obj.category);
    writer.writeByte(4); writer.write(obj.frequency);
    writer.writeByte(5); writer.write(obj.startDate);
    writer.writeByte(6); writer.write(obj.nextDue);
    writer.writeByte(7); writer.write(obj.isActive);
  }
}
