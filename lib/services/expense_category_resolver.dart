import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/custom_category.dart';
import '../models/expense.dart';

/// A stable category identity that is safe to use for grouping and filtering.
///
/// Display names are deliberately not used as keys: a custom category may be
/// called "Food" without being the built-in Food category.
class ExpenseCategoryKey {
  const ExpenseCategoryKey.builtIn(Category category)
      : builtIn = category,
        customCategoryId = null;

  const ExpenseCategoryKey.custom(String id)
      : builtIn = null,
        customCategoryId = id;

  final Category? builtIn;
  final String? customCategoryId;

  bool get isCustom => customCategoryId != null;

  String get storageKey => isCustom
      ? 'custom:$customCategoryId'
      : 'builtIn:${builtIn!.index}';

  @override
  bool operator ==(Object other) =>
      other is ExpenseCategoryKey &&
      other.builtIn == builtIn &&
      other.customCategoryId == customCategoryId;

  @override
  int get hashCode => Object.hash(builtIn, customCategoryId);
}

class ResolvedExpenseCategory {
  const ResolvedExpenseCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    this.builtInCategory,
    this.customCategoryId,
    this.missingReference = false,
  });

  final ExpenseCategoryKey key;
  final String label;
  final IconData icon;
  final Color color;
  final Category? builtInCategory;
  final String? customCategoryId;
  final bool missingReference;

  bool get isCustom => customCategoryId != null;
}

/// Resolves persisted expenses without coupling UI or export code to Hive.
///
/// The resolver follows a merge target defensively. This keeps old expenses
/// readable after a category merge and prevents malformed backup data from
/// creating an infinite loop.
class ExpenseCategoryCatalog {
  ExpenseCategoryCatalog(Iterable<CustomCategory> categories)
      : _categories = {
          for (final category in categories) category.id: category,
        };

  const ExpenseCategoryCatalog.empty() : _categories = const {};

  final Map<String, CustomCategory> _categories;

  List<CustomCategory> get customCategories => _categories.values.toList();

  CustomCategory? customById(String id) => _categories[id];

  ResolvedExpenseCategory resolve(Expense expense) {
    final customId = expense.customCategoryId;
    if (customId != null) {
      final resolvedCustom = _resolveCustom(customId);
      if (resolvedCustom != null) return resolvedCustom;
      return _builtIn(expense.category, missingReference: true);
    }
    return _builtIn(expense.category);
  }

  ResolvedExpenseCategory? resolveKey(ExpenseCategoryKey key) {
    if (key.customCategoryId != null) {
      return _resolveCustom(key.customCategoryId!);
    }
    final category = key.builtIn;
    return category == null ? null : _builtIn(category);
  }

  ExpenseCategoryKey keyOf(Expense expense) => resolve(expense).key;

  String labelOf(Expense expense) => resolve(expense).label;

  bool matches(Expense expense, ExpenseCategoryKey? selected) =>
      selected == null || keyOf(expense) == selected;

  Map<ExpenseCategoryKey, double> sumByCategory(
    Iterable<Expense> expenses, {
    bool includeUncategorized = false,
  }) {
    final totals = <ExpenseCategoryKey, double>{};
    for (final expense in expenses) {
      if (!includeUncategorized && expense.isUncategorized) continue;
      final key = keyOf(expense);
      totals[key] = (totals[key] ?? 0) + expense.amount;
    }
    return totals;
  }

  List<ResolvedExpenseCategory> get selectableCategories => [
        ...Category.values.map(_builtIn),
        ..._categories.values
            .where((category) => !category.archived)
            .map(_custom),
      ];

  ResolvedExpenseCategory? _resolveCustom(String id) {
    final visited = <String>{};
    var current = id;
    while (visited.add(current)) {
      final category = _categories[current];
      if (category == null) return null;
      final next = category.mergedIntoId;
      if (next == null || next == current) return _custom(category);
      current = next;
    }
    return null;
  }

  ResolvedExpenseCategory _custom(CustomCategory category) =>
      ResolvedExpenseCategory(
        key: ExpenseCategoryKey.custom(category.id),
        label: category.name,
        icon: category.icon,
        color: category.color,
        customCategoryId: category.id,
      );

  ResolvedExpenseCategory _builtIn(
    Category category, {
    bool missingReference = false,
  }) =>
      ResolvedExpenseCategory(
        key: ExpenseCategoryKey.builtIn(category),
        label: category.displayName,
        icon: category.icon,
        color: category.color,
        builtInCategory: category,
        missingReference: missingReference,
      );
}
