import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/recurring_expense.dart';
import '../models/expense.dart';
import '../models/category.dart';
import 'expense_provider.dart';
import 'service_provider.dart';

final recurringExpenseProvider =
    NotifierProvider<RecurringExpenseNotifier, List<RecurringExpense>>(
  RecurringExpenseNotifier.new,
);

class RecurringExpenseNotifier extends Notifier<List<RecurringExpense>> {
  Box<RecurringExpense> get _box => ref.read(storageServiceProvider).recurringBox;

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

  /// Occurrences generated per rule per run.
  ///
  /// A daily rule left dormant for two years is 700 expenses, and the old
  /// unbounded loop wrote every one of them on the frame after launch. The cap
  /// spreads a long backlog over successive launches instead of freezing the
  /// first one; the remainder is still generated, just not all at once.
  static const _maxOccurrencesPerRun = 60;

  /// Called on app startup. Generates Expense entries for any recurring
  /// expenses that are past due, then advances their nextDue date.
  ///
  /// Occurrence ids are derived from the rule id and the due date, so a run
  /// interrupted midway — the app killed between the expense write and the
  /// nextDue write — regenerates the same id and is dropped as a duplicate
  /// rather than charging the user twice.
  Future<void> generateDueExpenses(ExpenseNotifier expenseNotifier) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = <Expense>[];

    for (final r in _box.values) {
      if (!r.isActive) continue;
      var cursor = r.nextDue;
      var generated = 0;
      while (!cursor.isAfter(today) && generated < _maxOccurrencesPerRun) {
        due.add(
          Expense(
            id: _occurrenceId(r.id, cursor),
            title: r.title,
            amount: r.amount,
            category: r.category,
            date: cursor,
            note: 'Auto-generated recurring (${r.frequency})',
            isManual: false,
            isUncategorized: false,
            source: 'recurring',
          ),
        );
        final next = r.computeNextDue(cursor);
        // A frequency that fails to advance would spin forever.
        if (!next.isAfter(cursor)) break;
        cursor = next;
        generated++;
      }
      if (cursor != r.nextDue) {
        r.nextDue = cursor;
        await r.save();
      }
    }

    if (due.isNotEmpty) await expenseNotifier.addMissingById(due);
    _refresh();
  }

  static String _occurrenceId(String ruleId, DateTime due) =>
      'recurring:$ruleId:${due.year.toString().padLeft(4, '0')}-'
      '${due.month.toString().padLeft(2, '0')}-'
      '${due.day.toString().padLeft(2, '0')}';

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
