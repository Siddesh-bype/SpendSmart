import 'package:hive_flutter/hive_flutter.dart';
import '../models/expense.dart';
import '../models/merchant_memory.dart';
import '../models/budget.dart';
import '../models/category.dart';

class StorageService {
  static const String expenseBoxName = 'expenses';
  static const String merchantBoxName = 'merchants';
  static const String budgetBoxName = 'budgets';

  Future<void> init() async {
    await Hive.initFlutter();
    
    // Register Adapters
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CategoryAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ExpenseAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(MerchantMemoryAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(BudgetAdapter());

    // Open Boxes
    await Hive.openBox<Expense>(expenseBoxName);
    await Hive.openBox<MerchantMemory>(merchantBoxName);
    await Hive.openBox<Budget>(budgetBoxName);
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
    return expenseBox.values.where((e) => e.isUncategorized).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  // Merchant Memory
  Box<MerchantMemory> get merchantBox => Hive.box<MerchantMemory>(merchantBoxName);

  MerchantMemory? getMerchantMemory(String merchantName) {
    return merchantBox.get(merchantName.toLowerCase());
  }

  Future<void> saveMerchantMemory(String merchantName, Category category) async {
    final key = merchantName.toLowerCase();
    final existing = merchantBox.get(key);
    if (existing != null) {
      existing.usageCount += 1;
      existing.lastUsed = DateTime.now();
      await existing.save();
    } else {
      await merchantBox.put(key, MerchantMemory(
        merchantName: merchantName,
        category: category,
        lastUsed: DateTime.now(),
      ));
    }
  }

  Future<void> deleteMerchantMemory(String merchantName) async {
    await merchantBox.delete(merchantName.toLowerCase());
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

  // Clear all data (on logout)
  Future<void> clearAll() async {
    await expenseBox.clear();
    await budgetBox.clear();
    await merchantBox.clear();
  }
}
