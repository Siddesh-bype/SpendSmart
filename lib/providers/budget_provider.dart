import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../services/supabase_service.dart';
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
    // StorageService uses category.index as key — saving a 0-limit budget effectively removes it
    await ref.read(storageServiceProvider).saveBudget(budget);
    _loadBudgets();
    SupabaseService.upsertBudget(budget);
  }

  Future<void> deleteBudget(Category category) async {
    // Hive uses category.index as key — delete by key
    await ref.read(storageServiceProvider).budgetBox.delete(category.index);
    _loadBudgets();
    SupabaseService.deleteBudgetByCategory(category.name);
  }

  // Alias used by budget_screen UI
  Future<void> setBudget(Budget budget) => saveBudget(budget);

  /// Pull budgets from Supabase and merge locally
  Future<void> syncFromSupabase() async {
    final rows = await SupabaseService.fetchBudgets();
    for (final row in rows) {
      try {
        final catName = (row['category'] as String).toLowerCase();
        final cat = Category.values.firstWhere(
          (c) => c.name.toLowerCase() == catName,
          orElse: () => Category.other,
        );
        final budget = Budget(
          category: cat,
          monthlyLimit: (row['monthly_limit'] as num).toDouble(),
          alertAt: (row['alert_at'] as num?)?.toDouble() ?? 0.8,
        );
        await ref.read(storageServiceProvider).saveBudget(budget);
      } catch (_) {}
    }
    _loadBudgets();
  }
}
