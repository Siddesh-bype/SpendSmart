import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:spendsmart/models/budget.dart';
import 'package:spendsmart/models/category.dart';
import 'package:spendsmart/models/expense.dart';
import 'package:spendsmart/models/group_expense.dart';
import 'package:spendsmart/models/income.dart';
import 'package:spendsmart/models/lending.dart';
import 'package:spendsmart/models/merchant_memory.dart';
import 'package:spendsmart/models/recurring_expense.dart';
import 'package:spendsmart/models/split_group.dart';
import 'package:spendsmart/services/storage_service.dart';

// Real Hive boxes in a temp dir: seed one record per box, wipe, expect empty.
void main() {
  late Directory tempDir;
  late StorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wipe_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CategoryAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ExpenseAdapter());
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(MerchantMemoryAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(BudgetAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(IncomeAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(LendingAdapter());
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(RecurringExpenseAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(SplitGroupAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(GroupExpenseAdapter());
    }

    await Hive.openBox<Expense>(StorageService.expenseBoxName);
    await Hive.openBox<MerchantMemory>(StorageService.merchantBoxName);
    await Hive.openBox<Budget>(StorageService.budgetBoxName);
    await Hive.openBox<Lending>(StorageService.lendingBoxName);
    await Hive.openBox<Income>(StorageService.incomeBoxName);
    await Hive.openBox<RecurringExpense>(StorageService.recurringBoxName);
    await Hive.openBox<SplitGroup>(StorageService.splitGroupBoxName);
    await Hive.openBox<GroupExpense>(StorageService.groupExpenseBoxName);

    storage = StorageService();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> seedAll() async {
    final now = DateTime(2026, 7, 10);
    await storage.expenseBox.put(
      'e1',
      Expense(
        id: 'e1',
        title: 'Coffee',
        amount: 100,
        category: Category.food,
        date: now,
        isManual: true,
        isUncategorized: false,
        source: 'test',
      ),
    );
    await storage.merchantBox.put(
      'coffee',
      MerchantMemory(
        merchantName: 'Coffee',
        category: Category.food,
        lastUsed: now,
      ),
    );
    await storage.budgetBox.put(
      0,
      Budget(category: Category.food, monthlyLimit: 1000),
    );
    await storage.lendingBox.put(
      'l1',
      Lending(
        id: 'l1',
        friendName: 'Sam',
        amount: 50,
        isIGave: true,
        date: now,
      ),
    );
    await storage.incomeBox.put(
      'i1',
      Income(id: 'i1', amount: 5000, source: 'Salary', date: now),
    );
    await storage.recurringBox.put(
      'r1',
      RecurringExpense(
        id: 'r1',
        title: 'Rent',
        amount: 9000,
        category: Category.bills,
        frequency: 'monthly',
        startDate: now,
        nextDue: now,
      ),
    );
    await storage.splitGroupBox.put(
      'g1',
      SplitGroup(
        id: 'g1',
        name: 'Trip',
        participants: [
          Participant(id: 'me', name: 'Me', avatarColorValue: 0xFF123B5D),
        ],
        createdAt: now,
      ),
    );
    await storage.groupExpenseBox.put(
      'ge1',
      GroupExpense(
        id: 'ge1',
        groupId: 'g1',
        description: 'Hotel',
        totalAmount: 500,
        paidBy: 'me',
        shares: [ParticipantShare(participantId: 'me', amount: 500)],
        date: now,
      ),
    );
  }

  test('wipe clears all seeded boxes', () async {
    await seedAll();
    expect(storage.expenseBox.isNotEmpty, isTrue);
    expect(storage.groupExpenseBox.isNotEmpty, isTrue);

    await storage.clearAllData();

    expect(storage.expenseBox.isEmpty, isTrue);
    expect(storage.merchantBox.isEmpty, isTrue);
    expect(storage.budgetBox.isEmpty, isTrue);
    expect(storage.lendingBox.isEmpty, isTrue);
    expect(storage.incomeBox.isEmpty, isTrue);
    expect(storage.recurringBox.isEmpty, isTrue);
    expect(storage.splitGroupBox.isEmpty, isTrue);
    expect(storage.groupExpenseBox.isEmpty, isTrue);
  });

  test('wipe on empty boxes succeeds without throwing', () async {
    await storage.clearAllData();

    expect(storage.expenseBox.isEmpty, isTrue);
    expect(storage.groupExpenseBox.isEmpty, isTrue);
  });
}
