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
import 'package:rangernet/features/patrols/presentation/patrol_session_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts offline, records observation, and pauses/resumes', (
    tester,
  ) async {
    final context = await _createContext();
    final assigned = _assignedPatrol();
    await context.service.saveAssignedPatrol(assigned);
    await _showSession(tester, context, assigned);

    expect(
      find.textContaining('Offline · patrol data stays on this device'),
      findsOneWidget,
    );
    expect(find.text('Assigned'), findsOneWidget);

    await _tapAction(tester, 'Start patrol');
    expect(
      (await context.repository.listForRanger('ranger-1')).single.status,
      PatrolStatus.inProgress,
      reason: 'Start action should persist the in-progress state.',
    );
    await _ensureVisible(tester, 'Pause patrol');
    expect(find.text('Pause patrol'), findsOneWidget);
    expect(
      (await context.repository.listForRanger('ranger-1')).single.status,
      PatrolStatus.inProgress,
    );

    // Required category and description validation should block an empty record.
    await _tapAction(tester, 'Add observation');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Choose an observation category.'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await _pumpFrames(tester);
    await tester.tap(find.text('Wildlife').last);
    await _pumpFrames(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('This field is required.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, 'Elephant herd');
    await tester.tap(find.text('Save'));
    await _pumpFrames(tester);
    expect(
      (await context.repository.listForRanger(
        'ranger-1',
      )).single.observations.single.description,
      'Elephant herd',
    );

    await _tapAction(tester, 'Pause patrol');
    expect(
      (await context.repository.listForRanger('ranger-1')).single.status,
      PatrolStatus.paused,
    );

    await _tapAction(tester, 'Resume patrol');
    expect(
      (await context.repository.listForRanger('ranger-1')).single.status,
      PatrolStatus.inProgress,
    );

    await _disposeContext(tester, context);
  });

  testWidgets('GPS start failure can be cancelled without starting patrol', (
    tester,
  ) async {
    final context = await _createContext(locationFails: true);
    final assigned = _assignedPatrol();
    await context.service.saveAssignedPatrol(assigned);
    await _showSession(tester, context, assigned);

    await _tapAction(tester, 'Start patrol');
    expect(find.text('GPS unavailable'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await _pumpFrames(tester);

    expect(find.text('Start patrol'), findsOneWidget);
    expect(find.text('Assigned'), findsOneWidget);
    expect(
      (await context.repository.listForRanger('ranger-1')).single.status,
      PatrolStatus.assigned,
    );

    await _disposeContext(tester, context);
  });

  testWidgets('active patrol exposes GPS retry after tracking is unavailable', (
    tester,
  ) async {
    final context = await _createContext(gpsUnavailable: true);
    final assigned = _assignedPatrol();
    await context.service.saveAssignedPatrol(assigned);
    await _showSession(tester, context, assigned);
    await _tapAction(tester, 'Start patrol');

    expect(
      find.text('GPS unavailable/inaccurate — mark manual waypoint'),
      findsWidgets,
    );
    expect(find.text('Retry GPS'), findsOneWidget);
    await _tapAction(tester, 'Retry GPS');

    // Retrying location acquisition must not change the locally active patrol.
    expect(
      (await context.repository.listForRanger('ranger-1')).single.status,
      PatrolStatus.inProgress,
    );
    await _ensureVisible(tester, 'Retry GPS');
    expect(find.text('Retry GPS'), findsOneWidget);

    await _disposeContext(tester, context);
  });

  testWidgets('active patrol opens its summary before confirmation', (
    tester,
  ) async {
    final context = await _createContext();
    final assigned = _assignedPatrol();
    await context.service.saveAssignedPatrol(assigned);
    await _showSession(tester, context, assigned);
    await _tapAction(tester, 'Start patrol');
    await _tapAction(tester, 'Review and complete patrol');

    expect(find.text('Review patrol summary'), findsOneWidget);
    expect(find.text('Distance travelled'), findsOneWidget);
    expect(
      (await context.repository.listForRanger('ranger-1')).single.status,
      PatrolStatus.inProgress,
    );

    await tester.pageBack();
    await _pumpFrames(tester);
    expect(find.text('Patrol details'), findsOneWidget);
    expect(
      (await context.repository.listForRanger('ranger-1')).single.status,
      PatrolStatus.inProgress,
    );

    await _disposeContext(tester, context);
  });

  testWidgets('restores an active patrol and tracking after app resume', (
    tester,
  ) async {
    final context = await _createContext();
    final assigned = _assignedPatrol();
    await context.service.saveAssignedPatrol(assigned);
    final active = await context.service.start(
      rangerId: assigned.rangerId,
      localId: assigned.localId,
      location: _gpsLocation(),
      at: DateTime.utc(2026, 10, 9, 8),
    );
    await _showSession(tester, context, active);
    await _ensureVisible(tester, 'Pause patrol');
    expect(context.tracking.startCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester);
    expect(context.tracking.startCalls, 2);
    expect(
      (await context.repository.listForRanger('ranger-1')).single.status,
      PatrolStatus.inProgress,
    );

    await _disposeContext(tester, context);
  });

  testWidgets('failed manual sync retains completed patrol locally', (
    tester,
  ) async {
    final context = await _createContext();
    final pending = _pendingPatrol();
    await context.repository.save(pending);
    await _showSession(tester, context, pending);

    await _tapAction(tester, 'Retry Sync');
    expect(
      find.textContaining('locally saved patrol remains pending'),
      findsOneWidget,
    );
    final saved = (await context.repository.listForRanger('ranger-1')).single;
    expect(saved.status, PatrolStatus.completedPendingSync);
    expect(saved.syncInfo.status, PatrolSyncStatus.failed);
    expect(saved.syncInfo.lastError, contains('No network connection'));

    await _disposeContext(tester, context);
  });

  testWidgets('unsaved observation can be kept or explicitly discarded', (
    tester,
  ) async {
    final context = await _createContext();
    final assigned = _assignedPatrol();
    await context.service.saveAssignedPatrol(assigned);
    await _showSession(tester, context, assigned);
    await _tapAction(tester, 'Start patrol');
    await _tapAction(tester, 'Add observation');
    await tester.enterText(find.byType(TextFormField).last, 'Unsubmitted note');
    await tester.tap(find.text('Cancel').last);
    await _pumpFrames(tester);

    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await _pumpFrames(tester);
    expect(find.text('Unsubmitted note'), findsOneWidget);

    await tester.tap(find.text('Cancel').last);
    await _pumpFrames(tester);
    await tester.tap(find.text('Discard'));
    await _pumpFrames(tester);
    expect(find.text('Add patrol observation'), findsNothing);
    expect(
      (await context.repository.listForRanger('ranger-1')).single.observations,
      isEmpty,
    );

    await _disposeContext(tester, context);
  });

  testWidgets('photo source choices can be dismissed without adding a photo', (
    tester,
  ) async {
    final context = await _createContext();
    final assigned = _assignedPatrol();
    await context.service.saveAssignedPatrol(assigned);
    await _showSession(tester, context, assigned);
    await _tapAction(tester, 'Start patrol');
    await _tapAction(tester, 'Add patrol photograph');

    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    // Selecting a source with the test platform must not fabricate photo data.
    await tester.tap(find.text('Take photo'));
    await _pumpFrames(tester);
    expect(
      (await context.repository.listForRanger('ranger-1')).single.photographs,
      isEmpty,
    );

    await _disposeContext(tester, context);
  });

  testWidgets('cancelling early termination leaves the patrol active', (
    tester,
  ) async {
    final context = await _createContext();
    final assigned = _assignedPatrol();
    await context.service.saveAssignedPatrol(assigned);
    await _showSession(tester, context, assigned);
    await _tapAction(tester, 'Start patrol');
    await _tapAction(tester, 'End patrol early');

    await tester.tap(find.text('Cancel'));
    await _pumpFrames(tester);
    expect(
      (await context.repository.listForRanger('ranger-1')).single.status,
      PatrolStatus.inProgress,
    );
    expect(find.text('End patrol early?'), findsNothing);

    await _disposeContext(tester, context);
  });

  testWidgets('early termination requires confirmation and a reason', (
    tester,
  ) async {
    final context = await _createContext();
    final assigned = _assignedPatrol();
    await context.service.saveAssignedPatrol(assigned);
    await _showSession(tester, context, assigned);
    await _tapAction(tester, 'Start patrol');

    await _tapAction(tester, 'End patrol early');
    expect(find.text('End patrol early?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await _pumpFrames(tester);
    expect(
      find.text('Record why the patrol is ending before completion.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('This field is required.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'Severe weather');
    await tester.tap(find.text('Save'));
    await _pumpFrames(tester);

    final saved = (await context.repository.listForRanger('ranger-1')).single;
    expect(
      saved.status,
      PatrolStatus.aborted,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .join(' | '),
    );
    expect(saved.earlyTerminationReason, 'Severe weather');

    await _disposeContext(tester, context);
  });

  testWidgets('critical interruption requires details and can be resumed', (
    tester,
  ) async {
    final context = await _createContext();
    final assigned = _assignedPatrol();
    await context.service.saveAssignedPatrol(assigned);
    await _showSession(tester, context, assigned);
    await _tapAction(tester, 'Start patrol');

    await _tapAction(tester, 'Interrupt for critical incident');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('This field is required.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, 'Wildlife rescue');
    await tester.tap(find.text('Save'));
    await _pumpFrames(tester);
    expect(
      (await context.repository.listForRanger(
        'ranger-1',
      )).single.interruptionReason,
      'Wildlife rescue',
    );

    await _tapAction(tester, 'Resume patrol');
    expect(
      (await context.repository.listForRanger('ranger-1')).single.status,
      PatrolStatus.inProgress,
    );

    await _disposeContext(tester, context);
  });
}

Future<_TestContext> _createContext({
  bool locationFails = false,
  bool gpsUnavailable = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final repository = LocalPatrolRepository();
  final service = PatrolService(repository: repository);
  final network = _OfflineNetworkStatus();
  final tracking = _FakeTrackingService(
    locationFails: locationFails,
    gpsUnavailable: gpsUnavailable,
  );
  final sync = PatrolSyncService(
    patrolService: service,
    syncRepository: _TestSyncRepository(),
    networkStatus: network,
  );
  return _TestContext(repository, service, network, tracking, sync);
}

Future<void> _showSession(
  WidgetTester tester,
  _TestContext context,
  Patrol patrol,
) async {
  tester.view
    ..physicalSize = const Size(1200, 1800)
    ..devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      home: PatrolSessionPage(
        patrol: patrol,
        service: context.service,
        trackingService: context.tracking,
        syncService: context.sync,
        networkStatus: context.network,
        showTileLayer: false,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _tapAction(WidgetTester tester, String label) async {
  await _ensureVisible(tester, label);
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
  await tester.tap(button);
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  // Active patrols have a one-second clock timer, so settle-based pumping hangs.
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _ensureVisible(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

Future<void> _disposeContext(WidgetTester tester, _TestContext context) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await context.tracking.dispose();
  await context.network.dispose();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
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

PatrolLocation _gpsLocation() => PatrolLocation(
  latitude: 6.1,
  longitude: 81.2,
  recordedAt: DateTime.now().toUtc(),
  source: PatrolLocationSource.gps,
  accuracyMeters: 4,
);

class _TestContext {
  const _TestContext(
    this.repository,
    this.service,
    this.network,
    this.tracking,
    this.sync,
  );

  final LocalPatrolRepository repository;
  final PatrolService service;
  final _OfflineNetworkStatus network;
  final _FakeTrackingService tracking;
  final PatrolSyncService sync;
}

class _OfflineNetworkStatus implements PatrolNetworkStatusProvider {
  final _changes = StreamController<bool>.broadcast(sync: true);

  @override
  Future<bool> get isOnline async => false;

  @override
  Stream<bool> get onlineChanges => _changes.stream;

  Future<void> dispose() => _changes.close();
}

class _FakeTrackingService implements PatrolTrackingService {
  _FakeTrackingService({
    required this.locationFails,
    required this.gpsUnavailable,
  });

  final bool locationFails;
  final bool gpsUnavailable;
  final _states = StreamController<PatrolTrackingState>.broadcast(sync: true);
  PatrolTrackingState _currentState = const PatrolTrackingState(
    gpsStatus: PatrolGpsStatus(state: PatrolGpsState.acquiring),
  );
  int startCalls = 0;

  @override
  double get maximumAccuracyMeters => 50;

  @override
  double get minimumPointDistanceMeters => 8;

  @override
  Duration get minimumPointInterval => const Duration(seconds: 5);

  @override
  Stream<PatrolTrackingState> get states => _states.stream;

  @override
  PatrolTrackingState get currentState => _currentState;

  @override
  Future<PatrolLocation> currentLocation() async {
    if (locationFails) {
      throw StateError('Test GPS unavailable.');
    }
    return _gpsLocation();
  }

  @override
  Future<void> start(Patrol patrol) async {
    startCalls++;
    _currentState = PatrolTrackingState(
      gpsStatus: PatrolGpsStatus(
        state: locationFails || gpsUnavailable
            ? PatrolGpsState.unavailable
            : PatrolGpsState.available,
        accuracyMeters: locationFails || gpsUnavailable ? null : 4,
      ),
      patrol: patrol,
      latestFix: locationFails || gpsUnavailable ? null : _gpsLocation(),
    );
    _states.add(_currentState);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> refreshPatrol(Patrol patrol) async {
    _currentState = PatrolTrackingState(
      gpsStatus: _currentState.gpsStatus,
      patrol: patrol,
      latestFix: _currentState.latestFix,
      recordedPointCount: patrol.routePoints.length,
    );
    _states.add(_currentState);
  }

  @override
  Future<void> dispose() => _states.close();
}

class _TestSyncRepository implements PatrolSyncRepository {
  @override
  Future<void> syncCompletedPatrol(Patrol patrol) async {}
}

Patrol _pendingPatrol() {
  final startedAt = DateTime.utc(2026, 10, 9, 8);
  return _assignedPatrol().copyWith(
    status: PatrolStatus.completedPendingSync,
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(minutes: 15)),
    startLocation: PatrolLocation(
      latitude: 6.1,
      longitude: 81.2,
      recordedAt: startedAt,
      source: PatrolLocationSource.gps,
      accuracyMeters: 4,
    ),
    endLocation: PatrolLocation(
      latitude: 6.11,
      longitude: 81.21,
      recordedAt: startedAt.add(const Duration(minutes: 15)),
      source: PatrolLocationSource.gps,
      accuracyMeters: 4,
    ),
    syncInfo: const PatrolSyncInfo(status: PatrolSyncStatus.pendingSync),
  );
}
