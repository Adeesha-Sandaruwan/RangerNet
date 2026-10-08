import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/patrols/data/local_patrol_repository.dart';
import 'package:rangernet/features/patrols/data/patrol_codec.dart';
import 'package:rangernet/features/patrols/data/patrol_local_store.dart';
import 'package:rangernet/features/patrols/domain/patrol.dart';
import 'package:rangernet/features/patrols/domain/patrol_records.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalPatrolRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = LocalPatrolRepository();
  });

  test(
    'persists patrol records and replaces by local ID without duplicates',
    () async {
      final patrol = _patrol();
      await repository.save(patrol);
      await repository.save(patrol.copyWith(rangerName: 'Updated Ranger'));

      final loaded = await repository.listForRanger('ranger-1');
      expect(loaded, hasLength(1));
      expect(loaded.single.rangerName, 'Updated Ranger');
      expect(await repository.findByLocalId('ranger-1', 'local-1'), isNotNull);
    },
  );

  test('restores an active patrol and all field records after repository restart', () async {
    final active = _patrol();
    await repository.save(active);
    final restartedRepository = LocalPatrolRepository();

    final restored = await restartedRepository.findByLocalId(
      active.rangerId,
      active.localId,
    );

    expect(restored, isNotNull);
    expect(restored!.status, PatrolStatus.inProgress);
    expect(restored.routePoints, hasLength(1));
    expect(restored.manualWaypoints, hasLength(1));
    expect(restored.observations, hasLength(1));
    expect(restored.photographs, hasLength(1));
    expect(restored.pauseResumeEvents, hasLength(1));
  });

  test('storage-full failure is reported and does not replace prior local data', () async {
    final original = _patrol();
    await repository.save(original);
    final failingRepository = LocalPatrolRepository(
      store: PatrolLocalStore(writeValue: (key, value) async => false),
    );

    await expectLater(
      failingRepository.save(original.copyWith(rangerName: 'Not persisted')),
      throwsStateError,
    );

    final saved = (await repository.listForRanger(original.rangerId)).single;
    expect(saved.rangerName, original.rangerName);
  });

  test(
    'prevents a local ID or remote patrol ID from being reassigned',
    () async {
      final patrol = _patrol();
      await repository.save(patrol);
      await expectLater(
        repository.save(
          Patrol(
            patrolId: 'different-patrol',
            localId: patrol.localId,
            rangerId: patrol.rangerId,
            rangerName: patrol.rangerName,
            area: patrol.area,
          ),
        ),
        throwsStateError,
      );
      await expectLater(
        repository.save(
          Patrol(
            patrolId: patrol.patrolId,
            localId: 'different-local-id',
            rangerId: patrol.rangerId,
            rangerName: patrol.rangerName,
            area: patrol.area,
          ),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'round-trips route, observations, photos, events, and sync metadata',
    () {
      final patrol = _patrol();
      final decoded = PatrolCodec.decode(PatrolCodec.encode(patrol));

      expect(decoded.patrolId, patrol.patrolId);
      expect(decoded.localId, patrol.localId);
      expect(decoded.area.routeName, 'River Route');
      expect(decoded.status, PatrolStatus.inProgress);
      expect(
        decoded.routePoints.single.location.source,
        PatrolLocationSource.gps,
      );
      expect(
        decoded.manualWaypoints.single.location.source,
        PatrolLocationSource.manual,
      );
      expect(decoded.observations.single.description, 'Animal tracks');
      expect(decoded.photographs.single.observationId, 'observation-1');
      expect(
        decoded.pauseResumeEvents.single.action,
        PatrolPauseResumeAction.pause,
      );
      expect(decoded.syncInfo.status, PatrolSyncStatus.pendingSync);
      expect(decoded.syncInfo.lastError, isNull);
      expect(decoded.coverage?.uncoveredSectionIds, ['section-3']);
    },
  );

  test(
    'rejects corrupted saved patrol data rather than silently dropping it',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('patrol_records_v1_ranger-1', '{bad json');

      await expectLater(
        repository.listForRanger('ranger-1'),
        throwsFormatException,
      );
    },
  );
}

Patrol _patrol() {
  final time = DateTime.utc(2026, 5, 2, 7);
  final gps = PatrolLocation(
    latitude: 6.1,
    longitude: 81.2,
    recordedAt: time,
    source: PatrolLocationSource.gps,
    accuracyMeters: 5,
  );
  final manual = PatrolLocation(
    latitude: 6.2,
    longitude: 81.3,
    recordedAt: time.add(const Duration(minutes: 10)),
    source: PatrolLocationSource.manual,
  );
  return Patrol(
    patrolId: 'patrol-1',
    localId: 'local-1',
    rangerId: 'ranger-1',
    rangerName: 'Ranger One',
    area: const PatrolArea(
      parkId: 'park-1',
      parkName: 'North Park',
      zoneId: 'zone-1',
      zoneName: 'North Zone',
      routeId: 'route-1',
      routeName: 'River Route',
    ),
    status: PatrolStatus.inProgress,
    assignedAt: time.subtract(const Duration(days: 1)),
    startedAt: time,
    startLocation: gps,
    routePoints: [PatrolRoutePoint(id: 'point-1', location: gps)],
    manualWaypoints: [
      PatrolWaypoint(
        id: 'waypoint-1',
        description: 'Manual route marker',
        location: manual,
      ),
    ],
    observations: [
      PatrolObservation(
        id: 'observation-1',
        description: 'Animal tracks',
        category: 'wildlife',
        location: manual,
      ),
    ],
    photographs: [
      PatrolPhoto(
        id: 'photo-1',
        fileName: 'tracks.jpg',
        contentType: 'image/jpeg',
        base64Data: 'cGhvdG8=',
        capturedAt: time.add(const Duration(minutes: 11)),
        observationId: 'observation-1',
      ),
    ],
    pauseResumeEvents: [
      PatrolPauseResumeEvent(
        id: 'event-1',
        action: PatrolPauseResumeAction.pause,
        occurredAt: time.add(const Duration(minutes: 20)),
        reason: 'Rest break',
      ),
    ],
    syncInfo: PatrolSyncInfo(
      status: PatrolSyncStatus.pendingSync,
      lastAttemptAt: time.add(const Duration(minutes: 30)),
    ),
    coverage: PatrolCoverage(
      totalSections: 3,
      coveredSections: 2,
      uncoveredSectionIds: const ['section-3'],
      calculatedAt: time.add(const Duration(hours: 1)),
    ),
  );
}
