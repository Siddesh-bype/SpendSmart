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

  Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
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

    // Open Boxes
    await Hive.openBox<Expense>(expenseBoxName);
    await Hive.openBox<MerchantMemory>(merchantBoxName);
    await Hive.openBox<Budget>(budgetBoxName);
    await Hive.openBox<Lending>(lendingBoxName);
    await Hive.openBox<Income>(incomeBoxName);
    await Hive.openBox<RecurringExpense>(recurringBoxName);
    await Hive.openBox<SplitGroup>(splitGroupBoxName);
    await Hive.openBox<GroupExpense>(groupExpenseBoxName);
  }

  // Expenses
  Box<Expense> get expenseBox => Hive.box<Expense>(expenseBoxName);

  Future<void> saveExpense(Expense expense) async {
    await expenseBox.put(expense.id, expense);
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
