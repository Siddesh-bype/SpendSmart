import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/split_group.dart';
import 'service_provider.dart';

final splitGroupProvider =
    NotifierProvider<SplitGroupNotifier, List<SplitGroup>>(
      SplitGroupNotifier.new,
    );

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

  /// Sets which participant counts as "me" for [groupId] balance purposes.
  /// Unknown participant ids are ignored (state untouched).
  Future<void> setMyParticipant(String groupId, String participantId) async {
    SplitGroup? group;
    for (final g in state) {
      if (g.id == groupId) group = g;
    }
    if (group == null) return;
    if (group.participants.every((p) => p.id != participantId)) return;
    group.myParticipantId = participantId;
    await ref.read(storageServiceProvider).saveSplitGroup(group);
    _reload();
  }

  Future<void> deleteGroup(String id) async {
    final storage = ref.read(storageServiceProvider);
    for (final expense in storage.getAllGroupExpenses().where(
      (e) => e.groupId == id,
    )) {
      await storage.deleteGroupExpense(expense.id);
    }
    await storage.deleteSplitGroup(id);
    _reload();
  }
}
