// Coverage: GPS patrol tracking; checks accuracy filtering, duplicate and
// near-duplicate fixes, GPS loss/recovery, and preservation of saved route data.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/patrols/application/patrol_service.dart';
import 'package:rangernet/features/patrols/application/patrol_tracking_service.dart';
import 'package:rangernet/features/patrols/data/local_patrol_repository.dart';
import 'package:rangernet/features/patrols/domain/patrol.dart';
import 'package:rangernet/features/patrols/domain/patrol_location_provider.dart';
import 'package:rangernet/features/patrols/domain/patrol_records.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'filters duplicate fixes and preserves route through GPS loss',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = LocalPatrolRepository();
      final service = PatrolService(repository: repository);
      final provider = _FakeLocationProvider();
      final tracker = PatrolTrackingService(
        patrolService: service,
        locationProvider: provider,
        minimumPointDistanceMeters: 8,
        minimumPointInterval: const Duration(seconds: 5),
      );
      final start = DateTime.utc(2026, 5, 1, 8);
      final assigned = _assignedPatrol();
      await service.saveAssignedPatrol(assigned);
      final inProgress = await service.start(
        rangerId: assigned.rangerId,
        localId: assigned.localId,
        location: _location(6, 81, start),
        at: start,
      );
      final states = <PatrolTrackingState>[];
      final subscription = tracker.states.listen(states.add);
      await tracker.start(inProgress);

      provider.add(
        _location(
          6.0001,
          81,
          start.add(const Duration(seconds: 6)),
          accuracy: 90,
        ),
      );
      await _flush();
      expect(tracker.currentState.gpsStatus.state, PatrolGpsState.inaccurate);
      expect(
        (await service.listForRanger('ranger-1')).single.routePoints,
        isEmpty,
      );

      provider.add(
        _location(6.0001, 81, start.add(const Duration(seconds: 6))),
      );
      await _flush();
      expect(tracker.currentState.recordedPointCount, 1);

      provider.add(
        _location(6.00011, 81, start.add(const Duration(seconds: 12))),
      );
      await _flush();
      expect(tracker.currentState.recordedPointCount, 1);

      provider.addError(StateError('GPS signal lost'));
      await _flush();
      expect(tracker.currentState.gpsStatus.state, PatrolGpsState.unavailable);
      expect(tracker.currentState.recordedPointCount, 1);

      provider.add(
        _location(6.0002, 81, start.add(const Duration(seconds: 20))),
      );
      await _flush();
      await tracker.stop();
      final saved = (await service.listForRanger('ranger-1')).single;
      expect(saved.routePoints, hasLength(2));
      expect(tracker.currentState.gpsStatus.state, PatrolGpsState.available);
      expect(
        states.any(
          (state) => state.gpsStatus.state == PatrolGpsState.inaccurate,
        ),
        isTrue,
      );
      expect(
        states.any(
          (state) => state.gpsStatus.state == PatrolGpsState.unavailable,
        ),
        isTrue,
      );
      await subscription.cancel();
      await tracker.dispose();
      await provider.dispose();
    },
  );
}

class _FakeLocationProvider implements PatrolLocationProvider {
  final _positions = StreamController<PatrolLocation>.broadcast(sync: true);

  void add(PatrolLocation location) => _positions.add(location);

  void addError(Object error) => _positions.addError(error);

  @override
  Future<PatrolLocation> currentLocation() async =>
      _location(6, 81, DateTime.utc(2026));

  @override
  Future<PatrolGpsStatus> checkStatus() async =>
      const PatrolGpsStatus(state: PatrolGpsState.acquiring);

  @override
  Future<Stream<PatrolLocation>> watchLocations() async => _positions.stream;

  Future<void> dispose() => _positions.close();
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

PatrolLocation _location(
  double latitude,
  double longitude,
  DateTime recordedAt, {
  double accuracy = 4,
}) => PatrolLocation(
  latitude: latitude,
  longitude: longitude,
  recordedAt: recordedAt,
  source: PatrolLocationSource.gps,
  accuracyMeters: accuracy,
);

Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 5));
