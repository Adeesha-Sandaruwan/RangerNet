import 'dart:async';

import '../domain/patrol.dart';
import '../domain/patrol_repository.dart';
import 'patrol_local_store.dart';

class LocalPatrolRepository implements PatrolRepository {
  LocalPatrolRepository({PatrolLocalStore? store})
    : _store = store ?? PatrolLocalStore();

  final PatrolLocalStore _store;
  Future<void> _writeTail = Future<void>.value();

  @override
  Future<Patrol?> findByLocalId(String rangerId, String localId) async {
    final patrols = await _store.loadForRanger(rangerId);
    for (final patrol in patrols) {
      if (patrol.localId == localId) return patrol;
    }
    return null;
  }

  @override
  Future<List<Patrol>> listForRanger(String rangerId) =>
      _store.loadForRanger(rangerId);

  @override
  Future<void> save(Patrol patrol) => _serializeWrite(() async {
    final patrols = (await _store.loadForRanger(patrol.rangerId)).toList();
    final index = patrols.indexWhere((item) => item.localId == patrol.localId);
    if (index < 0) {
      if (patrols.any((item) => item.patrolId == patrol.patrolId)) {
        throw StateError(
          'This patrol ID is already stored under a different local ID.',
        );
      }
      patrols.add(patrol);
    } else {
      if (patrols[index].patrolId != patrol.patrolId) {
        throw StateError(
          'A local patrol ID cannot be reused for another patrol.',
        );
      }
      patrols[index] = patrol;
    }
    await _store.replaceForRanger(patrol.rangerId, patrols);
  });

  Future<void> _serializeWrite(Future<void> Function() operation) async {
    final previous = _writeTail;
    final completed = Completer<void>();
    _writeTail = completed.future;
    await previous;
    try {
      await operation();
    } finally {
      completed.complete();
    }
  }
}
