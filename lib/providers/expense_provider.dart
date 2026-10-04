import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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

  /// Batch-import: saves all non-duplicate expenses in one pass, then reloads
  /// state once.
  ///
  /// Imported ids are regenerated whenever they collide with a stored one.
  /// A CSV carries whatever id the file says, and storage is keyed by id, so a
  /// hand-edited or re-exported file could silently overwrite unrelated
  /// expenses. Content-level duplicates are still dropped by [_expenseKey], so
  /// re-importing the same file remains a no-op rather than a duplication.
  Future<int> importExpenses(List<Expense> expenses) async {
    final storage = ref.read(storageServiceProvider);
    final seen = state.map(_expenseKey).toSet();
    final usedIds = state.map((e) => e.id).toSet();
    final fresh = <Expense>[];
    for (final expense in expenses) {
      if (!seen.add(_expenseKey(expense))) continue;
      final safe = usedIds.add(expense.id)
          ? expense
          : expense.copyWith(id: const Uuid().v4());
      if (safe.id != expense.id) usedIds.add(safe.id);
      fresh.add(safe);
    }
    if (fresh.isNotEmpty) await storage.saveExpenses(fresh);
    _loadExpenses();
    return fresh.length;
  }

  /// Saves [expenses] whose ids are not already stored, in one pass.
  ///
  /// Unlike [importExpenses] this keys on the id alone and never rewrites one:
  /// callers pass deterministic ids so that re-running a generation is a no-op
  /// rather than a duplicate.
  Future<int> addMissingById(List<Expense> expenses) async {
    final known = state.map((e) => e.id).toSet();
    final fresh = expenses.where((e) => known.add(e.id)).toList();
    if (fresh.isEmpty) return 0;
    await ref.read(storageServiceProvider).saveExpenses(fresh);
    _loadExpenses();
    return fresh.length;
  }

  String _expenseKey(Expense e) {
    final day = DateTime(e.date.year, e.date.month, e.date.day);
    return '${e.title.trim().toLowerCase()}|${e.amount.toStringAsFixed(2)}|${day.toIso8601String()}';
  }
}
