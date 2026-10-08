import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/patrols/application/patrol_service.dart';
import 'package:rangernet/features/patrols/domain/patrol.dart';
import 'package:rangernet/features/patrols/domain/patrol_records.dart';
import 'package:rangernet/features/patrols/domain/patrol_repository.dart';

void main() {
  test(
    'loads server assignments into list and caches them for offline use',
    () async {
      final repository = _MemoryPatrolRepository();
      final assignment = _assignedPatrol();
      final service = PatrolService(
        repository: repository,
        assignmentSource: _FakeAssignmentSource([assignment]),
      );

      final result = await service.loadAssignedPatrols('ranger-1');

      expect(result.assignmentError, isNull);
      expect(result.patrols, hasLength(1));
      expect(result.patrols.single.patrolId, 'patrol-from-manager');
      expect(
        (await repository.listForRanger('ranger-1')).single.localId,
        'local-patrol-id',
      );
    },
  );

  test(
    'keeps a fetched assignment visible when local cache write fails',
    () async {
      final assignment = _assignedPatrol();
      final service = PatrolService(
        repository: _MemoryPatrolRepository(failWrites: true),
        assignmentSource: _FakeAssignmentSource([assignment]),
      );

      final result = await service.loadAssignedPatrols('ranger-1');

      expect(result.patrols, hasLength(1));
      expect(result.patrols.single.patrolId, assignment.patrolId);
      expect(result.assignmentError, isNotNull);
    },
  );

  test(
    'keeps cached assignments available when server refresh fails',
    () async {
      final repository = _MemoryPatrolRepository()..seed(_assignedPatrol());
      final service = PatrolService(
        repository: repository,
        assignmentSource: _FakeAssignmentSource(
          const [],
          error: StateError('offline'),
        ),
      );

      final result = await service.loadAssignedPatrols('ranger-1');

      expect(result.patrols, hasLength(1));
      expect(result.patrols.single.patrolId, 'patrol-from-manager');
      expect(result.assignmentError, isNotNull);
    },
  );

  test(
    'live assignment updates are merged and cached for the ranger',
    () async {
      final repository = _MemoryPatrolRepository();
      final service = PatrolService(
        repository: repository,
        assignmentSource: _FakeAssignmentSource([_assignedPatrol()]),
      );

      final result = await service.watchAssignedPatrols('ranger-1').first;

      expect(result.patrols.single.patrolId, 'patrol-from-manager');
      expect(
        await repository.findByLocalId('ranger-1', 'local-patrol-id'),
        isNotNull,
      );
    },
  );

  test(
    'new map route is merged into cached assigned patrol without changing local ID',
    () async {
      final remoteAssignment = _assignedPatrol();
      final cachedAssignment = remoteAssignment.copyWith(
        plannedRoute: null,
        clearPlannedRoute: true,
      );
      final repository = _MemoryPatrolRepository()..seed(cachedAssignment);
      final service = PatrolService(
        repository: repository,
        assignmentSource: _FakeAssignmentSource([remoteAssignment]),
      );

      final result = await service.loadAssignedPatrols('ranger-1');
      final patrol = result.patrols.single;

      expect(patrol.localId, cachedAssignment.localId);
      expect(patrol.plannedRoute?.start.name, 'Start');
      expect(patrol.plannedRoute?.stops.single.name, 'River bend');
      expect(
        (await repository.findByLocalId(
          'ranger-1',
          cachedAssignment.localId,
        ))?.plannedRoute,
        isNotNull,
      );
    },
  );
}

class _MemoryPatrolRepository implements PatrolRepository {
  _MemoryPatrolRepository({this.failWrites = false});

  final bool failWrites;
  final Map<String, Patrol> _patrols = {};

  void seed(Patrol patrol) => _patrols[patrol.localId] = patrol;

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
    if (failWrites) throw StateError('Device storage is full');
    _patrols[patrol.localId] = patrol;
  }
}

class _FakeAssignmentSource implements PatrolAssignmentSource {
  _FakeAssignmentSource(this.assignments, {this.error});

  final List<Patrol> assignments;
  final Object? error;

  @override
  Future<List<Patrol>> loadAssignedTo(String rangerId) async {
    if (error case final error?) throw error;
    return assignments.where((patrol) => patrol.rangerId == rangerId).toList();
  }

  @override
  Stream<List<Patrol>> watchAssignedTo(String rangerId) {
    if (error case final error?) return Stream.error(error);
    return Stream.value(
      assignments.where((patrol) => patrol.rangerId == rangerId).toList(),
    );
  }
}

Patrol _assignedPatrol() => Patrol(
  patrolId: 'patrol-from-manager',
  localId: 'local-patrol-id',
  rangerId: 'ranger-1',
  rangerName: 'Ranger One',
  area: const PatrolArea(
    parkName: 'North Park',
    zoneName: 'North Zone',
    routeName: 'River Route',
  ),
  assignedAt: DateTime.utc(2026, 10, 8),
  plannedRoute: PatrolRoutePlan(
    start: PatrolCoverageCheckpoint(
      id: 'route-start',
      name: 'Start',
      latitude: 6.1,
      longitude: 81.2,
    ),
    stops: [
      PatrolCoverageCheckpoint(
        id: 'stop-1',
        name: 'River bend',
        latitude: 6.11,
        longitude: 81.21,
      ),
    ],
    end: PatrolCoverageCheckpoint(
      id: 'route-end',
      name: 'Destination',
      latitude: 6.12,
      longitude: 81.22,
    ),
    coverageSections: [
      PatrolCoverageCheckpoint(
        id: 'section-1',
        name: 'Route section 1',
        latitude: 6.1,
        longitude: 81.2,
      ),
    ],
  ),
);
