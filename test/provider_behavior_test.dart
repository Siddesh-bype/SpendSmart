import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
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

  test(
    'a legacy spendingMilestone payload decodes to tip instead of throwing',
    () async {
      SharedPreferences.setMockInitialValues({
        'app_notifications_v1': jsonEncode([
          {
            'id': 'legacy',
            'title': 'Milestone reached',
            'body': 'Old milestone body',
            'time': DateTime(2026, 7, 10).toIso8601String(),
            // Stable id 2 belonged to the removed spendingMilestone variant.
            'type': 2,
            'isRead': false,
          },
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifications = container.read(notificationProvider);

      expect(notifications, hasLength(1));
      expect(notifications.single.type, NotifType.tip);
    },
  );

  group('per-group "this is me" identity', () {
    SplitGroup trip() => SplitGroup(
      id: 'trip',
      name: 'Trip',
      participants: [
        Participant(id: 'a', name: 'Asha', avatarColorValue: 0xFF123B5D),
        Participant(id: 'b', name: 'Ben', avatarColorValue: 0xFF0F766E),
      ],
      createdAt: DateTime(2026),
    );

    // Ben paid 100, split 50/50 → Asha -50, Ben +50.
    List<GroupExpense> expenses() => [
      GroupExpense(
        id: 'e1',
        groupId: 'trip',
        description: 'Hotel',
        totalAmount: 100,
        paidBy: 'b',
        shares: [
          ParticipantShare(participantId: 'a', amount: 50),
          ParticipantShare(participantId: 'b', amount: 50),
        ],
        date: DateTime(2026),
      ),
    ];

    Map<String, double> balancesFor(SplitGroup g, List<GroupExpense> ex) {
      final paid = {for (final p in g.participants) p.id: 0.0};
      final owed = {for (final p in g.participants) p.id: 0.0};
      for (final e in ex) {
        paid[e.paidBy] = (paid[e.paidBy] ?? 0) + e.totalAmount;
        for (final s in e.shares) {
          owed[s.participantId] = (owed[s.participantId] ?? 0) + s.amount;
        }
      }
      return {for (final p in g.participants) p.id: paid[p.id]! - owed[p.id]!};
    }

    double myNet(SplitGroup g, Map<String, double> b) =>
        b[g.meParticipantId] ?? 0;

    test('default-null behaves as today: first participant is me', () {
      final g = trip();
      expect(g.myParticipantId, isNull);
      expect(g.meParticipantId, 'a');
      expect(myNet(g, balancesFor(g, expenses())), -50);
    });

    test('setting me changes the net direction', () async {
      final storage = _FakeStorage(groups: [trip()]);
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      await container
          .read(splitGroupProvider.notifier)
          .setMyParticipant('trip', 'b');

      final updated = container.read(splitGroupProvider).single;
      expect(updated.myParticipantId, 'b');
      expect(myNet(updated, balancesFor(updated, expenses())), 50);
    });

    test('switching me mid-group works and unknown ids are ignored', () async {
      final storage = _FakeStorage(groups: [trip()]);
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(splitGroupProvider.notifier);

      await notifier.setMyParticipant('trip', 'b');
      expect(container.read(splitGroupProvider).single.myParticipantId, 'b');

      await notifier.setMyParticipant('trip', 'a');
      final back = container.read(splitGroupProvider).single;
      expect(back.myParticipantId, 'a');
      expect(myNet(back, balancesFor(back, expenses())), -50);

      // Unknown participant / group: state untouched.
      await notifier.setMyParticipant('trip', 'ghost');
      await notifier.setMyParticipant('nope', 'a');
      expect(container.read(splitGroupProvider).single.myParticipantId, 'a');
    });

    test('a stored id that no longer names a member falls back to first', () {
      final g = trip()..myParticipantId = 'removed';
      expect(g.meParticipantId, 'a');
    });

    test('legacy payload without field 4 loads with null me', () {
      final date = DateTime(2026);
      final legacy = _StubReader([
        4,
        0, 'trip',
        1, 'Trip',
        2, [
          {'id': 'a', 'name': 'Asha', 'avatarColorValue': 0xFF123B5D},
          {'id': 'b', 'name': 'Ben', 'avatarColorValue': 0xFF0F766E},
        ],
        3, date,
      ]);
      final g = SplitGroupAdapter().read(legacy);
      expect(g.myParticipantId, isNull);
      expect(g.meParticipantId, 'a');
      expect(g.participants, hasLength(2));
    });

    test('new payload with field 4 round-trips the me pick', () {
      final date = DateTime(2026);
      final reader = _StubReader([
        5,
        0, 'trip',
        1, 'Trip',
        2, [
          {'id': 'a', 'name': 'Asha', 'avatarColorValue': 0xFF123B5D},
          {'id': 'b', 'name': 'Ben', 'avatarColorValue': 0xFF0F766E},
        ],
        3, date,
        4, 'b',
      ]);
      final g = SplitGroupAdapter().read(reader);
      expect(g.myParticipantId, 'b');
      expect(g.meParticipantId, 'b');
    });
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
  Future<void> saveSplitGroup(SplitGroup group) async {
    groups.removeWhere((g) => g.id == group.id);
    groups.add(group);
  }

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

/// Serves canned tokens to [SplitGroupAdapter.read] in the exact order the
/// adapter pulls them (readByte/read interleaved), simulating raw Hive
/// payloads without needing a Hive box on disk.
class _StubReader implements BinaryReader {
  _StubReader(this.tokens);

  final List<Object?> tokens;
  int _i = 0;

  @override
  int readByte() => tokens[_i++] as int;

  @override
  dynamic read([int? typeId]) => tokens[_i++];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
