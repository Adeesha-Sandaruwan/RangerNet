import 'dart:async';

import '../domain/patrol.dart';
import '../domain/patrol_repository.dart';
import 'patrol_local_store.dart';

/// Local repository adapter backed by PatrolLocalStore. DIP/LSP: implements PatrolRepository for application services.
class LocalPatrolRepository implements PatrolRepository {
  /// Creates the adapter with an injectable local store.
  LocalPatrolRepository({PatrolLocalStore? store})
    : _store = store ?? PatrolLocalStore();

  /// Store used to read and replace persisted patrol queues.
  final PatrolLocalStore _store;

  /// Tail of the per-instance write queue, preventing overlapping read-modify-writes.
  Future<void> _writeTail = Future<void>.value();

  /// Finds a patrol by its stable local identifier within one ranger queue.
  @override
  Future<Patrol?> findByLocalId(String rangerId, String localId) async {
    final patrols = await _store.loadForRanger(rangerId);
    for (final patrol in patrols) {
      if (patrol.localId == localId) return patrol;
    }
    return null;
  }

  /// Returns all locally saved patrols for rangerId.
  @override
  Future<List<Patrol>> listForRanger(String rangerId) =>
      _store.loadForRanger(rangerId);

  /// Inserts or replaces a patrol while preserving its stable identifiers.
  @override
  Future<void> save(Patrol patrol) => _serializeWrite(() async {
    final patrols = (await _store.loadForRanger(patrol.rangerId)).toList();
    final index = patrols.indexWhere(
      (item) =>
          item.localId == patrol.localId || item.patrolId == patrol.patrolId,
    );
    if (index < 0) {
      if (patrols.any((item) => item.patrolId == patrol.patrolId)) {
        throw StateError(
          'This patrol ID is already stored under a different local ID.',
        );
      }
      patrols.add(patrol);
    } else {
      if (patrols[index].patrolId != patrol.patrolId ||
          patrols[index].localId != patrol.localId) {
        throw StateError(
          'A local patrol ID cannot be reused for another patrol.',
        );
      }
      patrols[index] = patrol;
    }
    await _store.replaceForRanger(patrol.rangerId, patrols);
  });

  /// Queues this read-modify-write behind prior writes in this repository instance.
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
