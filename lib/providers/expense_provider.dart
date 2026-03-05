import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../services/supabase_service.dart';
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
    // Sync to Supabase (fire-and-forget)
    SupabaseService.upsertExpense(expense);
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
    SupabaseService.upsertExpense(expense);
  }

  Future<void> updateExpense(Expense expense) async {
    await ref.read(storageServiceProvider).saveExpense(expense);
    _loadExpenses();
    SupabaseService.upsertExpense(expense);
  }

  Future<void> deleteExpense(String id) async {
    await ref.read(storageServiceProvider).deleteExpense(id);
    _loadExpenses();
    SupabaseService.deleteExpense(id);
  }

  Future<void> categorizeExpense(String id, dynamic category) async {
    final expense = state.firstWhere((e) => e.id == id);
    final updated = expense.copyWith(category: category, isUncategorized: false);
    await ref.read(storageServiceProvider).saveExpense(updated);
    _loadExpenses();
    SupabaseService.upsertExpense(updated);
  }

  Future<void> importExpenses(List<Expense> expenses) async {
    for (final expense in expenses) {
      await addExpenseFromSMS(expense, isImport: true);
    }
  }

  /// Pull all expenses from Supabase and merge into local storage.
  /// Called once on startup or when the user asks to sync.
  Future<void> syncFromSupabase() async {
    final rows = await SupabaseService.fetchExpenses();
    for (final row in rows) {
      try {
        final expense = SupabaseService.rowToExpense(row);
        // Only add if not already in local store
        final alreadyExists = state.any((e) => e.id == expense.id);
        if (!alreadyExists) {
          await ref.read(storageServiceProvider).saveExpense(expense);
        }
      } catch (_) {
        // Skip malformed rows
      }
    }
    _loadExpenses();
  }
}
