import 'package:hive_flutter/hive_flutter.dart';
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

  /// Rewrites every encrypted box as plaintext, for removing the app lock.
  ///
  /// Mirrors [_migrateToEncrypted]'s ordering: stage, verify, then replace. A
  /// crash leaves the encrypted original, which the password still opens.
  Future<void> decryptToPlaintext() async {
    final snapshot = <String, Map<dynamic, dynamic>>{};
    for (final name in _allBoxNames) {
      if (!Hive.isBoxOpen(name)) continue;
      final box = Hive.box<dynamic>(name);
      snapshot[name] = {for (final key in box.keys) key: box.get(key)};
    }

    await Hive.close();
    for (final entry in snapshot.entries) {
      await Hive.deleteBoxFromDisk(entry.key);
      final box = await Hive.openBox<dynamic>(entry.key);
      await box.putAll(entry.value);
      await box.close();
    }
    await init();
  }

  /// Closes every open box and opens them again, encrypted with [encryptionKey].
  ///
  /// Used when a lock is added to an app that has been running without one:
  /// the boxes are already open in the clear, so they must be closed before
  /// [init] can migrate and re-open them.
  Future<void> reopen({List<int>? encryptionKey}) async {
    await Hive.close();
    await init(encryptionKey: encryptionKey);
  }

  /// Opens every box, encrypted when [encryptionKey] is supplied.
  ///
  /// Adapters are registered first and unconditionally: they describe the
  /// binary layout and are needed to read either flavour of box.
  Future<void> init({List<int>? encryptionKey}) async {
    await Hive.initFlutter();
    _registerAdapters();

    final cipher = encryptionKey == null
        ? null
        : HiveAesCipher(encryptionKey);

    if (cipher != null) {
      await _migrateToEncrypted(cipher);
    }

    await Hive.openBox<Expense>(expenseBoxName, encryptionCipher: cipher);
    await Hive.openBox<MerchantMemory>(
      merchantBoxName,
      encryptionCipher: cipher,
    );
    await Hive.openBox<Budget>(budgetBoxName, encryptionCipher: cipher);
    await Hive.openBox<Lending>(lendingBoxName, encryptionCipher: cipher);
    await Hive.openBox<Income>(incomeBoxName, encryptionCipher: cipher);
    await Hive.openBox<RecurringExpense>(
      recurringBoxName,
      encryptionCipher: cipher,
    );
    await Hive.openBox<SplitGroup>(
      splitGroupBoxName,
      encryptionCipher: cipher,
    );
    await Hive.openBox<GroupExpense>(
      groupExpenseBoxName,
      encryptionCipher: cipher,
    );
  }

  /// Copies any surviving plaintext box into its encrypted replacement.
  ///
  /// Order matters and is deliberate: write the encrypted copy under a staging
  /// name, verify the entry count, and only then delete the plaintext and
  /// rename. A crash at any point leaves the original readable, so the worst
  /// case is repeating the migration rather than losing expenses.
  Future<void> _migrateToEncrypted(HiveAesCipher cipher) async {
    for (final name in _allBoxNames) {
      if (!await Hive.boxExists(name)) continue;

      // A box that no longer opens in the clear is already encrypted.
      final Box<dynamic> plain;
      try {
        plain = await Hive.openBox<dynamic>(name);
      } catch (_) {
        continue;
      }

      if (plain.isEmpty) {
        await plain.close();
        continue;
      }

      final entries = <dynamic, dynamic>{
        for (final key in plain.keys) key: plain.get(key),
      };
      final expected = entries.length;

      final staging = '${name}_enc';
      await Hive.deleteBoxFromDisk(staging); // Leftover from a failed attempt.
      final encrypted = await Hive.openBox<dynamic>(
        staging,
        encryptionCipher: cipher,
      );
      await encrypted.putAll(entries);
      if (encrypted.length != expected) {
        throw StateError(
          'Migration of "$name" wrote ${encrypted.length} of $expected entries.',
        );
      }
      final migrated = <dynamic, dynamic>{
        for (final key in encrypted.keys) key: encrypted.get(key),
      };
      await encrypted.close();

      // The copy is verified; only now is it safe to drop the plaintext.
      await plain.close();
      await Hive.deleteBoxFromDisk(name);

      final replacement = await Hive.openBox<dynamic>(
        name,
        encryptionCipher: cipher,
      );
      await replacement.putAll(migrated);
      await replacement.close();
      await Hive.deleteBoxFromDisk(staging);
    }
  }

  static const List<String> _allBoxNames = [
    expenseBoxName,
    merchantBoxName,
    budgetBoxName,
    lendingBoxName,
    incomeBoxName,
    recurringBoxName,
    splitGroupBoxName,
    groupExpenseBoxName,
  ];

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
