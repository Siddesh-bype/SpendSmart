import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendsmart/models/app_notification.dart';
import 'package:spendsmart/models/budget.dart';
import 'package:spendsmart/models/category.dart';
import 'package:spendsmart/models/expense.dart';
import 'package:spendsmart/models/group_expense.dart';
import 'package:spendsmart/models/split_group.dart';
import 'package:spendsmart/providers/app_settings_provider.dart';
import 'package:spendsmart/providers/expense_provider.dart';
import 'package:spendsmart/providers/group_provider.dart';
import 'package:spendsmart/providers/notification_provider.dart';
import 'package:spendsmart/providers/service_provider.dart';
import 'package:spendsmart/services/storage_service.dart';

Expense _expense(String id, String title) => Expense(
  id: id,
  title: title,
  amount: 100,
  category: Category.food,
  date: DateTime(2026, 7, 10),
  isManual: true,
  isUncategorized: false,
  source: 'test',
);

void main() {
  test(
    'batch import returns inserted count and removes batch duplicates',
    () async {
      final storage = _FakeStorage(expenses: [_expense('existing', 'Coffee')]);
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final inserted = await container
          .read(expenseProvider.notifier)
          .importExpenses([
            _expense('duplicate', 'Coffee'),
            _expense('new', 'Lunch'),
            _expense('new-again', 'Lunch'),
          ]);

      expect(inserted, 1);
      expect(storage.expenses.map((e) => e.title), ['Coffee', 'Lunch']);
    },
  );

  test('an imported id that collides with a stored one is regenerated', () async {
    final existing = _expense('shared-id', 'Coffee');
    final storage = _FakeStorage(expenses: [existing]);
    final container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    // Same id, different content: a hand-edited or re-exported CSV. Storage is
    // keyed by id, so without the guard this overwrites the coffee expense.
    final inserted = await container
        .read(expenseProvider.notifier)
        .importExpenses([_expense('shared-id', 'Lunch')]);

    expect(inserted, 1);
    expect(storage.expenses.length, 2);
    expect(
      storage.expenses.singleWhere((e) => e.id == 'shared-id').title,
      'Coffee',
    );
    expect(storage.expenses.map((e) => e.title), containsAll(['Coffee', 'Lunch']));
  });

  test('regenerating a recurring occurrence is a no-op', () async {
    final storage = _FakeStorage();
    final container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(expenseProvider.notifier);

    // Deterministic occurrence ids: the same rule and due date twice, as
    // happens when a generation run is killed between the two writes.
    final occurrence = _expense('recurring:rent:2026-07-01', 'Rent');
    expect(await notifier.addMissingById([occurrence]), 1);
    expect(await notifier.addMissingById([occurrence]), 0);
    expect(storage.expenses, hasLength(1));
  });

  test('deleting a group also removes its expenses', () async {
    final group = SplitGroup(
      id: 'group',
      name: 'Trip',
      participants: [
        Participant(id: 'me', name: 'Me', avatarColorValue: 0xFF123B5D),
      ],
      createdAt: DateTime(2026),
    );
    final storage = _FakeStorage(
      groups: [group],
      groupExpenses: [
        GroupExpense(
          id: 'expense',
          groupId: group.id,
          description: 'Hotel',
          totalAmount: 500,
          paidBy: 'me',
          shares: [ParticipantShare(participantId: 'me', amount: 500)],
          date: DateTime(2026),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    await container.read(splitGroupProvider.notifier).deleteGroup(group.id);

    expect(storage.groups, isEmpty);
    expect(storage.groupExpenses, isEmpty);
  });

  test(
    'budget warning from a previous month does not block a new warning',
    () async {
      final previousMonth = DateTime.now().subtract(const Duration(days: 40));
      SharedPreferences.setMockInitialValues({
        'app_notifications_v1': jsonEncode([
          {
            'id': 'old',
            'title': 'Budget Warning: Food',
            'body': 'Old warning',
            'time': previousMonth.toIso8601String(),
            'type': NotifType.budgetWarning.index,
            'isRead': true,
          },
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      container
          .read(notificationProvider.notifier)
          .checkBudgets(
            [Budget(category: Category.food, monthlyLimit: 100)],
            {Category.food: 90},
          );

      expect(container.read(notificationProvider), hasLength(2));
    },
  );

  test('an expired AI session is not treated as access', () async {
    SharedPreferences.setMockInitialValues({
      'aiAccountEmail': 'user@example.com',
      'aiSessionExpiresAt': DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialSessionTokenProvider.overrideWithValue('stale-token'),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(appSettingsProvider).hasAiAccess, isFalse);
  });

  test('a session with no expiry is trusted until the server says otherwise', () async {
    SharedPreferences.setMockInitialValues({'aiSessionExpiresAt': 0});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialSessionTokenProvider.overrideWithValue('live-token'),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(appSettingsProvider).hasAiAccess, isTrue);
  });
}

class _FakeStorage extends StorageService {
  _FakeStorage({
    List<Expense>? expenses,
    List<SplitGroup>? groups,
    List<GroupExpense>? groupExpenses,
  }) : expenses = expenses ?? [],
       groups = groups ?? [],
       groupExpenses = groupExpenses ?? [];

  final List<Expense> expenses;
  final List<SplitGroup> groups;
  final List<GroupExpense> groupExpenses;

  @override
  List<Expense> getAllExpenses() => List.of(expenses);

  @override
  Future<void> saveExpense(Expense expense) async {
    expenses.removeWhere((e) => e.id == expense.id);
    expenses.add(expense);
  }

  @override
  Future<void> saveExpenses(Iterable<Expense> toSave) async {
    for (final e in toSave) {
      await saveExpense(e);
    }
  }

  @override
  List<SplitGroup> getAllSplitGroups() => List.of(groups);

  @override
  List<GroupExpense> getAllGroupExpenses() => List.of(groupExpenses);

  @override
  Future<void> deleteGroupExpense(String id) async {
    groupExpenses.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> deleteSplitGroup(String id) async {
    groups.removeWhere((g) => g.id == id);
  }
}
