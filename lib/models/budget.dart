import 'package:hive/hive.dart';
import 'category.dart';

part 'budget.g.dart';

@HiveType(typeId: 3)
class Budget extends HiveObject {
  @HiveField(0)
  final Category category;

  @HiveField(1)
  double monthlyLimit;

  @HiveField(2)
  double alertAt;

  Budget({
    required this.category,
    required this.monthlyLimit,
    this.alertAt = 0.8,
  });
}
