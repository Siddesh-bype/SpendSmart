import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget.dart';
import '../models/category.dart';
import 'service_provider.dart';

final budgetProvider = NotifierProvider<BudgetNotifier, List<Budget>>(BudgetNotifier.new);

class BudgetNotifier extends Notifier<List<Budget>> {
  @override
  List<Budget> build() {
    return ref.watch(storageServiceProvider).getAllBudgets();
  }

  void _loadBudgets() {
    state = ref.read(storageServiceProvider).getAllBudgets();
  }

  Future<void> saveBudget(Budget budget) async {
    await ref.read(storageServiceProvider).saveBudget(budget);
    _loadBudgets();
  }

  Future<void> deleteBudget(Category category) async {
    await ref.read(storageServiceProvider).budgetBox.delete(category.index);
    _loadBudgets();
  }

  // Alias used by budget_screen UI
  Future<void> setBudget(Budget budget) => saveBudget(budget);
}
