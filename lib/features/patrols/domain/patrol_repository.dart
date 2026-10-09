import 'patrol.dart';

/// ISP: small local patrol persistence port used by the application service.
abstract interface class PatrolRepository {
  /// Finds a ranger-owned patrol by its stable local ID.
  Future<Patrol?> findByLocalId(String rangerId, String localId);

  /// Lists locally stored patrols belonging to a ranger.
  Future<List<Patrol>> listForRanger(String rangerId);

  /// Saves or replaces the local representation of a patrol.
  Future<void> save(Patrol patrol);
}

/// ISP: small source boundary for assigned patrol snapshots and live assignment updates.
abstract interface class PatrolAssignmentSource {
  /// Loads the current server assignments for a ranger.
  Future<List<Patrol>> loadAssignedTo(String rangerId);

  /// Streams assignment updates for a ranger.
  Stream<List<Patrol>> watchAssignedTo(String rangerId);
}

/// ISP: small remote-sync boundary for submitting a completed patrol.
abstract interface class PatrolSyncRepository {
  /// Submits a completed patrol to the configured remote system.
  Future<void> syncCompletedPatrol(Patrol patrol);
}
