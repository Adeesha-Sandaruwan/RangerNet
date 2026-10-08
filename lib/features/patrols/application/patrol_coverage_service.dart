import '../domain/patrol.dart';
import '../domain/patrol_records.dart';
import 'patrol_metrics_service.dart';

class PatrolCoverageService {
  const PatrolCoverageService({
    this.coverageRadiusMeters = 100,
    this.maximumGpsAccuracyMeters = 50,
    this.metrics = const PatrolMetricsService(),
  });

  final double coverageRadiusMeters;
  final double maximumGpsAccuracyMeters;
  final PatrolMetricsService metrics;

  PatrolCoverage? calculate(
    Patrol patrol, {
    DateTime? calculatedAt,
    PatrolLocation? additionalLocation,
  }) {
    final sections = patrol.plannedCoverageSections;
    if (sections.isEmpty) return null;

    final recordedLocations = <PatrolLocation>[
      ?patrol.startLocation,
      ?patrol.endLocation,
      ?additionalLocation,
      ...patrol.routePoints.map((point) => point.location),
      ...patrol.manualWaypoints.map((waypoint) => waypoint.location),
    ].where(_isReliable);
    final recordedAt = (calculatedAt ?? DateTime.now()).toUtc();

    final coveredIds = <String>{};
    final uncoveredIds = <String>[];
    for (final section in sections) {
      final checkpoint = PatrolLocation(
        latitude: section.latitude,
        longitude: section.longitude,
        recordedAt: recordedAt,
        source: PatrolLocationSource.manual,
      );
      final covered = recordedLocations.any(
        (location) =>
            metrics.distanceBetween(location, checkpoint) <=
            coverageRadiusMeters,
      );
      if (covered) {
        coveredIds.add(section.id);
      } else {
        uncoveredIds.add(section.id);
      }
    }

    return PatrolCoverage(
      totalSections: sections.length,
      coveredSections: coveredIds.length,
      coveredSectionIds: coveredIds,
      uncoveredSectionIds: uncoveredIds,
      calculatedAt: recordedAt,
    );
  }

  bool _isReliable(PatrolLocation location) =>
      location.source == PatrolLocationSource.manual ||
      location.accuracyMeters == null ||
      location.accuracyMeters! <= maximumGpsAccuracyMeters;
}
