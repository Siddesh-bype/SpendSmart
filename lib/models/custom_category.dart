import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// Icons a custom category may use.
const customCategoryIcons = [
  Icons.category,
  Icons.repeat,
  Icons.home_work_outlined,
  Icons.school_outlined,
  Icons.pets_outlined,
  Icons.fitness_center_outlined,
  Icons.flight_takeoff_outlined,
  Icons.devices_other_outlined,
];

/// A user-owned category. Built-in [Category] values remain the legacy-safe
/// fallback on expenses; custom categories are referenced by this stable id.
class CustomCategory extends HiveObject {
  final String id;
  String name;
  int iconCodePoint;
  int colorValue;
  bool archived;
  String? mergedIntoId;

  CustomCategory({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    this.archived = false,
    this.mergedIntoId,
  });

  CustomCategory copyWith({
    String? name,
    int? iconCodePoint,
    int? colorValue,
    bool? archived,
    String? mergedIntoId,
    bool clearMergedIntoId = false,
  }) =>
      CustomCategory(
        id: id,
        name: name ?? this.name,
        iconCodePoint: iconCodePoint ?? this.iconCodePoint,
        colorValue: colorValue ?? this.colorValue,
        archived: archived ?? this.archived,
        mergedIntoId: clearMergedIntoId
            ? null
            : (mergedIntoId ?? this.mergedIntoId),
      );

  // Const lookup keeps release icon tree-shaking working; unknown code points
  // (e.g. from an imported backup) fall back to the generic icon.
  IconData get icon => customCategoryIcons.firstWhere(
        (icon) => icon.codePoint == iconCodePoint,
        orElse: () => Icons.category,
      );
  Color get color => Color(colorValue);
}

class CustomCategoryAdapter extends TypeAdapter<CustomCategory> {
  @override
  final int typeId = 9;

  @override
  CustomCategory read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };
    return CustomCategory(
      id: fields[0] as String,
      name: fields[1] as String,
      iconCodePoint: fields[2] as int,
      colorValue: fields[3] as int,
      archived: fields[4] as bool? ?? false,
      mergedIntoId: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CustomCategory obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.iconCodePoint)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.archived)
      ..writeByte(5)
      ..write(obj.mergedIntoId);
  }
}
