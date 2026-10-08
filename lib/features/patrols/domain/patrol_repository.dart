import 'patrol.dart';

abstract interface class PatrolRepository {
  Future<Patrol?> findByLocalId(String rangerId, String localId);

  Future<List<Patrol>> listForRanger(String rangerId);

  Future<void> save(Patrol patrol);
}
