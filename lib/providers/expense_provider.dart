import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../models/category.dart';
import 'service_provider.dart';

final expenseProvider = NotifierProvider<ExpenseNotifier, List<Expense>>(ExpenseNotifier.new);

class ExpenseNotifier extends Notifier<List<Expense>> {
  @override
  List<Expense> build() {
    return ref.watch(storageServiceProvider).getAllExpenses();
  }

  void _loadExpenses() {
    state = ref.read(storageServiceProvider).getAllExpenses();
  }

  Future<void> addExpense(Expense expense) async {
    await ref.read(storageServiceProvider).saveExpense(expense);
    _loadExpenses();
  }

  Future<void> addExpenseFromSMS(Expense expense, {bool isImport = false}) async {
    if (isImport) {
      final exists = state.any((e) =>
          e.amount == expense.amount &&
          e.date.year == expense.date.year &&
          e.date.month == expense.date.month &&
          e.date.day == expense.date.day &&
          e.title == expense.title);
      if (exists) return;
    }
    await ref.read(storageServiceProvider).saveExpense(expense);
    _loadExpenses();
  }

  Future<void> updateExpense(Expense expense) async {
    await ref.read(storageServiceProvider).saveExpense(expense);
    _loadExpenses();
  }

  Future<void> deleteExpense(String id) async {
    await ref.read(storageServiceProvider).deleteExpense(id);
    _loadExpenses();
  }

  Future<void> categorizeExpense(String id, Category category) async {
    final index = state.indexWhere((e) => e.id == id);
    if (index == -1) return; // expense was deleted before categorization
    final updated = state[index].copyWith(category: category, isUncategorized: false);
    await ref.read(storageServiceProvider).saveExpense(updated);
    _loadExpenses();
  }

  /// Batch-import: saves all non-duplicate expenses in one pass, then reloads state once.
  Future<void> importExpenses(List<Expense> expenses) async {
    final storage = ref.read(storageServiceProvider);
    final existing = state;
    for (final expense in expenses) {
      final isDuplicate = existing.any((e) =>
          e.amount == expense.amount &&
          e.date.year == expense.date.year &&
          e.date.month == expense.date.month &&
          e.date.day == expense.date.day &&
          e.title == expense.title);
      if (!isDuplicate) {
        await storage.saveExpense(expense);
      }
    }
    _loadExpenses(); // single reload
  }
}
