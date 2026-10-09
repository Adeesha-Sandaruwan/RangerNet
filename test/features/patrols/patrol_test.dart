// Coverage: Patrol model-derived values and route metrics; checks completion,
// distance, duration, pauses, and manual/GPS route endpoints.
import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/patrols/domain/patrol.dart';
import 'package:rangernet/features/patrols/domain/patrol_records.dart';
import 'package:rangernet/features/patrols/domain/patrol_workflow_policy.dart';
import 'package:rangernet/features/patrols/application/patrol_metrics_service.dart';

void main() {
  group('Patrol', () {
    const metrics = PatrolMetricsService();

    test('derives completion state, route distance, and active duration', () {
      final start = DateTime.utc(2026, 1, 1, 8);
      final patrol = _patrol(
        status: PatrolStatus.paused,
        startedAt: start,
        startLocation: _location(6.0, 81.0, start),
        routePoints: [
          PatrolRoutePoint(
            id: 'point-1',
            location: _location(6.0, 81.0, start),
          ),
          PatrolRoutePoint(
            id: 'point-2',
            location: _location(
              6.0,
              81.01,
              start.add(const Duration(hours: 1)),
            ),
          ),
        ],
        pauseResumeEvents: [
          PatrolPauseResumeEvent(
            id: 'pause-1',
            action: PatrolPauseResumeAction.pause,
            occurredAt: start.add(const Duration(minutes: 20)),
          ),
        ],
      );

      expect(patrol.completionState, PatrolCompletionState.active);
      expect(metrics.distanceTravelledMeters(patrol), greaterThan(1000));
      expect(
        metrics.durationAt(patrol, start.add(const Duration(hours: 1))),
        const Duration(minutes: 20),
      );
    });

    test('includes the start and recorded GPS end in route distance', () {
      final startedAt = DateTime.utc(2026, 1, 1, 8);
      final start = _location(6.0, 81.0, startedAt);
      final firstFix = _location(
        6.001,
        81.0,
        startedAt.add(const Duration(minutes: 2)),
      );
      final lastFix = _location(
        6.002,
        81.0,
        startedAt.add(const Duration(minutes: 4)),
      );
      final gpsEnd = _location(
        6.003,
        81.0,
        startedAt.add(const Duration(minutes: 5)),
      );
      final patrol = _patrol(
        status: PatrolStatus.completedPendingSync,
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 5)),
        startLocation: start,
        endLocation: gpsEnd,
        routePoints: [
          PatrolRoutePoint(id: 'point-1', location: firstFix),
          PatrolRoutePoint(id: 'point-2', location: lastFix),
        ],
      );
      final expectedDistance =
          metrics.distanceBetween(start, firstFix) +
          metrics.distanceBetween(firstFix, lastFix) +
          metrics.distanceBetween(lastFix, gpsEnd);

      expect(
        metrics.distanceTravelledMeters(patrol),
        closeTo(expectedDistance, 0.01),
      );

      final manualEndPatrol = _patrol(
        status: PatrolStatus.completedPendingSync,
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 5)),
        startLocation: start,
        endLocation: PatrolLocation(
          latitude: 6.01,
          longitude: 81.0,
          recordedAt: startedAt.add(const Duration(minutes: 5)),
          source: PatrolLocationSource.manual,
        ),
        routePoints: [
          PatrolRoutePoint(id: 'point-1', location: firstFix),
          PatrolRoutePoint(id: 'point-2', location: lastFix),
        ],
      );
      expect(
        metrics.distanceTravelledMeters(manualEndPatrol),
        closeTo(
          metrics.distanceBetween(start, firstFix) +
              metrics.distanceBetween(firstFix, lastFix) +
              metrics.distanceBetween(
                lastFix,
                manualEndPatrol.endLocation!,
              ),
          0.01,
        ),
      );
    });

    test('calculates assigned distance through optional planned stops', () {
      final first = PatrolCoverageCheckpoint(
        id: 'start',
        name: 'Start',
        latitude: 6.0,
        longitude: 81.0,
      );
      final stop = PatrolCoverageCheckpoint(
        id: 'stop',
        name: 'Stop',
        latitude: 6.005,
        longitude: 81.004,
      );
      final end = PatrolCoverageCheckpoint(
        id: 'end',
        name: 'End',
        latitude: 6.01,
        longitude: 81.0,
      );
      final route = PatrolRoutePlan(
        start: first,
        stops: [stop],
        end: end,
      );
      final timestamp = DateTime.utc(2026, 1, 1);
      final expected =
          metrics.distanceBetween(
            _location(first.latitude, first.longitude, timestamp),
            _location(stop.latitude, stop.longitude, timestamp),
          ) +
          metrics.distanceBetween(
            _location(stop.latitude, stop.longitude, timestamp),
            _location(end.latitude, end.longitude, timestamp),
          );

      expect(metrics.plannedRouteDistanceMeters(route), closeTo(expected, 0.01));
    });

    test(
      'counts map-marked waypoints in timestamp order in actual route distance',
      () {
        final startedAt = DateTime.utc(2026, 1, 1, 8);
      final start = _location(6.0, 81.0, startedAt);
      final gps = _location(
        6.001,
        81.0,
        startedAt.add(const Duration(minutes: 2)),
      );
      final manual = PatrolLocation(
        latitude: 6.002,
        longitude: 81.0,
        recordedAt: startedAt.add(const Duration(minutes: 3)),
        source: PatrolLocationSource.manual,
      );
      final end = PatrolLocation(
        latitude: 6.003,
        longitude: 81.0,
        recordedAt: startedAt.add(const Duration(minutes: 4)),
        source: PatrolLocationSource.manual,
      );
      final patrol = _patrol(
        status: PatrolStatus.completedPendingSync,
        startedAt: startedAt,
        endedAt: end.recordedAt,
        startLocation: start,
        endLocation: end,
        routePoints: [PatrolRoutePoint(id: 'gps-1', location: gps)],
        manualWaypoints: [
          PatrolWaypoint(
            id: 'manual-1',
            description: 'Manual point',
            location: manual,
          ),
        ],
      );
      final actualRoute = metrics.actualRouteLocations(patrol);

      expect(actualRoute, [start, gps, manual, end]);
      expect(
        metrics.distanceTravelledMeters(patrol),
        closeTo(
          metrics.distanceBetween(start, gps) +
              metrics.distanceBetween(gps, manual) +
              metrics.distanceBetween(manual, end),
          0.01,
        ),
      );
      },
    );

    test('calculates manual-only route distance when GPS is unavailable', () {
      final startedAt = DateTime.utc(2026, 1, 1, 8);
      final start = PatrolLocation(
        latitude: 6.0,
        longitude: 81.0,
        recordedAt: startedAt,
        source: PatrolLocationSource.manual,
      );
      final waypointLocation = PatrolLocation(
        latitude: 6.001,
        longitude: 81.0,
        recordedAt: startedAt.add(const Duration(minutes: 3)),
        source: PatrolLocationSource.manual,
      );
      final patrol = _patrol(
        status: PatrolStatus.inProgress,
        startedAt: startedAt,
        startLocation: start,
        manualWaypoints: [
          PatrolWaypoint(
            id: 'manual-1',
            description: 'GPS unavailable location',
            location: waypointLocation,
          ),
        ],
      );

      expect(
        metrics.distanceTravelledMeters(patrol),
        closeTo(metrics.distanceBetween(start, waypointLocation), 0.01),
      );
    });

    test('validates coordinates and coverage counts', () {
      expect(() => _location(91, 0, DateTime.utc(2026)), throwsArgumentError);
      expect(
        () => PatrolCoverage(
          totalSections: 3,
          coveredSections: 2,
          uncoveredSectionIds: const [],
          calculatedAt: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
      final coverage = PatrolCoverage(
        totalSections: 4,
        coveredSections: 3,
        uncoveredSectionIds: const ['zone-4'],
        calculatedAt: DateTime.utc(2026),
      );
      expect(coverage.coveragePercent, 75);
    });
  });

  group('PatrolWorkflowPolicy', () {
    test('allows normal lifecycle changes and completion sync', () {
      expect(
        () => PatrolWorkflowPolicy.validateTransition(
          current: PatrolStatus.assigned,
          next: PatrolStatus.inProgress,
        ),
        returnsNormally,
      );
      expect(
        () => PatrolWorkflowPolicy.validateTransition(
          current: PatrolStatus.completedPendingSync,
          next: PatrolStatus.completedSynced,
        ),
        returnsNormally,
      );
    });

    test('rejects invalid transitions and requires interruption reasons', () {
      expect(
        () => PatrolWorkflowPolicy.validateTransition(
          current: PatrolStatus.completedSynced,
          next: PatrolStatus.inProgress,
        ),
        throwsStateError,
      );
      expect(
        () => PatrolWorkflowPolicy.validateTransition(
          current: PatrolStatus.inProgress,
          next: PatrolStatus.interrupted,
        ),
        throwsArgumentError,
      );
      expect(
        () => PatrolWorkflowPolicy.validateTransition(
          current: PatrolStatus.inProgress,
          next: PatrolStatus.interrupted,
          reason: 'Critical wildlife incident',
        ),
        returnsNormally,
      );
    });
  });
}

Patrol _patrol({
  PatrolStatus status = PatrolStatus.assigned,
  DateTime? startedAt,
  DateTime? endedAt,
  PatrolLocation? startLocation,
  PatrolLocation? endLocation,
  List<PatrolRoutePoint> routePoints = const [],
  List<PatrolWaypoint> manualWaypoints = const [],
  List<PatrolPauseResumeEvent> pauseResumeEvents = const [],
}) => Patrol(
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
  status: status,
  startedAt: startedAt,
  endedAt: endedAt,
  startLocation: startLocation,
  endLocation: endLocation,
  routePoints: routePoints,
  manualWaypoints: manualWaypoints,
  pauseResumeEvents: pauseResumeEvents,
);

PatrolLocation _location(double latitude, double longitude, DateTime time) =>
    PatrolLocation(
      latitude: latitude,
      longitude: longitude,
      recordedAt: time,
      source: PatrolLocationSource.gps,
      accuracyMeters: 4,
    );
