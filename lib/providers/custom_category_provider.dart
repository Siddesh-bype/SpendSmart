import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/custom_category.dart';
import '../models/budget.dart';
import '../services/storage_service.dart';
import 'expense_provider.dart';
import 'budget_provider.dart';
import 'service_provider.dart';

final customCategoryProvider = NotifierProvider<CustomCategoryNotifier,
    List<CustomCategory>>(CustomCategoryNotifier.new);

class CustomCategoryNotifier extends Notifier<List<CustomCategory>> {
  @override
  List<CustomCategory> build() =>
      ref.watch(storageServiceProvider).getAllCustomCategories();

  void _reload() {
    state = ref.read(storageServiceProvider).getAllCustomCategories();
  }

  Future<void> add({
    required String name,
    int iconCodePoint = 0xe3b0,
    int colorValue = 0xFF9AB8EE,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('Category name is required.');
    if (state.any((value) => value.name.toLowerCase() == normalized.toLowerCase() && !value.archived)) {
      throw ArgumentError('A category with this name already exists.');
    }
    await ref.read(storageServiceProvider).saveCustomCategory(
          CustomCategory(
            id: const Uuid().v4(),
            name: normalized,
            iconCodePoint: iconCodePoint,
            colorValue: colorValue,
          ),
        );
    _reload();
  }

  Future<void> rename(CustomCategory category, String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('Category name is required.');
    if (state.any(
      (value) =>
          value.id != category.id &&
          !value.archived &&
          value.name.toLowerCase() == normalized.toLowerCase(),
    )) {
      throw ArgumentError('A category with this name already exists.');
    }
    final updated = category.copyWith(name: normalized);
    await ref.read(storageServiceProvider).saveCustomCategory(updated);
    _reload();
  }

  Future<void> archive(CustomCategory category) async {
    final updated = category.copyWith(archived: true);
    await ref.read(storageServiceProvider).saveCustomCategory(updated);
    _reload();
  }

  Future<void> unarchive(CustomCategory category) async {
    if (category.mergedIntoId != null) {
      throw StateError('A merged category cannot be restored.');
    }
    await ref
        .read(storageServiceProvider)
        .saveCustomCategory(category.copyWith(archived: false));
    _reload();
  }

  Future<void> delete(CustomCategory category) async {
    final storage = ref.read(storageServiceProvider);
    final isReferenced = storage.expenseBox.values.any(
      (expense) => expense.customCategoryId == category.id,
    );
    if (isReferenced) {
      throw StateError('Archive this category instead of deleting it.');
    }
    await storage.deleteCustomCategory(category.id);
    _reload();
  }

  Future<void> merge(CustomCategory source, CustomCategory destination) async {
    if (source.id == destination.id) {
      throw ArgumentError('Choose two different categories.');
    }
    if (source.archived || destination.archived) {
      throw ArgumentError('Only active categories can be combined.');
    }
    if (_wouldCreateMergeLoop(source.id, destination.id)) {
      throw ArgumentError('That combination would create a category loop.');
    }
    final storage = ref.read(storageServiceProvider);
    final affected = storage.expenseBox.values
        .where((expense) => expense.customCategoryId == source.id)
        .map(
          (expense) => expense.copyWith(customCategoryId: destination.id),
        )
        .toList();
    if (affected.isNotEmpty) {
      await storage.saveExpenses(affected);
      final verified = affected.every(
        (expense) => storage.expenseBox.get(expense.id)?.customCategoryId == destination.id,
      );
      if (!verified) throw StateError('Could not verify category merge.');
    }
    await _migrateBudget(storage, source.id, destination.id);
    final archivedSource = source.copyWith(
      archived: true,
      mergedIntoId: destination.id,
    );
    await storage.saveCustomCategory(archivedSource);
    _reload();
    ref.invalidate(expenseProvider);
    ref.invalidate(budgetProvider);
  }

  Future<void> _migrateBudget(
    StorageService storage,
    String sourceId,
    String destinationId,
  ) async {
    final budgets = storage.getAllBudgets();
    Budget? sourceBudget;
    Budget? destinationBudget;
    for (final budget in budgets) {
      if (budget.customCategoryId == sourceId) sourceBudget = budget;
      if (budget.customCategoryId == destinationId) {
        destinationBudget = budget;
      }
    }
    if (sourceBudget == null) return;
    if (destinationBudget == null) {
      await storage.saveBudget(
        sourceBudget.copyWith(customCategoryId: destinationId),
      );
    } else {
      await storage.saveBudget(
        destinationBudget.copyWith(
          monthlyLimit:
              destinationBudget.monthlyLimit + sourceBudget.monthlyLimit,
          alertAt: destinationBudget.alertAt < sourceBudget.alertAt
              ? destinationBudget.alertAt
              : sourceBudget.alertAt,
        ),
      );
    }
    await storage.deleteBudget(sourceBudget);
  }

  bool _wouldCreateMergeLoop(String sourceId, String destinationId) {
    final visited = <String>{};
    var current = destinationId;
    while (visited.add(current)) {
      if (current == sourceId) return true;
      CustomCategory? category;
      for (final value in state) {
        if (value.id == current) {
          category = value;
          break;
        }
      }
      final next = category?.mergedIntoId;
      if (next == null) return false;
      current = next;
    }
    return true;
  }
}
