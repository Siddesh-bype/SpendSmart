import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../models/category.dart';
import 'service_provider.dart';

final expenseProvider = NotifierProvider<ExpenseNotifier, List<Expense>>(
  ExpenseNotifier.new,
);

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

  Future<void> addExpenseFromSMS(
    Expense expense, {
    bool isImport = false,
  }) async {
    if (isImport) {
      final key = _expenseKey(expense);
      final exists = state.any((e) => _expenseKey(e) == key);
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
    final updated = state[index].copyWith(
      category: category,
      isUncategorized: false,
    );
    await ref.read(storageServiceProvider).saveExpense(updated);
    _loadExpenses();
  }

  /// Batch-import: saves all non-duplicate expenses in one pass, then reloads state once.
  Future<int> importExpenses(List<Expense> expenses) async {
    final storage = ref.read(storageServiceProvider);
    final seen = state.map(_expenseKey).toSet();
    final fresh = expenses.where((e) => seen.add(_expenseKey(e))).toList();
    if (fresh.isNotEmpty) await storage.saveExpenses(fresh);
    _loadExpenses();
    return fresh.length;
  }

  String _expenseKey(Expense e) {
    final day = DateTime(e.date.year, e.date.month, e.date.day);
    return '${e.title.trim().toLowerCase()}|${e.amount.toStringAsFixed(2)}|${day.toIso8601String()}';
  }
}
