import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/merchant_memory.dart';
import '../models/category.dart';
import 'service_provider.dart';

final merchantNotifierProvider = NotifierProvider<MerchantMemoryNotifier, List<MerchantMemory>>(MerchantMemoryNotifier.new);

class MerchantMemoryNotifier extends Notifier<List<MerchantMemory>> {
  @override
  List<MerchantMemory> build() {
    return ref.watch(storageServiceProvider).merchantBox.values.toList();
  }

  void _loadMerchants() {
    state = ref.read(storageServiceProvider).merchantBox.values.toList();
  }

  /// Re-teaches [name] after the user picks a different category.
  Future<void> correctMerchant(String name, Category category) async {
    await ref.read(storageServiceProvider).saveMerchantMemory(name, category);
    _loadMerchants();
  }

  Category? lookupCategory(String rawMerchant) =>
      ref.read(storageServiceProvider).lookupMerchantCategory(rawMerchant);
}
