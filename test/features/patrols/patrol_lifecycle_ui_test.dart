import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/patrols/application/patrol_service.dart';
import 'package:rangernet/features/patrols/application/patrol_sync_service.dart';
import 'package:rangernet/features/patrols/data/local_patrol_repository.dart';
import 'package:rangernet/features/patrols/domain/patrol.dart';
import 'package:rangernet/features/patrols/domain/patrol_location_provider.dart';
import 'package:rangernet/features/patrols/domain/patrol_network_status.dart';
import 'package:rangernet/features/patrols/domain/patrol_records.dart';
import 'package:rangernet/features/patrols/domain/patrol_repository.dart';
import 'package:rangernet/features/patrols/presentation/patrol_completion_review_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'completion requires confirmation and remains pending when offline',
    (tester) async {
      final context = await _createTestContext();
      final start = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final patrol = _assignedPatrol();
      await context.service.saveAssignedPatrol(patrol);
      final active = await context.service.start(
        rangerId: patrol.rangerId,
        localId: patrol.localId,
        location: _location(start),
        at: start,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PatrolCompletionReviewPage(
            patrol: active,
            suggestedEndLocation: _location(
              start.add(const Duration(hours: 1)),
            ),
            gpsStatus: const PatrolGpsStatus(state: PatrolGpsState.available),
            service: context.service,
            syncService: context.syncService,
            networkStatus: context.network,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline'), findsOneWidget);
      expect(find.text('GPS status: Available'), findsOneWidget);
      await _tapAction(tester, 'Confirm completion');
      expect(find.text('Complete this patrol?'), findsOneWidget);

      // Canceling the confirmation must leave the active local patrol untouched.
      await tester.tap(find.text('Return to summary'));
      await tester.pumpAndSettle();
      expect(
        (await context.repository.listForRanger('ranger-1')).single.status,
        PatrolStatus.inProgress,
      );

      await _tapAction(tester, 'Confirm completion');
      await tester.tap(find.text('Complete patrol'));
      await tester.pumpAndSettle();

      final completed = (await context.repository.listForRanger(
        'ranger-1',
      )).single;
      expect(completed.status, PatrolStatus.completedPendingSync);
      expect(completed.syncInfo.status, PatrolSyncStatus.failed);
      expect(find.textContaining('Pending Sync'), findsWidgets);
      await _ensureVisible(tester, 'Retry synchronization');
      expect(find.text('Retry synchronization'), findsOneWidget);

      await _disposeTestContext(tester, context);
    },
  );

  testWidgets('online completion synchronizes and shows completed status', (
    tester,
  ) async {
    final context = await _createTestContext(online: true);
    final start = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    final patrol = _assignedPatrol();
    await context.service.saveAssignedPatrol(patrol);
    final active = await context.service.start(
      rangerId: patrol.rangerId,
      localId: patrol.localId,
      location: _location(start),
      at: start,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PatrolCompletionReviewPage(
          patrol: active,
          suggestedEndLocation: _location(start.add(const Duration(hours: 1))),
          gpsStatus: const PatrolGpsStatus(state: PatrolGpsState.available),
          service: context.service,
          syncService: context.syncService,
          networkStatus: context.network,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapAction(tester, 'Confirm completion');
    await tester.tap(find.text('Complete patrol'));
    await tester.pumpAndSettle();

    final completed = (await context.repository.listForRanger(
      'ranger-1',
    )).single;
    expect(completed.status, PatrolStatus.completedSynced);
    expect(find.text('Patrol completion synchronized.'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);

    await _disposeTestContext(tester, context);
  });
}

Future<_TestContext> _createTestContext({bool online = false}) async {
  SharedPreferences.setMockInitialValues({});
  final repository = LocalPatrolRepository();
  final service = PatrolService(repository: repository);
  final network = _FakeNetworkStatus(online: online);
  final syncService = PatrolSyncService(
    patrolService: service,
    syncRepository: _FakeSyncRepository(),
    networkStatus: network,
  );
  return _TestContext(repository, service, network, syncService);
}

Future<void> _tapAction(WidgetTester tester, String label) async {
  await _ensureVisible(tester, label);
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _ensureVisible(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    400,
    scrollable: find.byType(Scrollable).first,
  );
}

Future<void> _disposeTestContext(
  WidgetTester tester,
  _TestContext context,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await context.network.dispose();
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

PatrolLocation _location(DateTime at) => PatrolLocation(
  latitude: 6.1,
  longitude: 81.2,
  recordedAt: at,
  source: PatrolLocationSource.gps,
  accuracyMeters: 5,
);

class _TestContext {
  const _TestContext(
    this.repository,
    this.service,
    this.network,
    this.syncService,
  );

  final LocalPatrolRepository repository;
  final PatrolService service;
  final _FakeNetworkStatus network;
  final PatrolSyncService syncService;
}

class _FakeNetworkStatus implements PatrolNetworkStatusProvider {
  _FakeNetworkStatus({required this.online});

  final _changes = StreamController<bool>.broadcast(sync: true);
  final bool online;

  @override
  Future<bool> get isOnline async => online;

  @override
  Stream<bool> get onlineChanges => _changes.stream;

  Future<void> dispose() => _changes.close();
}

class _FakeSyncRepository implements PatrolSyncRepository {
  @override
  Future<void> syncCompletedPatrol(Patrol patrol) async {}
}
