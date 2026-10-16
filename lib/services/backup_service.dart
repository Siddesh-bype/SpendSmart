import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget.dart';
import '../models/category.dart';
import '../models/custom_category.dart';
import '../models/expense.dart';
import '../models/group_expense.dart';
import '../models/income.dart';
import '../models/lending.dart';
import '../models/merchant_memory.dart';
import '../models/recurring_expense.dart';
import '../models/split_group.dart';
import 'storage_service.dart';

/// Thrown when a selected backup is not a supported SpendSmart backup.
class BackupFormatException implements Exception {
  final String message;

  const BackupFormatException(this.message);

  @override
  String toString() => message;
}

/// The supported, deliberately small backup format. A new incompatible format
/// must use a new version rather than being partially interpreted here.
class BackupSnapshot {
  static const format = 'spendsmart-backup';
  static const version = 1;

  static const datasetNames = [
    StorageService.expenseBoxName,
    StorageService.merchantBoxName,
    StorageService.budgetBoxName,
    StorageService.lendingBoxName,
    StorageService.incomeBoxName,
    StorageService.recurringBoxName,
    StorageService.splitGroupBoxName,
    StorageService.groupExpenseBoxName,
    StorageService.customCategoryBoxName,
  ];

  static const preferenceNames = [
    'currency',
    'monthlyBudget',
    'monthlyIncome',
    'theme',
    'onboardingDone',
    'startingDayOfMonth',
    'goal_monthly_limit',
    'goal_enabled',
    'daily_goals',
    'app_notifications_v1',
  ];

  final DateTime createdAt;
  final List<Expense> expenses;
  final Map<String, MerchantMemory> merchants;
  final Map<String, Budget> budgets;
  final Map<String, Lending> lendings;
  final Map<String, Income> incomes;
  final Map<String, RecurringExpense> recurringExpenses;
  final Map<String, SplitGroup> splitGroups;
  final Map<String, GroupExpense> groupExpenses;
  final Map<String, CustomCategory> customCategories;
  final Map<String, dynamic> preferences;

  BackupSnapshot({
    required this.createdAt,
    required List<Expense> expenses,
    required Map<String, MerchantMemory> merchants,
    required Map<String, Budget> budgets,
    required Map<String, Lending> lendings,
    required Map<String, Income> incomes,
    required Map<String, RecurringExpense> recurringExpenses,
    required Map<String, SplitGroup> splitGroups,
    required Map<String, GroupExpense> groupExpenses,
    required Map<String, CustomCategory> customCategories,
    required Map<String, dynamic> preferences,
  }) : expenses = List.unmodifiable(expenses),
       merchants = Map.unmodifiable(merchants),
       budgets = Map.unmodifiable(budgets),
       lendings = Map.unmodifiable(lendings),
       incomes = Map.unmodifiable(incomes),
       recurringExpenses = Map.unmodifiable(recurringExpenses),
       splitGroups = Map.unmodifiable(splitGroups),
       groupExpenses = Map.unmodifiable(groupExpenses),
       customCategories = Map.unmodifiable(customCategories),
       preferences = Map.unmodifiable(preferences);

  Map<String, dynamic> toJson() => {
    'format': format,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'datasets': {
      StorageService.expenseBoxName: [
        for (final value in expenses)
          {'key': value.id, 'value': _expenseToJson(value)},
      ],
      StorageService.merchantBoxName: [
        for (final entry in merchants.entries)
          {'key': entry.key, 'value': _merchantToJson(entry.value)},
      ],
      StorageService.budgetBoxName: [
        for (final entry in budgets.entries)
          {'key': entry.key, 'value': _budgetToJson(entry.value)},
      ],
      StorageService.lendingBoxName: [
        for (final entry in lendings.entries)
          {'key': entry.key, 'value': _lendingToJson(entry.value)},
      ],
      StorageService.incomeBoxName: [
        for (final entry in incomes.entries)
          {'key': entry.key, 'value': _incomeToJson(entry.value)},
      ],
      StorageService.recurringBoxName: [
        for (final entry in recurringExpenses.entries)
          {'key': entry.key, 'value': _recurringToJson(entry.value)},
      ],
      StorageService.splitGroupBoxName: [
        for (final entry in splitGroups.entries)
          {'key': entry.key, 'value': _splitGroupToJson(entry.value)},
      ],
      StorageService.groupExpenseBoxName: [
        for (final entry in groupExpenses.entries)
          {'key': entry.key, 'value': _groupExpenseToJson(entry.value)},
      ],
      StorageService.customCategoryBoxName: [
        for (final entry in customCategories.entries)
          {'key': entry.key, 'value': _customCategoryToJson(entry.value)},
      ],
    },
    'preferences': {...preferences},
  };

  factory BackupSnapshot.fromJson(Map<String, dynamic> json) {
    _requireFields(
      json,
      {'format', 'version', 'createdAt', 'datasets', 'preferences'},
      'backup',
    );
    if (json['format'] != format) {
      throw const BackupFormatException('This is not a SpendSmart backup.');
    }
    if (json['version'] != version) {
      throw const BackupFormatException(
        'This backup version is not supported.',
      );
    }

    final createdAt = _date(json['createdAt'], 'createdAt');
    final datasets = _map(json['datasets'], 'datasets');
    // Version 1 backups created before custom categories existed are still
    // valid; they simply contain no custom-category records.
    datasets.putIfAbsent(StorageService.customCategoryBoxName, () => const []);
    final expected = datasetNames.toSet();
    if (datasets.keys.toSet().length != expected.length ||
        !datasets.keys.toSet().containsAll(expected)) {
      throw const BackupFormatException('Backup datasets are incomplete.');
    }

    final preferences = _preferences(json['preferences']);
    final expenseEntries = _entries(
      datasets[StorageService.expenseBoxName],
      'expenses',
    );
    final expenses = expenseEntries
        .map((entry) => _expenseFromJson(entry.value))
        .toList();
    final merchants = _entryMap(
      datasets[StorageService.merchantBoxName],
      'merchants',
      _merchantFromJson,
    );
    final budgets = _entryMap(
      datasets[StorageService.budgetBoxName],
      'budgets',
      _budgetFromJson,
    );
    final lendings = _entryMap(
      datasets[StorageService.lendingBoxName],
      'lendings',
      _lendingFromJson,
    );
    final incomes = _entryMap(
      datasets[StorageService.incomeBoxName],
      'incomes',
      _incomeFromJson,
    );
    final recurringExpenses = _entryMap(
      datasets[StorageService.recurringBoxName],
      'recurring_expenses',
      _recurringFromJson,
    );
    final splitGroups = _entryMap(
      datasets[StorageService.splitGroupBoxName],
      'split_groups',
      _splitGroupFromJson,
    );
    final groupExpenses = _entryMap(
      datasets[StorageService.groupExpenseBoxName],
      'group_expenses',
      _groupExpenseFromJson,
    );
    final customCategories = _entryMap(
      datasets[StorageService.customCategoryBoxName],
      'custom_categories',
      _customCategoryFromJson,
    );
    final snapshot = BackupSnapshot(
      createdAt: createdAt,
      expenses: expenses,
      merchants: merchants,
      budgets: budgets,
      lendings: lendings,
      incomes: incomes,
      recurringExpenses: recurringExpenses,
      splitGroups: splitGroups,
      groupExpenses: groupExpenses,
      customCategories: customCategories,
      preferences: preferences,
    );
    _validateKeys(snapshot, expenseEntries.map((entry) => entry.key));
    _validateRelationships(snapshot);
    return snapshot;
  }

  static void _validateKeys(
    BackupSnapshot snapshot,
    Iterable<String> expenseKeys,
  ) {
    final keys = expenseKeys.toList();
    final expenseIds = snapshot.expenses.map((value) => value.id).toList();
    if (expenseIds.toSet().length != expenseIds.length ||
        snapshot.expenses.length != keys.length ||
        expenseIds.toSet().length != keys.length ||
        !expenseIds.every(keys.contains)) {
      throw const BackupFormatException(
        'Expense keys do not match their records.',
      );
    }
    void validateIds<T>(
      Map<String, T> values,
      String Function(T) id,
      String name,
    ) {
      if (values.entries.any((entry) => id(entry.value) != entry.key)) {
        throw BackupFormatException('$name keys do not match their records.');
      }
    }

    validateIds(snapshot.lendings, (value) => value.id, 'lending');
    validateIds(snapshot.incomes, (value) => value.id, 'income');
    validateIds(snapshot.recurringExpenses, (value) => value.id, 'recurring');
    validateIds(snapshot.splitGroups, (value) => value.id, 'split group');
    validateIds(snapshot.groupExpenses, (value) => value.id, 'group expense');
    validateIds(snapshot.customCategories, (value) => value.id, 'custom category');
    if (snapshot.budgets.entries.any(
      (entry) => entry.key !=
          (entry.value.customCategoryId == null
              ? entry.value.category.index.toString()
              : 'custom:${entry.value.customCategoryId}'),
    )) {
      throw const BackupFormatException(
        'Budget keys do not match their records.',
      );
    }
  }

  static void _validateRelationships(BackupSnapshot snapshot) {
    for (final category in snapshot.customCategories.values) {
      if (category.mergedIntoId != null &&
          !snapshot.customCategories.containsKey(category.mergedIntoId)) {
        throw const BackupFormatException(
          'Custom category merge targets must exist in the backup.',
        );
      }
    }
    for (final expense in snapshot.expenses) {
      if (expense.customCategoryId != null &&
          !snapshot.customCategories.containsKey(expense.customCategoryId)) {
        throw const BackupFormatException(
          'Expenses must reference an existing custom category.',
        );
      }
    }
    for (final budget in snapshot.budgets.values) {
      if (budget.customCategoryId != null &&
          !snapshot.customCategories.containsKey(budget.customCategoryId)) {
        throw const BackupFormatException(
          'Budgets must reference an existing custom category.',
        );
      }
    }
    for (final group in snapshot.splitGroups.values) {
      if (group.participants.isEmpty) {
        throw const BackupFormatException(
          'Split groups must contain at least one participant.',
        );
      }
      final participantIds = group.participants.map((value) => value.id).toSet();
      if (participantIds.length != group.participants.length) {
        throw const BackupFormatException(
          'Split groups cannot contain duplicate participants.',
        );
      }
      if (group.myParticipantId != null &&
          !participantIds.contains(group.myParticipantId)) {
        throw const BackupFormatException(
          'Split group identity must name a participant.',
        );
      }
    }

    // ponytail: no paidBy/share membership check — editing a group can remove
    // a participant who still has expenses, and the app keeps those records,
    // so rejecting them here would make backups fail for valid local data.
    for (final expense in snapshot.groupExpenses.values) {
      if (!snapshot.splitGroups.containsKey(expense.groupId)) {
        throw const BackupFormatException(
          'Group expenses must reference an existing split group.',
        );
      }
    }
  }

  static List<_BackupEntry> _entries(dynamic raw, String name) {
    if (raw is! List) {
      throw BackupFormatException('Backup dataset "$name" is not a list.');
    }
    final seen = <String>{};
    final result = <_BackupEntry>[];
    for (final item in raw) {
      final map = _map(item, '$name entry');
      _requireFields(map, {'key', 'value'}, '$name entry');
      final key = _string(map['key'], '$name key');
      if (!seen.add(key)) {
        throw BackupFormatException(
          'Backup dataset "$name" has duplicate keys.',
        );
      }
      result.add(_BackupEntry(key, _map(map['value'], '$name value')));
    }
    return result;
  }

  static Map<String, T> _entryMap<T>(
    dynamic raw,
    String name,
    T Function(Map<String, dynamic>) decoder,
  ) {
    return {
      for (final entry in _entries(raw, name)) entry.key: decoder(entry.value),
    };
  }

  static Map<String, dynamic> _map(dynamic value, String label) {
    if (value is! Map) throw BackupFormatException('$label is malformed.');
    try {
      return Map<String, dynamic>.from(value);
    } catch (_) {
      throw BackupFormatException('$label is malformed.');
    }
  }

  static void _requireFields(
    Map<String, dynamic> value,
    Set<String> expected,
    String label,
  ) {
    if (value.keys.toSet().length != expected.length ||
        !value.keys.toSet().containsAll(expected)) {
      throw BackupFormatException('$label has an unsupported schema.');
    }
  }

  static String _string(dynamic value, String label) {
    if (value is! String || value.isEmpty) {
      throw BackupFormatException('$label must be a non-empty string.');
    }
    return value;
  }

  static String _text(dynamic value, String label) {
    if (value is! String) throw BackupFormatException('$label must be text.');
    return value;
  }

  static String? _nullableString(dynamic value, String label) {
    if (value == null) return null;
    return _text(value, label);
  }

  static bool _bool(dynamic value, String label) {
    if (value is! bool) {
      throw BackupFormatException('$label must be a boolean.');
    }
    return value;
  }

  static double _number(dynamic value, String label) {
    if (value is! num || !value.toDouble().isFinite) {
      throw BackupFormatException('$label must be a finite number.');
    }
    return value.toDouble();
  }

  static int _integer(dynamic value, String label) {
    if (value is! int) {
      throw BackupFormatException('$label must be an integer.');
    }
    return value;
  }

  static DateTime _date(dynamic value, String label) {
    if (value is! String) throw BackupFormatException('$label must be a date.');
    try {
      return DateTime.parse(value);
    } catch (_) {
      throw BackupFormatException('$label must be a valid date.');
    }
  }

  static Category _category(dynamic value, String label) {
    final index = _integer(value, label);
    if (index < 0 || index >= Category.values.length) {
      throw BackupFormatException('$label is not a supported category.');
    }
    return Category.values[index];
  }

  static Map<String, dynamic> _preferences(dynamic raw) {
    final map = _map(raw, 'preferences');
    final allowed = preferenceNames.toSet();
    if (!allowed.containsAll(map.keys)) {
      throw const BackupFormatException(
        'Backup contains an unknown preference.',
      );
    }
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      switch (key) {
        case 'currency':
        case 'theme':
          result[key] = _string(value, key);
          break;
        case 'onboardingDone':
        case 'goal_enabled':
          result[key] = _bool(value, key);
          break;
        case 'monthlyBudget':
        case 'monthlyIncome':
        case 'goal_monthly_limit':
          result[key] = _number(value, key);
          break;
        case 'startingDayOfMonth':
          final day = _integer(value, key);
          if (day < 1 || day > 28) {
            throw const BackupFormatException(
              'startingDayOfMonth must be between 1 and 28.',
            );
          }
          result[key] = day;
          break;
        case 'daily_goals':
          result[key] = _validatedDailyGoals(value);
          break;
        case 'app_notifications_v1':
          result[key] = _validatedNotifications(value);
          break;
        default:
          throw BackupFormatException('Backup contains an unknown preference.');
      }
    }
    return result;
  }

  static String _validatedDailyGoals(dynamic value) {
    final raw = _string(value, 'daily_goals');
    final decoded = _decodeJson(raw, 'daily_goals');
    if (decoded is! Map) {
      throw const BackupFormatException('daily_goals must contain a JSON map.');
    }
    for (final entry in decoded.entries) {
      if (entry.key is! String ||
          entry.value is! num ||
          !entry.value.toDouble().isFinite) {
        throw const BackupFormatException(
          'daily_goals contains an invalid value.',
        );
      }
    }
    return raw;
  }

  static String _validatedNotifications(dynamic value) {
    final raw = _string(value, 'app_notifications_v1');
    final decoded = _decodeJson(raw, 'app_notifications_v1');
    if (decoded is! List) {
      throw const BackupFormatException(
        'app_notifications_v1 must contain a JSON list.',
      );
    }
    for (final item in decoded) {
      final map = _map(item, 'notification');
      final notificationKeys = map.keys.toSet();
      const requiredNotificationKeys = {'id', 'title', 'body', 'time', 'type'};
      const allowedNotificationKeys = {
        ...requiredNotificationKeys,
        'isRead',
        'categoryKey',
      };
      if (!notificationKeys.containsAll(requiredNotificationKeys) ||
          notificationKeys.difference(allowedNotificationKeys).isNotEmpty) {
        throw const BackupFormatException(
          'notification has an unsupported schema.',
        );
      }
      _string(map['id'], 'notification id');
      _string(map['title'], 'notification title');
      _string(map['body'], 'notification body');
      _date(map['time'], 'notification time');
      final type = _integer(map['type'], 'notification type');
      if (type < 0 || type > 3) {
        throw const BackupFormatException('notification type is unsupported.');
      }
      if (map.containsKey('isRead')) {
        _bool(map['isRead'], 'notification isRead');
      }
      if (map['categoryKey'] != null) {
        _string(map['categoryKey'], 'notification categoryKey');
      }
    }
    return raw;
  }

  static dynamic _decodeJson(String raw, String label) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      throw BackupFormatException('$label contains invalid JSON.');
    }
  }

  static Map<String, dynamic> _expenseToJson(Expense value) => {
    'id': value.id,
    'title': value.title,
    'amount': value.amount,
    'category': value.category.index,
    'date': value.date.toIso8601String(),
    'note': value.note,
    'isManual': value.isManual,
    'isUncategorized': value.isUncategorized,
    'source': value.source,
    'customCategoryId': value.customCategoryId,
  };

  static Expense _expenseFromJson(Map<String, dynamic> raw) {
    final value = _map(raw, 'expense');
    const requiredFields = {
      'id',
      'title',
      'amount',
      'category',
      'date',
      'note',
      'isManual',
      'isUncategorized',
      'source',
    };
    final allowedFields = <String>{...requiredFields, 'customCategoryId'};
    if (!value.keys.toSet().containsAll(requiredFields) ||
        value.keys.toSet().difference(allowedFields).isNotEmpty) {
      throw const BackupFormatException('expense has an unsupported schema.');
    }
    return Expense(
      id: _string(value['id'], 'expense id'),
      title: _text(value['title'], 'expense title'),
      amount: _number(value['amount'], 'expense amount'),
      category: _category(value['category'], 'expense category'),
      date: _date(value['date'], 'expense date'),
      note: _nullableString(value['note'], 'expense note'),
      isManual: _bool(value['isManual'], 'expense isManual'),
      isUncategorized: _bool(value['isUncategorized'], 'expense isUncategorized'),
      source: _text(value['source'], 'expense source'),
      customCategoryId: _nullableString(
        value['customCategoryId'],
        'expense customCategoryId',
      ),
    );
  }

  static Map<String, dynamic> _merchantToJson(MerchantMemory value) => {
    'merchantName': value.merchantName,
    'category': value.category.index,
    'usageCount': value.usageCount,
    'lastUsed': value.lastUsed.toIso8601String(),
  };

  static MerchantMemory _merchantFromJson(Map<String, dynamic> raw) {
    final value = _fields(raw, 'merchant', {
      'merchantName',
      'category',
      'usageCount',
      'lastUsed',
    });
    return MerchantMemory(
      merchantName: _text(value['merchantName'], 'merchant name'),
      category: _category(value['category'], 'merchant category'),
      usageCount: _integer(value['usageCount'], 'merchant usageCount'),
      lastUsed: _date(value['lastUsed'], 'merchant lastUsed'),
    );
  }

  static Map<String, dynamic> _budgetToJson(Budget value) => {
    'category': value.category.index,
    'monthlyLimit': value.monthlyLimit,
    'alertAt': value.alertAt,
    'customCategoryId': value.customCategoryId,
  };

  static Budget _budgetFromJson(Map<String, dynamic> raw) {
    final value = _fields(raw, 'budget', {
      'category',
      'monthlyLimit',
      'alertAt',
      if (raw.containsKey('customCategoryId')) 'customCategoryId',
    });
    return Budget(
      category: _category(value['category'], 'budget category'),
      monthlyLimit: _number(value['monthlyLimit'], 'budget monthlyLimit'),
      alertAt: _number(value['alertAt'], 'budget alertAt'),
      customCategoryId: _nullableString(
        value['customCategoryId'],
        'budget customCategoryId',
      ),
    );
  }

  static Map<String, dynamic> _lendingToJson(Lending value) => {
    'id': value.id,
    'friendName': value.friendName,
    'amount': value.amount,
    'isIGave': value.isIGave,
    'date': value.date.toIso8601String(),
    'note': value.note,
    'isSettled': value.isSettled,
  };

  static Lending _lendingFromJson(Map<String, dynamic> raw) {
    final value = _fields(raw, 'lending', {
      'id',
      'friendName',
      'amount',
      'isIGave',
      'date',
      'note',
      'isSettled',
    });
    return Lending(
      id: _string(value['id'], 'lending id'),
      friendName: _text(value['friendName'], 'lending friendName'),
      amount: _number(value['amount'], 'lending amount'),
      isIGave: _bool(value['isIGave'], 'lending isIGave'),
      date: _date(value['date'], 'lending date'),
      note: _text(value['note'], 'lending note'),
      isSettled: _bool(value['isSettled'], 'lending isSettled'),
    );
  }

  static Map<String, dynamic> _incomeToJson(Income value) => {
    'id': value.id,
    'amount': value.amount,
    'source': value.source,
    'date': value.date.toIso8601String(),
    'note': value.note,
  };

  static Income _incomeFromJson(Map<String, dynamic> raw) {
    final value = _fields(raw, 'income', {
      'id',
      'amount',
      'source',
      'date',
      'note',
    });
    return Income(
      id: _string(value['id'], 'income id'),
      amount: _number(value['amount'], 'income amount'),
      source: _text(value['source'], 'income source'),
      date: _date(value['date'], 'income date'),
      note: _text(value['note'], 'income note'),
    );
  }

  static Map<String, dynamic> _recurringToJson(RecurringExpense value) => {
    'id': value.id,
    'title': value.title,
    'amount': value.amount,
    'category': value.category.index,
    'frequency': value.frequency,
    'startDate': value.startDate.toIso8601String(),
    'nextDue': value.nextDue.toIso8601String(),
    'isActive': value.isActive,
  };

  static RecurringExpense _recurringFromJson(Map<String, dynamic> raw) {
    final value = _fields(raw, 'recurring expense', {
      'id',
      'title',
      'amount',
      'category',
      'frequency',
      'startDate',
      'nextDue',
      'isActive',
    });
    return RecurringExpense(
      id: _string(value['id'], 'recurring id'),
      title: _text(value['title'], 'recurring title'),
      amount: _number(value['amount'], 'recurring amount'),
      category: _category(value['category'], 'recurring category'),
      frequency: _text(value['frequency'], 'recurring frequency'),
      startDate: _date(value['startDate'], 'recurring startDate'),
      nextDue: _date(value['nextDue'], 'recurring nextDue'),
      isActive: _bool(value['isActive'], 'recurring isActive'),
    );
  }

  static Map<String, dynamic> _splitGroupToJson(SplitGroup value) => {
    'id': value.id,
    'name': value.name,
    'participants': [
      for (final participant in value.participants)
        {
          'id': participant.id,
          'name': participant.name,
          'avatarColorValue': participant.avatarColorValue,
        },
    ],
    'createdAt': value.createdAt.toIso8601String(),
    'myParticipantId': value.myParticipantId,
  };

  static SplitGroup _splitGroupFromJson(Map<String, dynamic> value) {
    value = _fields(value, 'split group', {
      'id',
      'name',
      'participants',
      'createdAt',
      'myParticipantId',
    });
    final rawParticipants = value['participants'];
    if (rawParticipants is! List) {
      throw const BackupFormatException(
        'split group participants are malformed.',
      );
    }
    final participants = <Participant>[];
    for (final raw in rawParticipants) {
      final participant = _map(raw, 'participant');
      _requireFields(
        participant,
        {'id', 'name', 'avatarColorValue'},
        'participant',
      );
      participants.add(
        Participant(
          id: _string(participant['id'], 'participant id'),
          name: _text(participant['name'], 'participant name'),
          avatarColorValue: _integer(
            participant['avatarColorValue'],
            'participant avatarColorValue',
          ),
        ),
      );
    }
    return SplitGroup(
      id: _string(value['id'], 'split group id'),
      name: _text(value['name'], 'split group name'),
      participants: participants,
      createdAt: _date(value['createdAt'], 'split group createdAt'),
      myParticipantId: _nullableString(
        value['myParticipantId'],
        'split group myParticipantId',
      ),
    );
  }

  static Map<String, dynamic> _groupExpenseToJson(GroupExpense value) => {
    'id': value.id,
    'groupId': value.groupId,
    'description': value.description,
    'totalAmount': value.totalAmount,
    'paidBy': value.paidBy,
    'shares': [for (final share in value.shares) share.toMap()],
    'date': value.date.toIso8601String(),
    'note': value.note,
    'isSettled': value.isSettled,
  };

  static Map<String, dynamic> _customCategoryToJson(CustomCategory value) => {
    'id': value.id,
    'name': value.name,
    'iconCodePoint': value.iconCodePoint,
    'colorValue': value.colorValue,
    'archived': value.archived,
    'mergedIntoId': value.mergedIntoId,
  };

  static CustomCategory _customCategoryFromJson(Map<String, dynamic> raw) {
    final value = _fields(raw, 'custom category', {
      'id',
      'name',
      'iconCodePoint',
      'colorValue',
      'archived',
      'mergedIntoId',
    });
    return CustomCategory(
      id: _string(value['id'], 'custom category id'),
      name: _text(value['name'], 'custom category name'),
      iconCodePoint: _integer(value['iconCodePoint'], 'custom category icon'),
      colorValue: _integer(value['colorValue'], 'custom category color'),
      archived: _bool(value['archived'], 'custom category archived'),
      mergedIntoId: _nullableString(
        value['mergedIntoId'],
        'custom category mergedIntoId',
      ),
    );
  }

  static GroupExpense _groupExpenseFromJson(Map<String, dynamic> value) {
    value = _fields(value, 'group expense', {
      'id',
      'groupId',
      'description',
      'totalAmount',
      'paidBy',
      'shares',
      'date',
      'note',
      'isSettled',
    });
    final rawShares = value['shares'];
    if (rawShares is! List) {
      throw const BackupFormatException('group expense shares are malformed.');
    }
    final shares = <ParticipantShare>[];
    for (final raw in rawShares) {
      final share = _map(raw, 'participant share');
      _requireFields(share, {'participantId', 'amount'}, 'participant share');
      shares.add(
        ParticipantShare(
          participantId: _string(share['participantId'], 'share participantId'),
          amount: _number(share['amount'], 'share amount'),
        ),
      );
    }
    return GroupExpense(
      id: _string(value['id'], 'group expense id'),
      groupId: _string(value['groupId'], 'group expense groupId'),
      description: _text(value['description'], 'group expense description'),
      totalAmount: _number(value['totalAmount'], 'group expense totalAmount'),
      paidBy: _text(value['paidBy'], 'group expense paidBy'),
      shares: shares,
      date: _date(value['date'], 'group expense date'),
      note: _text(value['note'], 'group expense note'),
      isSettled: _bool(value['isSettled'], 'group expense isSettled'),
    );
  }

  static Map<String, dynamic> _fields(
    Map<String, dynamic> value,
    String label,
    Set<String> expected,
  ) {
    _requireFields(value, expected, label);
    return value;
  }
}

class _BackupEntry {
  final String key;
  final Map<String, dynamic> value;

  const _BackupEntry(this.key, this.value);
}

class BackupPreview {
  final Map<String, int> newRecords;
  final Map<String, int> skippedRecords;
  final List<String> preferenceKeys;

  const BackupPreview({
    required this.newRecords,
    required this.skippedRecords,
    required this.preferenceKeys,
  });

  int get preferences => preferenceKeys.length;

  int get totalNewRecords =>
      newRecords.values.fold(0, (sum, value) => sum + value);
  int get totalSkippedRecords =>
      skippedRecords.values.fold(0, (sum, value) => sum + value);
}

class BackupRestoreResult {
  final Map<String, int> inserted;
  final Map<String, int> skipped;
  final int preferences;

  const BackupRestoreResult({
    required this.inserted,
    required this.skipped,
    required this.preferences,
  });

  int get totalInserted => inserted.values.fold(0, (sum, value) => sum + value);
}

/// Creates and restores a complete, local-only JSON snapshot.
class BackupService {
  final StorageService storage;
  final SharedPreferences preferences;

  const BackupService({required this.storage, required this.preferences});

  Future<BackupSnapshot> createSnapshot() async {
    final allPrefs = <String, dynamic>{
      for (final key in preferences.getKeys()) key: preferences.get(key),
    };
    // Store effective app settings rather than only explicitly written keys.
    // This also normalizes the legacy monthlyIncome alias to the key currently
    // consumed by AppSettingsNotifier.
    final prefs = <String, dynamic>{
      'currency': preferences.getString('currency') ?? '₹',
      'monthlyBudget':
          preferences.getDouble('monthlyBudget') ??
          preferences.getDouble('monthlyIncome') ??
          0.0,
      'theme': preferences.getString('theme') ?? 'system',
      'onboardingDone': preferences.getBool('onboardingDone') ?? false,
      'startingDayOfMonth': preferences.getInt('startingDayOfMonth') ?? 1,
    };
    for (final key in const [
      'goal_monthly_limit',
      'goal_enabled',
      'daily_goals',
      'app_notifications_v1',
    ]) {
      if (allPrefs.containsKey(key)) prefs[key] = allPrefs[key];
    }
    final snapshot = BackupSnapshot(
      createdAt: DateTime.now().toUtc(),
      expenses: storage.getAllExpenses(),
      merchants: storage.merchantBox.toMap().map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      budgets: storage.budgetBox.toMap().map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      lendings: storage.lendingBox.toMap().map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      incomes: storage.incomeBox.toMap().map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      recurringExpenses: storage.recurringBox.toMap().map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      splitGroups: storage.splitGroupBox.toMap().map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      groupExpenses: storage.groupExpenseBox.toMap().map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      customCategories: storage.customCategoryBox.toMap().map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      preferences: prefs,
    );
    // Validate the serialized form too. This makes a backup fail loudly rather
    // than producing a file that this same app cannot restore later.
    return BackupSnapshot.fromJson(snapshot.toJson());
  }

  Future<String> createBackupJson() async {
    return jsonEncode((await createSnapshot()).toJson());
  }

  Future<File> writeTemporaryBackup() async {
    final directory = await getTemporaryDirectory();
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final file = File('${directory.path}/SpendSmart_Backup_$stamp.json');
    await file.writeAsString(await createBackupJson(), flush: true);
    return file;
  }

  Future<void> shareBackup({required Rect sharePositionOrigin}) async {
    final file = await writeTemporaryBackup();
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'SpendSmart Backup',
      text: 'SpendSmart offline backup',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<String?> pickBackupJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.size > 20 * 1024 * 1024) {
      throw const BackupFormatException('Backup file is larger than 20 MB.');
    }
    if (file.bytes != null) return utf8.decode(file.bytes!);
    final path = file.path;
    if (path == null || path.isEmpty) {
      throw const BackupFormatException('Could not read the selected backup.');
    }
    return File(path).readAsString();
  }

  static BackupSnapshot parse(String json) {
    try {
      final decoded = jsonDecode(json);
      return BackupSnapshot.fromJson(BackupSnapshot._map(decoded, 'backup'));
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      throw const BackupFormatException('Backup is not valid JSON.');
    }
  }

  BackupPreview preview(BackupSnapshot snapshot) {
    final newRecords = <String, int>{};
    final skippedRecords = <String, int>{};
    void compare(
      String name,
      Iterable<String> keys,
      bool Function(String) exists,
    ) {
      var fresh = 0;
      var skipped = 0;
      for (final key in keys) {
        if (exists(key)) {
          skipped++;
        } else {
          fresh++;
        }
      }
      newRecords[name] = fresh;
      skippedRecords[name] = skipped;
    }

    compare(
      StorageService.expenseBoxName,
      snapshot.expenses.map((value) => value.id),
      storage.expenseBox.containsKey,
    );
    compare(
      StorageService.merchantBoxName,
      snapshot.merchants.keys,
      storage.merchantBox.containsKey,
    );
    compare(
      StorageService.budgetBoxName,
      snapshot.budgets.keys,
      (key) => storage.budgetBox.containsKey(int.tryParse(key) ?? key),
    );
    compare(
      StorageService.lendingBoxName,
      snapshot.lendings.keys,
      storage.lendingBox.containsKey,
    );
    compare(
      StorageService.incomeBoxName,
      snapshot.incomes.keys,
      storage.incomeBox.containsKey,
    );
    compare(
      StorageService.recurringBoxName,
      snapshot.recurringExpenses.keys,
      storage.recurringBox.containsKey,
    );
    compare(
      StorageService.splitGroupBoxName,
      snapshot.splitGroups.keys,
      storage.splitGroupBox.containsKey,
    );
    compare(
      StorageService.groupExpenseBoxName,
      snapshot.groupExpenses.keys,
      storage.groupExpenseBox.containsKey,
    );
    compare(
      StorageService.customCategoryBoxName,
      snapshot.customCategories.keys,
      storage.customCategoryBox.containsKey,
    );
    return BackupPreview(
      newRecords: newRecords,
      skippedRecords: skippedRecords,
      preferenceKeys: snapshot.preferences.keys.toList()..sort(),
    );
  }

  Future<BackupRestoreResult> restoreJson(String json) async {
    return restore(BackupService.parse(json));
  }

  /// Merge restore: existing Hive keys are never overwritten. Preferences are
  /// singular settings, so a valid backup value replaces that setting.
  Future<BackupRestoreResult> restore(BackupSnapshot snapshot) async {
    // Callers normally pass a parsed file, but revalidate this public entry
    // point as well so no invalid in-memory snapshot can mutate local data.
    snapshot = BackupSnapshot.fromJson(snapshot.toJson());
    final inserted = <String, int>{};
    final skipped = <String, int>{};

    Future<void> merge<T>(
      String name,
      Box<T> box,
      Map<String, T> values, {
      Object Function(String key)? keyForBox,
    }) async {
      final fresh = <Object, T>{};
      var duplicateCount = 0;
      for (final entry in values.entries) {
        final key = keyForBox?.call(entry.key) ?? entry.key;
        if (box.containsKey(key)) {
          duplicateCount++;
        } else {
          fresh[key] = entry.value;
        }
      }
      if (fresh.isNotEmpty) {
        await box.putAll(fresh);
        if (fresh.keys.any((key) => !box.containsKey(key))) {
          throw StateError('Backup write verification failed for $name.');
        }
      }
      inserted[name] = fresh.length;
      skipped[name] = duplicateCount;
    }

    await merge(StorageService.expenseBoxName, storage.expenseBox, {
      for (final value in snapshot.expenses) value.id: value,
    });
    await merge(
      StorageService.merchantBoxName,
      storage.merchantBox,
      snapshot.merchants,
    );
    await merge(
      StorageService.budgetBoxName,
      storage.budgetBox,
      snapshot.budgets,
       keyForBox: (key) => int.tryParse(key) ?? key,
    );
    await merge(
      StorageService.lendingBoxName,
      storage.lendingBox,
      snapshot.lendings,
    );
    await merge(
      StorageService.incomeBoxName,
      storage.incomeBox,
      snapshot.incomes,
    );
    await merge(
      StorageService.recurringBoxName,
      storage.recurringBox,
      snapshot.recurringExpenses,
    );
    await merge(
      StorageService.splitGroupBoxName,
      storage.splitGroupBox,
      snapshot.splitGroups,
    );
    await merge(
      StorageService.groupExpenseBoxName,
      storage.groupExpenseBox,
      snapshot.groupExpenses,
    );
    await merge(
      StorageService.customCategoryBoxName,
      storage.customCategoryBox,
      snapshot.customCategories,
    );

    final preferenceValues = Map<String, dynamic>.from(snapshot.preferences);
    // Prefer the current canonical key if an older backup contains both
    // monthly-budget aliases.
    if (preferenceValues.containsKey('monthlyBudget')) {
      preferenceValues.remove('monthlyIncome');
    }
    for (final entry in preferenceValues.entries) {
      await _setPreference(entry.key, entry.value);
    }

    return BackupRestoreResult(
      inserted: inserted,
      skipped: skipped,
      preferences: preferenceValues.length,
    );
  }

  Future<void> _setPreference(String key, dynamic value) async {
    var written = false;
    switch (key) {
      case 'currency':
      case 'theme':
      case 'daily_goals':
      case 'app_notifications_v1':
        written = await preferences.setString(key, value as String);
        break;
      case 'monthlyBudget':
        await preferences.remove('monthlyIncome');
        written = await preferences.setDouble(key, (value as num).toDouble());
        break;
      case 'monthlyIncome':
      case 'goal_monthly_limit':
        if (key == 'monthlyIncome') await preferences.remove('monthlyBudget');
        written = await preferences.setDouble(key, (value as num).toDouble());
        break;
      case 'onboardingDone':
      case 'goal_enabled':
        written = await preferences.setBool(key, value as bool);
        break;
      case 'startingDayOfMonth':
        written = await preferences.setInt(key, value as int);
        break;
      default:
        throw StateError('Unsupported preference "$key".');
    }
    if (!written || !_preferenceMatches(key, value)) {
      throw StateError('Backup write verification failed for preference "$key".');
    }
  }

  bool _preferenceMatches(String key, dynamic expected) {
    final actual = preferences.get(key);
    if (actual is num && expected is num) {
      return actual.toDouble() == expected.toDouble();
    }
    return actual == expected;
  }
}
