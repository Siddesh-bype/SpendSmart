import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
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
            e.title == expense.title
        );
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

  Future<void> categorizeExpense(String id, dynamic category) async {
    final expense = state.firstWhere((e) => e.id == id);
    final updated = expense.copyWith(category: category, isUncategorized: false);
    await ref.read(storageServiceProvider).saveExpense(updated);
    _loadExpenses();
  }

  Future<void> importExpenses(List<Expense> expenses) async {
    for (final expense in expenses) {
      await addExpenseFromSMS(expense, isImport: true);
    }
  }
}
