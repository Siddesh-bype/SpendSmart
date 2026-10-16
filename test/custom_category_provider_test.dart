import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:spendsmart/models/category.dart';
import 'package:spendsmart/models/budget.dart';
import 'package:spendsmart/models/custom_category.dart';
import 'package:spendsmart/models/expense.dart';
import 'package:spendsmart/providers/custom_category_provider.dart';
import 'package:spendsmart/providers/service_provider.dart';
import 'package:spendsmart/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('spendsmart_categories_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CategoryAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ExpenseAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(BudgetAdapter());
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(CustomCategoryAdapter());
    }
    await Hive.openBox<Expense>(StorageService.expenseBoxName);
    await Hive.openBox<Budget>(StorageService.budgetBoxName);
    await Hive.openBox<CustomCategory>(StorageService.customCategoryBoxName);
    storage = StorageService();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  ProviderContainer container() => ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );

  CustomCategory category(String id, String name) => CustomCategory(
        id: id,
        name: name,
        iconCodePoint: 0xe3b0,
        colorValue: 0xFF9AB8EE,
      );

  Expense expense(String id, String? customCategoryId) => Expense(
        id: id,
        title: 'Expense',
        amount: 12,
        category: Category.other,
        date: DateTime(2026, 1, 1),
        isManual: true,
        isUncategorized: false,
        source: 'test',
        customCategoryId: customCategoryId,
      );

  test('adds, renames, and archives a custom category', () async {
    final ref = container();
    addTearDown(ref.dispose);
    final notifier = ref.read(customCategoryProvider.notifier);

    await notifier.add(name: '  Subscriptions  ');
    final created = ref.read(customCategoryProvider).single;
    expect(created.name, 'Subscriptions');

    await notifier.rename(created, 'Recurring');
    expect(ref.read(customCategoryProvider).single.name, 'Recurring');

    await notifier.archive(ref.read(customCategoryProvider).single);
    expect(ref.read(customCategoryProvider).single.archived, isTrue);
    expect(storage.getAllCustomCategories().single.name, 'Recurring');
  });

  test('rejects duplicate active names case-insensitively', () async {
    final ref = container();
    addTearDown(ref.dispose);
    final notifier = ref.read(customCategoryProvider.notifier);
    await notifier.add(name: 'Subscriptions');

    await expectLater(
      notifier.add(name: ' subscriptions '),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('merge migrates linked expenses and archives the source', () async {
    final source = category('source', 'Old');
    final destination = category('destination', 'New');
    await storage.saveCustomCategory(source);
    await storage.saveCustomCategory(destination);
    await storage.saveExpense(expense('linked', source.id));
    await storage.saveExpense(expense('unrelated', null));
    await storage.saveBudget(
      Budget(
        category: Category.other,
        customCategoryId: source.id,
        monthlyLimit: 100,
      ),
    );

    final ref = container();
    addTearDown(ref.dispose);
    await ref.read(customCategoryProvider.notifier).merge(source, destination);

    expect(
      storage.expenseBox.get('linked')!.customCategoryId,
      destination.id,
    );
    final merged = storage.customCategoryBox.get(source.id)!;
    expect(merged.archived, isTrue);
    expect(merged.mergedIntoId, destination.id);
    final migratedBudget = storage.getAllBudgets().single;
    expect(migratedBudget.customCategoryId, destination.id);
    expect(migratedBudget.monthlyLimit, 100);
  });

  test('rejects a merge that would create a loop', () async {
    final source = category('source', 'Old');
    final destination = category('destination', 'New');
    destination.mergedIntoId = source.id;
    await storage.saveCustomCategory(source);
    await storage.saveCustomCategory(destination);

    final ref = container();
    addTearDown(ref.dispose);
    await expectLater(
      ref.read(customCategoryProvider.notifier).merge(source, destination),
      throwsA(isA<ArgumentError>()),
    );
  });
}
