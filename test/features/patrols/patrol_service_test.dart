import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/patrols/application/patrol_service.dart';
import 'package:rangernet/features/patrols/domain/patrol.dart';
import 'package:rangernet/features/patrols/domain/patrol_records.dart';
import 'package:rangernet/features/patrols/domain/patrol_repository.dart';

void main() {
  late _MemoryPatrolRepository repository;
  late PatrolService service;

  setUp(() {
    repository = _MemoryPatrolRepository();
    service = PatrolService(repository: repository);
  });

  test(
    'supports start, pause, resume, complete, and sync without duplicates',
    () async {
      await repository.save(_assignedPatrol());
      final start = DateTime.utc(2026, 4, 1, 8);
      final started = await service.start(
        rangerId: 'ranger-1',
        localId: 'local-1',
        location: _location(start),
        at: start,
      );
      expect(started.status, PatrolStatus.inProgress);

      final paused = await service.pause(
        rangerId: 'ranger-1',
        localId: 'local-1',
        at: start.add(const Duration(minutes: 10)),
        reason: 'Rest',
      );
      expect(paused.status, PatrolStatus.paused);

      final resumed = await service.resume(
        rangerId: 'ranger-1',
        localId: 'local-1',
        at: start.add(const Duration(minutes: 20)),
      );
      expect(resumed.status, PatrolStatus.inProgress);
      expect(resumed.pauseResumeEvents, hasLength(2));

      final completed = await service.complete(
        rangerId: 'ranger-1',
        localId: 'local-1',
        endLocation: _location(start.add(const Duration(hours: 1))),
        at: start.add(const Duration(hours: 1)),
      );
      expect(completed.status, PatrolStatus.completedPendingSync);
      expect(completed.completionState, PatrolCompletionState.completed);

      final synced = await service.markCompletedSynced(
        rangerId: 'ranger-1',
        localId: 'local-1',
        syncedAt: start.add(const Duration(hours: 2)),
      );
      expect(synced.status, PatrolStatus.completedSynced);
      expect(synced.syncInfo.status, PatrolSyncStatus.synced);
      await expectLater(
        service.complete(
          rangerId: 'ranger-1',
          localId: 'local-1',
          endLocation: _location(start.add(const Duration(hours: 3))),
          at: start.add(const Duration(hours: 3)),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'rejects empty termination reason and supports critical interruption recovery',
    () async {
      await repository.save(_assignedPatrol());
      final start = DateTime.utc(2026, 4, 1, 8);
      await service.start(
        rangerId: 'ranger-1',
        localId: 'local-1',
        location: _location(start),
        at: start,
      );
      await expectLater(
        service.interrupt(
          rangerId: 'ranger-1',
          localId: 'local-1',
          reason: ' ',
        ),
        throwsArgumentError,
      );
      final interrupted = await service.interrupt(
        rangerId: 'ranger-1',
        localId: 'local-1',
        reason: 'Critical incident response',
      );
      expect(interrupted.status, PatrolStatus.interrupted);
      expect(interrupted.endedAt, isNull);

      final recovered = await service.resume(
        rangerId: 'ranger-1',
        localId: 'local-1',
        at: start.add(const Duration(minutes: 5)),
      );
      expect(recovered.status, PatrolStatus.inProgress);
      expect(recovered.interruptionReason, isNull);
    },
  );

  test(
    'records manual waypoints and observations only for an active patrol',
    () async {
      final start = DateTime.utc(2026, 4, 1, 8);
      await repository.save(_assignedPatrol());
      await service.start(
        rangerId: 'ranger-1',
        localId: 'local-1',
        location: _location(start),
        at: start,
      );
      final waypoint = await service.addManualWaypoint(
        rangerId: 'ranger-1',
        localId: 'local-1',
        waypoint: PatrolWaypoint(
          id: 'waypoint-1',
          description: 'Manual waypoint',
          location: PatrolLocation(
            latitude: 6.2,
            longitude: 81.3,
            recordedAt: start,
            source: PatrolLocationSource.manual,
          ),
        ),
      );
      expect(waypoint.manualWaypoints, hasLength(1));
      expect(
        waypoint.manualWaypoints.single.location.source,
        PatrolLocationSource.manual,
      );

      await service.abort(
        rangerId: 'ranger-1',
        localId: 'local-1',
        reason: 'Weather conditions',
        at: start.add(const Duration(minutes: 10)),
      );
      await expectLater(
        service.addObservation(
          rangerId: 'ranger-1',
          localId: 'local-1',
          observation: PatrolObservation(
            id: 'observation-1',
            description: 'Not allowed after termination',
            location: _location(start),
          ),
        ),
        throwsStateError,
      );
    },
  );
}

class _MemoryPatrolRepository implements PatrolRepository {
  final Map<String, Patrol> _patrols = {};

  @override
  Future<Patrol?> findByLocalId(String rangerId, String localId) async {
    final patrol = _patrols[localId];
    return patrol?.rangerId == rangerId ? patrol : null;
  }

  @override
  Future<List<Patrol>> listForRanger(String rangerId) async => _patrols.values
      .where((patrol) => patrol.rangerId == rangerId)
      .toList(growable: false);

  @override
  Future<void> save(Patrol patrol) async {
    _patrols[patrol.localId] = patrol;
  }
}

Patrol _assignedPatrol() => Patrol(
  patrolId: 'patrol-1',
  localId: 'local-1',
  rangerId: 'ranger-1',
  rangerName: 'Ranger One',
  area: const PatrolArea(
    parkName: 'North Park',
    zoneName: 'North Zone',
    routeName: 'River Route',
  ),
);

PatrolLocation _location(DateTime time) => PatrolLocation(
  latitude: 6.1,
  longitude: 81.2,
  recordedAt: time,
  source: PatrolLocationSource.gps,
);
