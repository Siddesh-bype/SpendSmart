import 'package:hive/hive.dart';
import 'category.dart';

part 'expense.g.dart';

@HiveType(typeId: 1)
class Expense extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  Category category;

  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  final String? note;

  @HiveField(6)
  final bool isManual;

  @HiveField(7)
  bool isUncategorized;

  @HiveField(8)
  final String source;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
    required this.isManual,
    required this.isUncategorized,
    required this.source,
  });

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    Category? category,
    DateTime? date,
    String? note,
    bool? isManual,
    bool? isUncategorized,
    String? source,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      isManual: isManual ?? this.isManual,
      isUncategorized: isUncategorized ?? this.isUncategorized,
      source: source ?? this.source,
    );
  }
}
