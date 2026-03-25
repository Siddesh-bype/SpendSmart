import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/income.dart';
import 'service_provider.dart';

final incomeProvider = NotifierProvider<IncomeNotifier, List<Income>>(IncomeNotifier.new);

class IncomeNotifier extends Notifier<List<Income>> {
  Box<Income> get _box => ref.read(storageServiceProvider).incomeBox;

  @override
  List<Income> build() {
    return _box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> addIncome(Income income) async {
    await _box.put(income.id, income);
    state = _box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> deleteIncome(String id) async {
    await _box.delete(id);
    state = _box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }
}
