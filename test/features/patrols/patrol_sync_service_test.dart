// Coverage: completed-patrol synchronization; checks offline and remote
// failures, retries, persisted syncing state, and duplicate concurrent requests.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/patrols/application/patrol_service.dart';
import 'package:rangernet/features/patrols/application/patrol_sync_service.dart';
import 'package:rangernet/features/patrols/data/local_patrol_repository.dart';
import 'package:rangernet/features/patrols/domain/patrol.dart';
import 'package:rangernet/features/patrols/domain/patrol_network_status.dart';
import 'package:rangernet/features/patrols/domain/patrol_records.dart';
import 'package:rangernet/features/patrols/domain/patrol_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalPatrolRepository repository;
  late PatrolService patrolService;
  late _FakeNetworkStatus network;
  late _FakeSyncRepository remote;
  late PatrolSyncService syncService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = LocalPatrolRepository();
    patrolService = PatrolService(repository: repository);
    network = _FakeNetworkStatus();
    remote = _FakeSyncRepository();
    syncService = PatrolSyncService(
      patrolService: patrolService,
      syncRepository: remote,
      networkStatus: network,
    );
  });

  tearDown(() async {
    await network.dispose();
  });

  test(
    'offline completion stays local then syncs exactly once on restoration',
    () async {
      final completed = await _saveCompletedPatrol(patrolService);

      await expectLater(syncService.synchronize(completed), throwsStateError);
      final failedLocally = (await repository.listForRanger('ranger-1')).single;
      expect(failedLocally.status, PatrolStatus.completedPendingSync);
      expect(failedLocally.syncInfo.status, PatrolSyncStatus.failed);
      expect(failedLocally.syncInfo.lastError, isNotEmpty);
      expect(remote.calls, 0);

      network.online = true;
      final retry = await syncService.synchronizePending('ranger-1');
      expect(retry.synchronizedCount, 1);
      expect(retry.failures, isEmpty);

      final synced = (await repository.listForRanger('ranger-1')).single;
      expect(synced.status, PatrolStatus.completedSynced);
      expect(synced.syncInfo.status, PatrolSyncStatus.synced);
      expect(synced.syncInfo.lastSyncedAt, isNotNull);
      expect(remote.calls, 1);

      final staleRepeat = await syncService.synchronize(completed);
      expect(staleRepeat.status, PatrolStatus.completedSynced);
      expect(remote.calls, 1);
    },
  );

  test(
    'remote failure is recorded and manual retry preserves all local records',
    () async {
      final completed = await _saveCompletedPatrol(patrolService);
      network.online = true;
      remote.failure = StateError('server unavailable');

      await expectLater(syncService.synchronize(completed), throwsStateError);
      final afterFailure = (await repository.listForRanger('ranger-1')).single;
      expect(afterFailure.status, PatrolStatus.completedPendingSync);
      expect(afterFailure.syncInfo.status, PatrolSyncStatus.failed);
      expect(afterFailure.syncInfo.lastError, contains('server unavailable'));
      expect(afterFailure.routePoints, hasLength(1));
      expect(afterFailure.manualWaypoints, hasLength(1));
      expect(afterFailure.observations, hasLength(1));
      expect(afterFailure.photographs, hasLength(1));
      expect(afterFailure.pauseResumeEvents, hasLength(2));

      remote.failure = null;
      final retried = await syncService.synchronize(afterFailure);
      expect(retried.status, PatrolStatus.completedSynced);
      expect(remote.calls, 2);
    },
  );

  test(
    'duplicate concurrent requests share a single remote submission',
    () async {
      final completed = await _saveCompletedPatrol(patrolService);
      network.online = true;
      final remoteStarted = Completer<void>();
      final allowRemoteToFinish = Completer<void>();
      remote.beforeComplete = () async {
        if (!remoteStarted.isCompleted) remoteStarted.complete();
        await allowRemoteToFinish.future;
      };

      final first = syncService.synchronize(completed);
      await remoteStarted.future;
      final second = syncService.synchronize(completed);
      expect(remote.calls, 1);

      allowRemoteToFinish.complete();
      final outcomes = await Future.wait([first, second]);
      expect(
        outcomes.every((item) => item.status == PatrolStatus.completedSynced),
        isTrue,
      );
      expect(remote.calls, 1);
    },
  );

  test('restart retries a persisted syncing state', () async {
    final completed = await _saveCompletedPatrol(patrolService);
    await patrolService.markSyncing(
      rangerId: completed.rangerId,
      localId: completed.localId,
      attemptedAt: DateTime.utc(2026, 10, 8),
    );

    final restartedRepository = LocalPatrolRepository();
    final restartedService = PatrolService(repository: restartedRepository);
    final restartedSync = PatrolSyncService(
      patrolService: restartedService,
      syncRepository: remote,
      networkStatus: network..online = true,
    );
    final result = await restartedSync.synchronizePending('ranger-1');

    expect(result.synchronizedCount, 1);
    expect(
      (await restartedRepository.listForRanger('ranger-1')).single.status,
      PatrolStatus.completedSynced,
    );
  });
}

Future<Patrol> _saveCompletedPatrol(PatrolService service) async {
  final start = DateTime.utc(2026, 10, 8, 8);
  final location = _location(start);
  final assigned = Patrol(
    patrolId: 'assigned-patrol-1',
    localId: 'local-patrol-1',
    rangerId: 'ranger-1',
    rangerName: 'Ranger One',
    area: const PatrolArea(
      parkName: 'North Park',
      zoneName: 'North Zone',
      routeName: 'River Route',
    ),
  );
  await service.saveAssignedPatrol(assigned);
  await service.start(
    rangerId: assigned.rangerId,
    localId: assigned.localId,
    location: location,
    at: start,
  );
  await service.recordRoutePoint(
    rangerId: assigned.rangerId,
    localId: assigned.localId,
    point: PatrolRoutePoint(
      id: 'route-point-local-1',
      location: _location(start.add(const Duration(minutes: 1))),
    ),
  );
  await service.addManualWaypoint(
    rangerId: assigned.rangerId,
    localId: assigned.localId,
    waypoint: PatrolWaypoint(
      id: 'manual-waypoint-local-1',
      description: 'Tree marker',
      location: PatrolLocation(
        latitude: 6.2,
        longitude: 81.3,
        recordedAt: start.add(const Duration(minutes: 2)),
        source: PatrolLocationSource.manual,
      ),
    ),
  );
  await service.addObservation(
    rangerId: assigned.rangerId,
    localId: assigned.localId,
    observation: PatrolObservation(
      id: 'observation-local-1',
      description: 'Animal tracks',
      location: location,
    ),
  );
  await service.addPhotograph(
    rangerId: assigned.rangerId,
    localId: assigned.localId,
    photograph: PatrolPhoto(
      id: 'photo-local-1',
      fileName: 'tracks.jpg',
      contentType: 'image/jpeg',
      base64Data: 'cGhvdG8=',
      capturedAt: start.add(const Duration(minutes: 3)),
    ),
  );
  await service.pause(
    rangerId: assigned.rangerId,
    localId: assigned.localId,
    at: start.add(const Duration(minutes: 4)),
  );
  await service.resume(
    rangerId: assigned.rangerId,
    localId: assigned.localId,
    at: start.add(const Duration(minutes: 5)),
  );
  return service.complete(
    rangerId: assigned.rangerId,
    localId: assigned.localId,
    endLocation: _location(start.add(const Duration(minutes: 6))),
    at: start.add(const Duration(minutes: 6)),
  );
}

PatrolLocation _location(DateTime at) => PatrolLocation(
  latitude: 6.1,
  longitude: 81.2,
  recordedAt: at,
  source: PatrolLocationSource.gps,
  accuracyMeters: 4,
);

class _FakeNetworkStatus implements PatrolNetworkStatusProvider {
  final _changes = StreamController<bool>.broadcast(sync: true);

  set online(bool value) {
    _online = value;
    _changes.add(value);
  }

  bool get online => _online;
  bool _online = false;

  @override
  Future<bool> get isOnline async => _online;

  @override
  Stream<bool> get onlineChanges => _changes.stream;

  Future<void> dispose() => _changes.close();
}

class _FakeSyncRepository implements PatrolSyncRepository {
  int calls = 0;
  Object? failure;
  Future<void> Function()? beforeComplete;

  @override
  Future<void> syncCompletedPatrol(Patrol patrol) async {
    calls++;
    if (beforeComplete != null) await beforeComplete!();
    if (failure != null) throw failure!;
  }
}
