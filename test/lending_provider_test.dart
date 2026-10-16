import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/models/lending.dart';
import 'package:spendsmart/providers/lending_provider.dart';
import 'package:spendsmart/providers/service_provider.dart';
import 'package:spendsmart/services/storage_service.dart';

Lending _lending(
  String id, {
  String friendName = 'Asha',
  double amount = 100,
  bool isIGave = true,
  bool isSettled = false,
  String note = '',
}) => Lending(
  id: id,
  friendName: friendName,
  amount: amount,
  isIGave: isIGave,
  date: DateTime(2026, 7, 10),
  note: note,
  isSettled: isSettled,
);

void main() {
  test('edits and persists every editable lending field', () async {
    final original = _lending('one');
    final storage = _FakeLendingStorage([original]);
    final container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    await container.read(lendingProvider.notifier).updateLending(
          original.copyWith(
            friendName: 'Ben',
            amount: 275.5,
            isIGave: false,
            note: 'Dinner',
          ),
        );

    final updated = container.read(lendingProvider).single;
    expect(updated.friendName, 'Ben');
    expect(updated.amount, 275.5);
    expect(updated.isIGave, isFalse);
    expect(updated.note, 'Dinner');
    expect(storage.lendings.single.friendName, 'Ben');
  });

  test('deletes an entry and returns it for undo restoration', () async {
    final deleted = _lending('one');
    final storage = _FakeLendingStorage([deleted, _lending('two')]);
    final container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final removed = await container.read(lendingProvider.notifier).deleteLending(
          deleted.id,
        );

    expect(removed?.id, deleted.id);
    expect(container.read(lendingProvider).map((entry) => entry.id), ['two']);
    expect(storage.lendings.map((entry) => entry.id), ['two']);

    await container.read(lendingProvider.notifier).restoreLending(removed!);
    expect(container.read(lendingProvider).map((entry) => entry.id), [
      'one',
      'two',
    ]);
  });

  test('settles all active entries for one friend only', () async {
    final storage = _FakeLendingStorage([
      _lending('asha-one'),
      _lending('asha-two', amount: 50, isIGave: false),
      _lending('asha-old', isSettled: true),
      _lending('ben-one', friendName: 'Ben'),
    ]);
    final container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final changed = await container
        .read(lendingProvider.notifier)
        .settleAllForFriend('Asha');

    expect(changed, 2);
    final entries = container.read(lendingProvider);
    expect(
      entries.where((entry) => entry.friendName == 'Asha'),
      everyElement(
        isA<Lending>().having((entry) => entry.isSettled, 'isSettled', isTrue),
      ),
    );
    expect(
      entries.singleWhere((entry) => entry.friendName == 'Ben').isSettled,
      isFalse,
    );
  });
}

class _FakeLendingStorage extends StorageService {
  _FakeLendingStorage(Iterable<Lending> initial) : lendings = [...initial];

  final List<Lending> lendings;

  // Mirrors Hive: box values iterate in sorted key (id) order, so same-date
  // entries tie-break by id.
  @override
  List<Lending> getAllLendings() => lendings.toList()
    ..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });

  @override
  Future<void> saveLending(Lending lending) async {
    lendings.removeWhere((entry) => entry.id == lending.id);
    lendings.add(lending);
  }

  @override
  Future<void> deleteLending(String id) async {
    lendings.removeWhere((entry) => entry.id == id);
  }
}
