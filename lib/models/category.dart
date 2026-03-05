import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'category.g.dart';

@HiveType(typeId: 0)
enum Category {
  @HiveField(0)
  food,
  @HiveField(1)
  transport,
  @HiveField(2)
  shopping,
  @HiveField(3)
  health,
  @HiveField(4)
  entertainment,
  @HiveField(5)
  bills,
  @HiveField(6)
  other
}

extension CategoryExtension on Category {
  String get name {
    switch (this) {
      case Category.food: return 'Food';
      case Category.transport: return 'Transport';
      case Category.shopping: return 'Shopping';
      case Category.health: return 'Health';
      case Category.entertainment: return 'Entertainment';
      case Category.bills: return 'Bills';
      case Category.other: return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case Category.food: return const Color(0xFFFF6B6B);
      case Category.transport: return const Color(0xFF4ECDC4);
      case Category.shopping: return const Color(0xFF45B7D1);
      case Category.health: return const Color(0xFF96CEB4);
      case Category.entertainment: return const Color(0xFFFFB347);
      case Category.bills: return const Color(0xFFDA70D6);
      case Category.other: return const Color(0xFFB0BEC5);
    }
  }

  IconData get icon {
    switch (this) {
      case Category.food: return Icons.fastfood;
      case Category.transport: return Icons.directions_car;
      case Category.shopping: return Icons.shopping_bag;
      case Category.health: return Icons.favorite;
      case Category.entertainment: return Icons.movie;
      case Category.bills: return Icons.receipt;
      case Category.other: return Icons.category;
    }
  }
}
