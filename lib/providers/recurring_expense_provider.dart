import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/recurring_expense.dart';
import '../models/expense.dart';
import '../models/category.dart';
import 'expense_provider.dart';

final recurringExpenseProvider =
    NotifierProvider<RecurringExpenseNotifier, List<RecurringExpense>>(
  RecurringExpenseNotifier.new,
);

class RecurringExpenseNotifier extends Notifier<List<RecurringExpense>> {
  static const String _boxName = 'recurring_expenses';
  Box<RecurringExpense> get _box => Hive.box<RecurringExpense>(_boxName);

  @override
  List<RecurringExpense> build() =>
      _box.values.toList()..sort((a, b) => a.title.compareTo(b.title));

  Future<void> add(RecurringExpense r) async {
    await _box.put(r.id, r);
    _refresh();
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    _refresh();
  }

  Future<void> toggleActive(String id) async {
    final r = _box.get(id);
    if (r == null) return;
    r.isActive = !r.isActive;
    await r.save();
    _refresh();
  }

  /// Called on app startup. Generates Expense entries for any recurring
  /// expenses that are past due, then advances their nextDue date.
  Future<void> generateDueExpenses(ExpenseNotifier expenseNotifier) async {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final r in _box.values) {
      if (!r.isActive) continue;
      // Keep generating until nextDue is in the future
      while (!r.nextDue.isAfter(today)) {
        final expense = Expense(
          id:               const Uuid().v4(),
          title:            r.title,
          amount:           r.amount,
          category:         r.category,
          date:             r.nextDue,
          note:             'Auto-generated recurring (${r.frequency})',
          isManual:         false,
          isUncategorized:  false,
          source:           'recurring',
        );
        await expenseNotifier.addExpense(expense);
        r.nextDue = r.computeNextDue(r.nextDue);
        await r.save();
      }
    }
    _refresh();
  }

  void _refresh() {
    state = _box.values.toList()..sort((a, b) => a.title.compareTo(b.title));
  }
}

/// Helper to quickly build a RecurringExpense from form inputs.
RecurringExpense buildRecurring({
  required String title,
  required double amount,
  required Category category,
  required String frequency,
  required DateTime startDate,
}) {
  return RecurringExpense(
    id:        const Uuid().v4(),
    title:     title,
    amount:    amount,
    category:  category,
    frequency: frequency,
    startDate: startDate,
    nextDue:   startDate,
  );
}
