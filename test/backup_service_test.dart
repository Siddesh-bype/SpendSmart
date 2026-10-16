import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendsmart/models/budget.dart';
import 'package:spendsmart/models/category.dart';
import 'package:spendsmart/models/custom_category.dart';
import 'package:spendsmart/models/expense.dart';
import 'package:spendsmart/models/group_expense.dart';
import 'package:spendsmart/models/income.dart';
import 'package:spendsmart/models/lending.dart';
import 'package:spendsmart/models/merchant_memory.dart';
import 'package:spendsmart/models/recurring_expense.dart';
import 'package:spendsmart/models/split_group.dart';
import 'package:spendsmart/services/backup_service.dart';
import 'package:spendsmart/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;
  late SharedPreferences prefs;
  late BackupService service;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('spendsmart_backup_');
    Hive.init(tempDir.path);
    Hive.registerAdapter(CategoryAdapter());
    Hive.registerAdapter(ExpenseAdapter());
    Hive.registerAdapter(MerchantMemoryAdapter());
    Hive.registerAdapter(BudgetAdapter());
    Hive.registerAdapter(IncomeAdapter());
    Hive.registerAdapter(LendingAdapter());
    Hive.registerAdapter(RecurringExpenseAdapter());
    Hive.registerAdapter(SplitGroupAdapter());
    Hive.registerAdapter(GroupExpenseAdapter());
    Hive.registerAdapter(CustomCategoryAdapter());
    await Hive.openBox<Expense>(StorageService.expenseBoxName);
    await Hive.openBox<MerchantMemory>(StorageService.merchantBoxName);
    await Hive.openBox<Budget>(StorageService.budgetBoxName);
    await Hive.openBox<Lending>(StorageService.lendingBoxName);
    await Hive.openBox<Income>(StorageService.incomeBoxName);
    await Hive.openBox<RecurringExpense>(StorageService.recurringBoxName);
    await Hive.openBox<SplitGroup>(StorageService.splitGroupBoxName);
    await Hive.openBox<GroupExpense>(StorageService.groupExpenseBoxName);
    await Hive.openBox<CustomCategory>(StorageService.customCategoryBoxName);
    storage = StorageService();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = BackupService(storage: storage, preferences: prefs);
  });

  tearDown(() async {
    await storage.clearAllData();
    await prefs.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('rejects unsupported backup versions', () {
    final json = _snapshot().toJson();
    json['version'] = BackupSnapshot.version + 1;

    expect(
      () => BackupService.parse(jsonEncode(json)),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('rejects an incomplete schema before changing local data', () async {
    await storage.saveExpense(_expense('existing', 'Keep me'));
    final json = _snapshot().toJson();
    (json['datasets'] as Map<String, dynamic>).remove(
      StorageService.groupExpenseBoxName,
    );

    expect(
      () => BackupService.parse(jsonEncode(json)),
      throwsA(isA<BackupFormatException>()),
    );
    expect(storage.getAllExpenses().single.title, 'Keep me');
  });

  test('serializes and restores all datasets and preferences in memory', () {
    final original = _snapshot();
    final restored = BackupSnapshot.fromJson(original.toJson());

    expect(restored.expenses.single.title, 'Coffee');
    expect(restored.expenses.single.customCategoryId, 'cat-1');
    expect(restored.merchants['coffee']!.usageCount, 2);
    expect(restored.budgets['0']!.monthlyLimit, 500);
    expect(restored.lendings['lend-1']!.isSettled, isTrue);
    expect(restored.incomes['income-1']!.source, 'Work');
    expect(restored.recurringExpenses['rule-1']!.frequency, 'monthly');
    expect(restored.splitGroups['group-1']!.participants, hasLength(1));
    expect(restored.groupExpenses['group-expense-1']!.shares, hasLength(1));
    expect(restored.customCategories['cat-1']!.name, 'Subscriptions');
    expect(restored.preferences['currency'], r'$');
    expect(restored.preferences['daily_goals'], contains('2026-01-01'));
  });

  test('rejects malformed JSON before changing local data', () async {
    final existing = _expense('existing', 'Existing');
    await storage.saveExpense(existing);

    await expectLater(
      service.restoreJson('{"format":"spendsmart-backup"'),
      throwsA(isA<BackupFormatException>()),
    );
    expect(storage.getAllExpenses().map((value) => value.id), ['existing']);
  });

  test('rejects malformed preference JSON before changing local data', () async {
    await storage.saveExpense(_expense('existing', 'Keep me'));
    final json = _snapshot().toJson();
    (json['preferences'] as Map<String, dynamic>)['daily_goals'] = '{bad';

    expect(
      () => BackupService.parse(jsonEncode(json)),
      throwsA(isA<BackupFormatException>()),
    );
    expect(storage.getAllExpenses().single.title, 'Keep me');
  });

  test('rejects duplicate logical expense ids before restore', () {
    final json = _snapshot().toJson();
    final datasets = json['datasets'] as Map<String, dynamic>;
    final entries = datasets[StorageService.expenseBoxName] as List<dynamic>;
    entries.add({
      'key': 'different-entry-key',
      'value': Map<String, dynamic>.from(entries.first['value'] as Map),
    });

    expect(
      () => BackupService.parse(jsonEncode(json)),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('rejects null notification read state', () {
    final json = _snapshot().toJson();
    final preferences = json['preferences'] as Map<String, dynamic>;
    preferences['app_notifications_v1'] = jsonEncode([
      {
        'id': 'notification-1',
        'title': 'Budget warning',
        'body': 'Review your spending',
        'time': DateTime.utc(2026, 1, 1).toIso8601String(),
        'type': 0,
        'isRead': null,
      },
    ]);

    expect(
      () => BackupService.parse(jsonEncode(json)),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('accepts notifications in the shape the app stores them', () {
    final json = _snapshot().toJson();
    final preferences = json['preferences'] as Map<String, dynamic>;
    final notification = {
      'id': 'notification-1',
      'title': 'Budget warning',
      'body': 'Review your spending',
      'time': DateTime.utc(2026, 1, 1).toIso8601String(),
      'type': 0,
      'isRead': false,
    };
    preferences['app_notifications_v1'] = jsonEncode([
      {...notification, 'categoryKey': null},
      {...notification, 'id': 'notification-2', 'categoryKey': 'builtIn:0'},
    ]);

    expect(() => BackupService.parse(jsonEncode(json)), returnsNormally);
  });

  test(
    'createSnapshot includes all Hive datasets and used preferences',
    () async {
      await service.restore(_snapshot());

      final snapshot = await service.createSnapshot();

      expect(snapshot.expenses, hasLength(1));
      expect(snapshot.merchants, hasLength(1));
      expect(snapshot.budgets, hasLength(1));
      expect(snapshot.lendings, hasLength(1));
      expect(snapshot.incomes, hasLength(1));
      expect(snapshot.recurringExpenses, hasLength(1));
      expect(snapshot.splitGroups, hasLength(1));
      expect(snapshot.groupExpenses, hasLength(1));
      expect(
        snapshot.preferences.keys,
        containsAll([
          'currency',
          'goal_enabled',
          'daily_goals',
          'app_notifications_v1',
        ]),
      );
    },
  );

  test(
    'merge restore skips duplicate keys and inserts fresh records',
    () async {
      await storage.saveExpense(_expense('same-id', 'Keep local'));
      final snapshot = BackupSnapshot(
        createdAt: DateTime.utc(2026, 1, 1),
        expenses: [
          _expense('same-id', 'Do not overwrite'),
          _expense('new-id', 'Insert this'),
        ],
        merchants: const {},
        budgets: const {},
        lendings: const {},
        incomes: const {},
        recurringExpenses: const {},
        splitGroups: const {},
        groupExpenses: const {},
        customCategories: const {},
        preferences: const {},
      );

      final result = await service.restore(snapshot);

      expect(result.inserted[StorageService.expenseBoxName], 1);
      expect(result.skipped[StorageService.expenseBoxName], 1);
      expect(storage.expenseBox.values, hasLength(2));
      expect(storage.expenseBox.get('same-id')!.title, 'Keep local');
    },
  );
}

Expense _expense(String id, String title) => Expense(
  id: id,
  title: title,
  amount: 12.5,
  category: Category.food,
  date: DateTime.utc(2026, 1, 1),
  note: 'offline test',
  isManual: true,
  isUncategorized: false,
  source: 'test',
);

BackupSnapshot _snapshot() => BackupSnapshot(
  createdAt: DateTime.utc(2026, 1, 2),
  expenses: [
    _expense('expense-1', 'Coffee').copyWith(customCategoryId: 'cat-1'),
  ],
  merchants: {
    'coffee': MerchantMemory(
      merchantName: 'Coffee Shop',
      category: Category.food,
      usageCount: 2,
      lastUsed: DateTime.utc(2026, 1, 1),
    ),
  },
  budgets: {
    '0': Budget(category: Category.food, monthlyLimit: 500, alertAt: 0.8),
  },
  lendings: {
    'lend-1': Lending(
      id: 'lend-1',
      friendName: 'Friend',
      amount: 20,
      isIGave: true,
      date: DateTime.utc(2026, 1, 1),
      isSettled: true,
    ),
  },
  incomes: {
    'income-1': Income(
      id: 'income-1',
      amount: 100,
      source: 'Work',
      date: DateTime.utc(2026, 1, 1),
    ),
  },
  recurringExpenses: {
    'rule-1': RecurringExpense(
      id: 'rule-1',
      title: 'Rent',
      amount: 50,
      category: Category.bills,
      frequency: 'monthly',
      startDate: DateTime.utc(2026, 1, 1),
      nextDue: DateTime.utc(2026, 2, 1),
    ),
  },
  splitGroups: {
    'group-1': SplitGroup(
      id: 'group-1',
      name: 'Trip',
      participants: [
        Participant(id: 'me', name: 'Me', avatarColorValue: 0xFF123456),
      ],
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  },
  groupExpenses: {
    'group-expense-1': GroupExpense(
      id: 'group-expense-1',
      groupId: 'group-1',
      description: 'Hotel',
      totalAmount: 20,
      paidBy: 'me',
      shares: [ParticipantShare(participantId: 'me', amount: 20)],
      date: DateTime.utc(2026, 1, 1),
    ),
  },
  customCategories: {
    'cat-1': CustomCategory(
      id: 'cat-1',
      name: 'Subscriptions',
      iconCodePoint: Icons.repeat.codePoint,
      colorValue: 0xFF9AB8EE,
    ),
  },
  preferences: {
    'currency': r'$',
    'goal_enabled': true,
    'daily_goals': '{"2026-01-01":25}',
    'app_notifications_v1': '[]',
  },
);
