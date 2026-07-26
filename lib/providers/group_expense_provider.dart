import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_expense.dart';
import 'service_provider.dart';

final groupExpenseProvider =
    NotifierProvider<GroupExpenseNotifier, List<GroupExpense>>(
      GroupExpenseNotifier.new,
    );

class GroupExpenseNotifier extends Notifier<List<GroupExpense>> {
  @override
  List<GroupExpense> build() {
    return ref.watch(storageServiceProvider).getAllGroupExpenses();
  }

  void _reload() {
    state = ref.read(storageServiceProvider).getAllGroupExpenses();
  }

  Future<void> addExpense(GroupExpense expense) async {
    await ref.read(storageServiceProvider).saveGroupExpense(expense);
    _reload();
  }

  Future<void> updateExpense(GroupExpense expense) async {
    await ref.read(storageServiceProvider).saveGroupExpense(expense);
    _reload();
  }

  Future<void> deleteExpense(String id) async {
    await ref.read(storageServiceProvider).deleteGroupExpense(id);
    _reload();
  }

  Future<void> settleExpense(String id) async {
    final index = state.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final expense = state[index];
    final updated = expense.copyWith(isSettled: true);
    await ref.read(storageServiceProvider).saveGroupExpense(updated);
    _reload();
  }
}
