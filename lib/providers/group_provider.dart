import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/split_group.dart';
import 'service_provider.dart';

final splitGroupProvider =
    NotifierProvider<SplitGroupNotifier, List<SplitGroup>>(SplitGroupNotifier.new);

class SplitGroupNotifier extends Notifier<List<SplitGroup>> {
  @override
  List<SplitGroup> build() {
    return ref.watch(storageServiceProvider).getAllSplitGroups();
  }

  void _reload() {
    state = ref.read(storageServiceProvider).getAllSplitGroups();
  }

  Future<void> addGroup(SplitGroup group) async {
    await ref.read(storageServiceProvider).saveSplitGroup(group);
    _reload();
  }

  Future<void> updateGroup(SplitGroup group) async {
    await ref.read(storageServiceProvider).saveSplitGroup(group);
    _reload();
  }

  Future<void> deleteGroup(String id) async {
    await ref.read(storageServiceProvider).deleteSplitGroup(id);
    _reload();
  }
}
