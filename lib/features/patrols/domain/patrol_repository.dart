import 'patrol.dart';

abstract interface class PatrolRepository {
  Future<Patrol?> findByLocalId(String rangerId, String localId);

  Future<List<Patrol>> listForRanger(String rangerId);

  Future<void> save(Patrol patrol);
}

abstract interface class PatrolAssignmentSource {
  Future<List<Patrol>> loadAssignedTo(String rangerId);

  Stream<List<Patrol>> watchAssignedTo(String rangerId);
}

abstract interface class PatrolSyncRepository {
  Future<void> syncCompletedPatrol(Patrol patrol);
}
