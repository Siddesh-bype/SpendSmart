import 'package:hive/hive.dart';

part 'lending.g.dart';

@HiveType(typeId: 5)
class Lending extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String friendName;

  @HiveField(2)
  final double amount;

  /// true  = I gave money to friend (they owe me)
  /// false = I owe money to friend
  @HiveField(3)
  final bool isIGave;

  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  final String note;

  @HiveField(6)
  bool isSettled;

  Lending({
    required this.id,
    required this.friendName,
    required this.amount,
    required this.isIGave,
    required this.date,
    this.note = '',
    this.isSettled = false,
  });
}
