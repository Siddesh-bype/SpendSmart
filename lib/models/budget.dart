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

  /// Null for legacy built-in category budgets. This trailing field keeps old
  /// Hive records readable while allowing custom-category budgets.
  @HiveField(3)
  final String? customCategoryId;

  Budget({
    required this.category,
    required this.monthlyLimit,
    this.alertAt = 0.8,
    this.customCategoryId,
  });

  Budget copyWith({
    Category? category,
    double? monthlyLimit,
    double? alertAt,
    String? customCategoryId,
    bool clearCustomCategory = false,
  }) =>
      Budget(
        category: category ?? this.category,
        monthlyLimit: monthlyLimit ?? this.monthlyLimit,
        alertAt: alertAt ?? this.alertAt,
        customCategoryId: clearCustomCategory
            ? null
            : (customCategoryId ?? this.customCategoryId),
      );
}
