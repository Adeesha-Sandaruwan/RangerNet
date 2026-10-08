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
  PatrolLocation? startLocation,
  List<PatrolRoutePoint> routePoints = const [],
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
  startLocation: startLocation,
  routePoints: routePoints,
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
