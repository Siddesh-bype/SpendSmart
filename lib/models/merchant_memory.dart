import 'package:hive/hive.dart';
import 'category.dart';

part 'merchant_memory.g.dart';

@HiveType(typeId: 2)
class MerchantMemory extends HiveObject {
  @HiveField(0)
  final String merchantName;

  @HiveField(1)
  final Category category;

  @HiveField(2)
  int usageCount;

  @HiveField(3)
  DateTime lastUsed;

  MerchantMemory({
    required this.merchantName,
    required this.category,
    this.usageCount = 1,
    required this.lastUsed,
  });
}
