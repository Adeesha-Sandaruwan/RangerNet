import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/patrols/application/patrol_service.dart';
import 'package:rangernet/features/patrols/application/patrol_sync_service.dart';
import 'package:rangernet/features/patrols/application/patrol_tracking_service.dart';
import 'package:rangernet/features/patrols/data/local_patrol_repository.dart';
import 'package:rangernet/features/patrols/domain/patrol.dart';
import 'package:rangernet/features/patrols/domain/patrol_location_provider.dart';
import 'package:rangernet/features/patrols/domain/patrol_network_status.dart';
import 'package:rangernet/features/patrols/domain/patrol_records.dart';
import 'package:rangernet/features/patrols/domain/patrol_repository.dart';
import 'package:rangernet/features/patrols/presentation/patrol_home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'ranger can manually sync and pending patrol syncs on network restoration',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = LocalPatrolRepository();
      final service = PatrolService(
        repository: repository,
        assignmentSource: _FakeAssignmentSource(),
      );
      final network = _FakeNetworkStatus();
      final remote = _FakeSyncRepository();
      final syncService = PatrolSyncService(
        patrolService: service,
        syncRepository: remote,
        networkStatus: network,
      );
      final trackingService = PatrolTrackingService(
        patrolService: service,
        locationProvider: _FakeLocationProvider(),
      );
      final pendingPatrol = _pendingPatrol();
      await repository.save(pendingPatrol);

      await tester.pumpWidget(
        MaterialApp(
          home: PatrolHomePage(
            rangerId: pendingPatrol.rangerId,
            rangerName: pendingPatrol.rangerName,
            service: service,
            trackingService: trackingService,
            syncService: syncService,
            networkStatus: network,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not sync 1 patrol(s)'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
      await tester.tap(find.text('Sync now'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No network connection is available'),
        findsWidgets,
      );
      expect(
        (await repository.listForRanger(pendingPatrol.rangerId)).single.status,
        PatrolStatus.completedPendingSync,
      );

      network.setOnline(true);
      await tester.pumpAndSettle();

      expect(remote.calls, 1);
      expect(
        (await repository.listForRanger(pendingPatrol.rangerId)).single.status,
        PatrolStatus.completedSynced,
      );
      expect(find.text('Synced 1 patrol(s) successfully.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await trackingService.dispose();
      await network.dispose();
    },
  );
}

Patrol _pendingPatrol() {
  final startedAt = DateTime.utc(2026, 10, 9, 8);
  final location = PatrolLocation(
    latitude: 6.1,
    longitude: 81.2,
    recordedAt: startedAt,
    source: PatrolLocationSource.manual,
  );
  return Patrol(
    patrolId: 'patrol-1',
    localId: 'local-1',
    rangerId: 'ranger-1',
    rangerName: 'Ranger One',
    area: const PatrolArea(
      parkName: 'Park',
      zoneName: 'Zone',
      routeName: 'Route',
    ),
    status: PatrolStatus.completedPendingSync,
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(minutes: 10)),
    startLocation: location,
    endLocation: PatrolLocation(
      latitude: 6.101,
      longitude: 81.2,
      recordedAt: startedAt.add(const Duration(minutes: 10)),
      source: PatrolLocationSource.manual,
    ),
    syncInfo: const PatrolSyncInfo(status: PatrolSyncStatus.pendingSync),
  );
}

class _FakeAssignmentSource implements PatrolAssignmentSource {
  @override
  Future<List<Patrol>> loadAssignedTo(String rangerId) async => const [];

  @override
  Stream<List<Patrol>> watchAssignedTo(String rangerId) =>
      Stream.value(const []);
}

class _FakeNetworkStatus implements PatrolNetworkStatusProvider {
  final _onlineChanges = StreamController<bool>.broadcast(sync: true);
  bool _online = false;

  void setOnline(bool online) {
    _online = online;
    _onlineChanges.add(online);
  }

  @override
  Future<bool> get isOnline async => _online;

  @override
  Stream<bool> get onlineChanges => _onlineChanges.stream;

  Future<void> dispose() => _onlineChanges.close();
}

class _FakeSyncRepository implements PatrolSyncRepository {
  int calls = 0;

  @override
  Future<void> syncCompletedPatrol(Patrol patrol) async {
    calls++;
  }
}

class _FakeLocationProvider implements PatrolLocationProvider {
  @override
  Future<PatrolLocation> currentLocation() async =>
      _pendingPatrol().startLocation!;

  @override
  Future<PatrolGpsStatus> checkStatus() async =>
      const PatrolGpsStatus(state: PatrolGpsState.unavailable);

  @override
  Future<Stream<PatrolLocation>> watchLocations() async =>
      const Stream<PatrolLocation>.empty();
}
