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

  Future<void> updateLending(Lending lending) async {
    if (state.every((entry) => entry.id != lending.id)) return;
    await ref.read(storageServiceProvider).saveLending(lending);
    _reload();
  }

  Future<void> settle(String id) async {
    final index = state.indexWhere((e) => e.id == id);
    if (index == -1) return; // already deleted
    final settled = state[index].copyWith(isSettled: true);
    await ref.read(storageServiceProvider).saveLending(settled);
    _reload();
  }

  Future<Lending?> deleteLending(String id) async {
    Lending? deleted;
    for (final entry in state) {
      if (entry.id == id) {
        deleted = entry;
        break;
      }
    }
    if (deleted == null) return null;
    await ref.read(storageServiceProvider).deleteLending(id);
    _reload();
    return deleted;
  }

  Future<void> restoreLending(Lending lending) async {
    await ref.read(storageServiceProvider).saveLending(lending);
    _reload();
  }

  Future<int> settleAllForFriend(String friendName) async {
    final entries = state
        .where((entry) => entry.friendName == friendName && !entry.isSettled)
        .map((entry) => entry.copyWith(isSettled: true))
        .toList();
    for (final entry in entries) {
      await ref.read(storageServiceProvider).saveLending(entry);
    }
    if (entries.isNotEmpty) _reload();
    return entries.length;
  }
}
