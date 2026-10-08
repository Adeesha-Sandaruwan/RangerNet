import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/patrols/application/patrol_coverage_service.dart';
import 'package:rangernet/features/patrols/domain/patrol.dart';
import 'package:rangernet/features/patrols/domain/patrol_records.dart';

void main() {
  const service = PatrolCoverageService(coverageRadiusMeters: 100);

  test(
    'counts nearby recorded GPS and manual locations per planned section',
    () {
      final start = DateTime.utc(2026, 10, 8, 8);
      final patrol = _patrol(
        startLocation: _location(6.1, 81.2, start),
        routePoints: [
          PatrolRoutePoint(
            id: 'gps-near',
            location: _location(
              6.1002,
              81.2,
              start.add(const Duration(minutes: 1)),
            ),
          ),
          PatrolRoutePoint(
            id: 'gps-inaccurate',
            location: _location(
              6.2,
              81.2,
              start.add(const Duration(minutes: 2)),
              accuracy: 120,
            ),
          ),
        ],
        manualWaypoints: [
          PatrolWaypoint(
            id: 'manual-near',
            description: 'Field checkpoint',
            location: PatrolLocation(
              latitude: 6.3,
              longitude: 81.2,
              recordedAt: start.add(const Duration(minutes: 3)),
              source: PatrolLocationSource.manual,
            ),
          ),
        ],
        plannedCoverageSections: [
          _section('start', 'Start section', 6.1, 81.2),
          _section('gps', 'GPS section', 6.1003, 81.2),
          _section('manual', 'Manual section', 6.3, 81.2),
          _section('uncovered', 'Uncovered section', 6.4, 81.2),
        ],
      );

      final coverage = service.calculate(patrol, calculatedAt: start);

      expect(coverage?.totalSections, 4);
      expect(coverage?.coveredSections, 3);
      expect(coverage?.coveredSectionIds, ['start', 'gps', 'manual']);
      expect(coverage?.uncoveredSectionIds, ['uncovered']);
      expect(coverage?.coveragePercent, 75);
    },
  );

  test(
    'returns no coverage when the manager did not define route sections',
    () {
      expect(service.calculate(_patrol()), isNull);
    },
  );
}

Patrol _patrol({
  PatrolLocation? startLocation,
  List<PatrolRoutePoint> routePoints = const [],
  List<PatrolWaypoint> manualWaypoints = const [],
  List<PatrolCoverageCheckpoint> plannedCoverageSections = const [],
}) => Patrol(
  patrolId: 'patrol-1',
  localId: 'local-1',
  rangerId: 'ranger-1',
  rangerName: 'Ranger One',
  area: const PatrolArea(
    parkName: 'North Park',
    zoneName: 'North Zone',
    routeName: 'River Route',
  ),
  status: PatrolStatus.inProgress,
  startedAt: DateTime.utc(2026, 10, 8, 8),
  startLocation: startLocation,
  routePoints: routePoints,
  manualWaypoints: manualWaypoints,
  plannedCoverageSections: plannedCoverageSections,
);

PatrolCoverageCheckpoint _section(
  String id,
  String name,
  double latitude,
  double longitude,
) => PatrolCoverageCheckpoint(
  id: id,
  name: name,
  latitude: latitude,
  longitude: longitude,
);

PatrolLocation _location(
  double latitude,
  double longitude,
  DateTime recordedAt, {
  double accuracy = 5,
}) => PatrolLocation(
  latitude: latitude,
  longitude: longitude,
  recordedAt: recordedAt,
  source: PatrolLocationSource.gps,
  accuracyMeters: accuracy,
);
