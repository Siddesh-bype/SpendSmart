import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lending.dart';
import '../services/supabase_service.dart';
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
    SupabaseService.upsertLending(lending);
  }

  Future<void> settle(String id) async {
    final l = state.firstWhere((e) => e.id == id);
    l.isSettled = true;
    await ref.read(storageServiceProvider).saveLending(l);
    _reload();
    SupabaseService.upsertLending(l);
  }

  Future<void> deleteLending(String id) async {
    await ref.read(storageServiceProvider).deleteLending(id);
    _reload();
    SupabaseService.deleteLending(id);
  }

  /// Pull lendings from Supabase and merge locally
  Future<void> syncFromSupabase() async {
    final rows = await SupabaseService.fetchLendings();
    for (final row in rows) {
      try {
        final lending = SupabaseService.rowToLending(row);
        final alreadyExists = state.any((e) => e.id == lending.id);
        if (!alreadyExists) {
          await ref.read(storageServiceProvider).saveLending(lending);
        }
      } catch (_) {}
    }
    _reload();
  }
}
