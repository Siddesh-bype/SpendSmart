import 'package:flutter/material.dart';
import '../models/category.dart';
import '../utils/constants.dart';

class CategoryGrid extends StatelessWidget {
  final Category? selectedCategory;
  final ValueChanged<Category> onSelect;

  const CategoryGrid({
    super.key,
    this.selectedCategory,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: Category.values.length,
      itemBuilder: (context, index) {
        final category = Category.values[index];
        final isSelected = selectedCategory == category;
        return InkWell(
          onTap: () => onSelect(category),
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? category.color.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
              border: Border.all(
                color: isSelected ? category.color : Colors.grey.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(category.icon, color: category.color, size: 28),
                const SizedBox(height: 4),
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? category.color : null,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
