import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/expense.dart';
import '../models/merchant_memory.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/lending.dart';
import '../models/income.dart';
import '../models/recurring_expense.dart';
import '../models/split_group.dart';
import '../models/group_expense.dart';
import 'category_classifier.dart';

class StorageService {
  static const String expenseBoxName = 'expenses';
  static const String merchantBoxName = 'merchants';
  static const String budgetBoxName = 'budgets';
  static const String lendingBoxName = 'lendings';
  static const String incomeBoxName = 'incomes';
  static const String recurringBoxName = 'recurring_expenses';
  static const String splitGroupBoxName = 'split_groups';
  static const String groupExpenseBoxName = 'group_expenses';

  /// Boxes that could not be opened, with the error that stopped them.
  ///
  /// Non-empty means some of the user's records are on disk but unreadable.
  /// The app still runs on the boxes that did open, and the UI warns instead of
  /// pretending the data was never there.
  final Map<String, String> openFailures = {};

  /// Where unreadable box files were moved. Shown to the user so the data is
  /// findable rather than silently gone.
  final List<String> quarantinedFiles = [];

  /// Opens every box.
  ///
  /// Data is stored unencrypted: the app has no password, so there is no
  /// secret to derive a key from.
  Future<void> init() async {
    await Hive.initFlutter();
    _registerAdapters();
    openFailures.clear();
    quarantinedFiles.clear();

    await _open<Expense>(expenseBoxName);
    await _open<MerchantMemory>(merchantBoxName);
    await _open<Budget>(budgetBoxName);
    await _open<Lending>(lendingBoxName);
    await _open<Income>(incomeBoxName);
    await _open<RecurringExpense>(recurringBoxName);
    await _open<SplitGroup>(splitGroupBoxName);
    await _open<GroupExpense>(groupExpenseBoxName);
  }

  /// Opens one box. Never deletes data.
  ///
  /// An open can fail for reasons that are nobody's fault and often temporary:
  /// disk full, a half-finished OS write, a file still locked, an adapter that
  /// does not match a file written by another build. Deleting the file in
  /// response would turn any of those into permanent loss of the user's
  /// expenses, so instead the file is moved aside, an empty box takes its
  /// place, and the failure is recorded for the UI to surface.
  ///
  /// The quarantined copy keeps the data recoverable: a later build with the
  /// right adapter can read it, and support can ask for it.
  Future<void> _open<T>(String name) async {
    try {
      await Hive.openBox<T>(name);
      return;
    } catch (error) {
      openFailures[name] = error.toString();
    }

    // Nothing below is allowed to throw: a failure here must not stop the
    // remaining boxes, which usually hold most of the user's data.
    try {
      final moved = await _quarantine(name);
      if (moved != null) quarantinedFiles.add(moved);
      await Hive.openBox<T>(name);
    } catch (error) {
      openFailures[name] = '${openFailures[name]} (recovery failed: $error)';
    }
  }

  /// Renames a box's files out of the way and returns the new path of the
  /// data file, or null if there was nothing to move.
  Future<String?> _quarantine(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');
    String? movedDataFile;

    // Hive writes '<name>.hive' plus a '<name>.lock' sidecar. Both must move
    // or the reopened box inherits the stale lock.
    for (final extension in const ['.hive', '.lock']) {
      final file = File('${dir.path}/$name$extension');
      if (!await file.exists()) continue;
      final target = '${dir.path}/$name.corrupt-$stamp$extension';
      await file.rename(target);
      if (extension == '.hive') movedDataFile = target;
    }
    return movedDataFile;
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ExpenseAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(MerchantMemoryAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(BudgetAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(IncomeAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(LendingAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(RecurringExpenseAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(SplitGroupAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(GroupExpenseAdapter());
    }
  }

  // Expenses
  Box<Expense> get expenseBox => Hive.box<Expense>(expenseBoxName);

  Future<void> saveExpense(Expense expense) async {
    await expenseBox.put(expense.id, expense);
  }

  /// One box write for a whole import instead of N awaits.
  Future<void> saveExpenses(Iterable<Expense> expenses) async {
    await expenseBox.putAll({for (final e in expenses) e.id: e});
  }

  Future<void> deleteExpense(String id) async {
    await expenseBox.delete(id);
  }

  List<Expense> getAllExpenses() {
    return expenseBox.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Expense> getPendingExpenses() {
    return expenseBox.values.where((e) => e.isUncategorized).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // Merchant Memory
  Box<MerchantMemory> get merchantBox =>
      Hive.box<MerchantMemory>(merchantBoxName);

  /// Entries written before normalization existed are keyed by plain
  /// lowercase, so lookups fall back to it.
  String _legacyMerchantKey(String merchantName) =>
      merchantName.toLowerCase().trim();

  MerchantMemory? getMerchantMemory(String merchantName) {
    final key = CategoryClassifier.normalizeMerchant(merchantName);
    if (key.isNotEmpty) {
      final hit = merchantBox.get(key);
      if (hit != null) return hit;
    }
    return merchantBox.get(_legacyMerchantKey(merchantName));
  }

  /// Learned category for [rawMerchant], or null when no entry is a confident
  /// match.
  Category? lookupMerchantCategory(String rawMerchant) {
    final key = CategoryClassifier.normalizeMerchant(rawMerchant);
    if (key.isEmpty) return null;

    final exact = getMerchantMemory(rawMerchant);
    if (exact != null) return exact.category;

    final tokens = key.split(' ').where((t) => t.isNotEmpty).toSet();
    MerchantMemory? best;
    for (final entry in merchantBox.toMap().entries) {
      if (!_merchantKeyMatches(entry.key.toString(), tokens)) continue;
      final candidate = entry.value;
      if (best == null ||
          candidate.usageCount > best.usageCount ||
          (candidate.usageCount == best.usageCount &&
              candidate.lastUsed.isAfter(best.lastUsed))) {
        best = candidate;
      }
    }
    return best?.category;
  }

  bool _merchantKeyMatches(String storedKey, Set<String> tokens) {
    if (storedKey.length < 3) return false;
    final storedTokens = storedKey
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toSet();
    if (storedTokens.isEmpty) return false;
    if (storedTokens.every(tokens.contains)) return true;
    return storedTokens.any((t) => t.length >= 4 && tokens.contains(t));
  }

  /// Saves or re-teaches [merchantName]. A category that differs from the
  /// stored one is treated as a user correction and overwrites it.
  Future<void> saveMerchantMemory(
    String merchantName,
    Category category,
  ) async {
    final key = CategoryClassifier.normalizeMerchant(merchantName);
    if (key.isEmpty) return;

    var existing = merchantBox.get(key);
    var rekeyed = false;
    if (existing == null) {
      final legacyKey = _legacyMerchantKey(merchantName);
      if (legacyKey != key) {
        existing = merchantBox.get(legacyKey);
        if (existing != null) {
          await merchantBox.delete(legacyKey);
          rekeyed = true;
        }
      }
    }

    if (existing == null) {
      await merchantBox.put(
        key,
        MerchantMemory(
          merchantName: merchantName,
          category: category,
          lastUsed: DateTime.now(),
        ),
      );
      return;
    }

    existing.category = category;
    existing.usageCount += 1;
    existing.lastUsed = DateTime.now();
    if (rekeyed) {
      await merchantBox.put(key, existing);
    } else {
      await existing.save();
    }
  }

  Future<void> deleteMerchantMemory(String merchantName) async {
    final key = CategoryClassifier.normalizeMerchant(merchantName);
    if (key.isNotEmpty) await merchantBox.delete(key);
    final legacyKey = _legacyMerchantKey(merchantName);
    if (legacyKey != key) await merchantBox.delete(legacyKey);
  }

  // Budgets
  Box<Budget> get budgetBox => Hive.box<Budget>(budgetBoxName);

  Budget? getBudget(Category category) {
    return budgetBox.get(category.index);
  }

  Future<void> saveBudget(Budget budget) async {
    await budgetBox.put(budget.category.index, budget);
  }

  List<Budget> getAllBudgets() {
    return budgetBox.values.toList();
  }

  // Incomes
  Box<Income> get incomeBox => Hive.box<Income>(incomeBoxName);

  // Recurring Expenses
  Box<RecurringExpense> get recurringBox =>
      Hive.box<RecurringExpense>(recurringBoxName);

  // Lendings
  Box<Lending> get lendingBox => Hive.box<Lending>(lendingBoxName);

  Future<void> saveLending(Lending lending) async {
    await lendingBox.put(lending.id, lending);
  }

  Future<void> deleteLending(String id) async {
    await lendingBox.delete(id);
  }

  List<Lending> getAllLendings() {
    return lendingBox.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  // Split Groups
  Box<SplitGroup> get splitGroupBox => Hive.box<SplitGroup>(splitGroupBoxName);

  Future<void> saveSplitGroup(SplitGroup group) async {
    await splitGroupBox.put(group.id, group);
  }

  Future<void> deleteSplitGroup(String id) async {
    await splitGroupBox.delete(id);
  }

  List<SplitGroup> getAllSplitGroups() {
    return splitGroupBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Group Expenses
  Box<GroupExpense> get groupExpenseBox =>
      Hive.box<GroupExpense>(groupExpenseBoxName);

  Future<void> saveGroupExpense(GroupExpense expense) async {
    await groupExpenseBox.put(expense.id, expense);
  }

  Future<void> deleteGroupExpense(String id) async {
    await groupExpenseBox.delete(id);
  }

  List<GroupExpense> getAllGroupExpenses() {
    return groupExpenseBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<GroupExpense> getGroupExpenses(String groupId) {
    return groupExpenseBox.values.where((e) => e.groupId == groupId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // Clear all data (on logout)
  Future<void> clearAll() async {
    await expenseBox.clear();
    await budgetBox.clear();
    await merchantBox.clear();
    await incomeBox.clear();
    await recurringBox.clear();
    await lendingBox.clear();
    await splitGroupBox.clear();
    await groupExpenseBox.clear();
  }
}
