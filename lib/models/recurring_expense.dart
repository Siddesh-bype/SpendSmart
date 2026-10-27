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
        // Anchor to the start date so Feb 29 stays in February (clamped to 28
        // in common years) instead of overflowing into March.
        final anchorDay = startDate.day;
        final targetYear = from.year + 1;
        final lastDay = DateTime(targetYear, startDate.month + 1, 0).day;
        return DateTime(targetYear, startDate.month, anchorDay.clamp(1, lastDay));
      case 'monthly':
      default:
        // Anchor to the rule's start day, not the cursor's: Jan 31 must recur
        // as Feb 28 then return to Mar 31, never drift to the 28th forever.
        final anchorDay = startDate.day;
        var nextMonth = from.month + 1;
        var nextYear = from.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        final lastDayOfMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        return DateTime(nextYear, nextMonth, anchorDay.clamp(1, lastDayOfMonth));
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
