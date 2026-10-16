import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/models/category.dart';
import 'package:spendsmart/models/custom_category.dart';
import 'package:spendsmart/models/expense.dart';
import 'package:spendsmart/services/expense_category_resolver.dart';

void main() {
  final subscriptions = CustomCategory(
    id: 'subscriptions',
    name: 'Subscriptions',
    iconCodePoint: Icons.repeat.codePoint,
    colorValue: 0xFF9AB8EE,
  );

  Expense expense({
    Category category = Category.other,
    String? customCategoryId,
    double amount = 10,
    bool isUncategorized = false,
  }) =>
      Expense(
        id: '${amount}_${customCategoryId ?? category.name}',
        title: 'Test expense',
        amount: amount,
        category: category,
        date: DateTime(2026, 1, 1),
        isManual: true,
        isUncategorized: isUncategorized,
        source: 'test',
        customCategoryId: customCategoryId,
      );

  test('resolves custom categories without collapsing them into Other', () {
    final catalog = ExpenseCategoryCatalog([subscriptions]);
    final resolved = catalog.resolve(
      expense(customCategoryId: subscriptions.id),
    );

    expect(resolved.label, 'Subscriptions');
    expect(resolved.isCustom, isTrue);
    expect(resolved.key, ExpenseCategoryKey.custom('subscriptions'));
    expect(resolved.icon, Icons.repeat);
  });

  test('groups built-in and custom categories by stable identity', () {
    final catalog = ExpenseCategoryCatalog([subscriptions]);
    final totals = catalog.sumByCategory([
      expense(category: Category.other, customCategoryId: subscriptions.id),
      expense(category: Category.other, customCategoryId: subscriptions.id, amount: 5),
      expense(category: Category.food, amount: 20),
    ]);

    expect(totals[ExpenseCategoryKey.custom('subscriptions')], 15);
    expect(totals[ExpenseCategoryKey.builtIn(Category.food)], 20);
    expect(totals.containsKey(ExpenseCategoryKey.builtIn(Category.other)), isFalse);
  });

  test('follows a merged category and safely falls back for missing ids', () {
    final source = CustomCategory(
      id: 'old',
      name: 'Old name',
      iconCodePoint: Icons.category.codePoint,
      colorValue: 0xFF112233,
      archived: true,
      mergedIntoId: 'new',
    );
    final destination = CustomCategory(
      id: 'new',
      name: 'New name',
      iconCodePoint: Icons.star.codePoint,
      colorValue: 0xFF445566,
    );
    final catalog = ExpenseCategoryCatalog([source, destination]);

    expect(
      catalog.labelOf(expense(customCategoryId: 'old')),
      'New name',
    );
    final missing = catalog.resolve(expense(customCategoryId: 'missing'));
    expect(missing.label, 'Other');
    expect(missing.missingReference, isTrue);
  });

  test('keeps uncategorized separate from category resolution', () {
    final catalog = ExpenseCategoryCatalog([subscriptions]);
    final totals = catalog.sumByCategory([
      expense(category: Category.food, isUncategorized: true),
      expense(category: Category.food, amount: 7),
    ]);

    expect(totals[ExpenseCategoryKey.builtIn(Category.food)], 7);
  });
}
