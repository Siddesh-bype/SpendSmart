import 'package:flutter/material.dart';
import '../models/category.dart';
import '../utils/design.dart';
import '../utils/theme.dart';

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
    final scheme = SchemeTheme.of(context);

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
        final categoryColor = scheme.categoryColors[index];
        return InkWell(
          onTap: () => onSelect(category),
          borderRadius: AppRadius.mdAll,
          child: AnimatedContainer(
            duration: AppMotion.duration(context, AppDuration.base),
            curve: AppMotion.curve(context, Curves.easeOutCubic),
            decoration: BoxDecoration(
              color: isSelected
                  ? categoryColor.withValues(alpha: 0.16)
                  : scheme.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: isSelected ? categoryColor : scheme.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(category.icon, color: categoryColor, size: 28),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  category.displayName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? categoryColor : scheme.ink,
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
