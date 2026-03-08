import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lending.dart';
import 'service_provider.dart';

final lendingProvider =
    NotifierProvider<LendingNotifier, List<Lending>>(LendingNotifier.new);

class LendingNotifier extends Notifier<List<Lending>> {
  @override
  List<Lending> build() {
    return ref.watch(storageServiceProvider).getAllLendings();
  }

  void _reload() {
    state = ref.read(storageServiceProvider).getAllLendings();
  }

  Future<void> addLending(Lending lending) async {
    await ref.read(storageServiceProvider).saveLending(lending);
    _reload();
  }

  Future<void> settle(String id) async {
    final l = state.firstWhere((e) => e.id == id);
    l.isSettled = true;
    await ref.read(storageServiceProvider).saveLending(l);
    _reload();
  }

  Future<void> deleteLending(String id) async {
    await ref.read(storageServiceProvider).deleteLending(id);
    _reload();
  }
}
