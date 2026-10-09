import '../domain/patrol.dart';
import '../domain/patrol_records.dart';
import 'patrol_metrics_service.dart';

/// Calculates planned-section coverage from reliable recorded locations and route segments.
class PatrolCoverageService {
  const PatrolCoverageService({
    this.coverageRadiusMeters = 100,
    this.maximumGpsAccuracyMeters = 50,
    this.metrics = const PatrolMetricsService(),
  });

  /// Maximum distance from a planned section for a recorded route to count as coverage.
  final double coverageRadiusMeters;
  /// Maximum GPS accuracy error accepted as reliable coverage evidence.
  final double maximumGpsAccuracyMeters;
  /// Distance calculations used to evaluate fixes and route segments.
  final PatrolMetricsService metrics;

  /// Marks sections covered by reliable fixes or connecting route segments; returns null without planned sections.
  PatrolCoverage? calculate(
    Patrol patrol, {
    DateTime? calculatedAt,
    PatrolLocation? additionalLocation,
  }) {
    final sections = patrol.plannedRoute?.coverageSections ?? const [];
    if (sections.isEmpty) return null;

    final recordedLocations = <PatrolLocation>[
      ...metrics.actualRouteLocations(patrol),
      ?additionalLocation,
    ]..sort((first, second) => first.recordedAt.compareTo(second.recordedAt));
    final reliableLocations = recordedLocations.where(_isReliable).toList();
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
      final covered =
          reliableLocations.any(
            (location) =>
                metrics.distanceBetween(location, checkpoint) <=
                coverageRadiusMeters,
          ) ||
          _trackPassesWithinRadius(checkpoint, reliableLocations);
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

  /// Accepts manual points and GPS points within the configured accuracy limit.
  bool _isReliable(PatrolLocation location) =>
      location.source == PatrolLocationSource.manual ||
      location.accuracyMeters == null ||
      location.accuracyMeters! <= maximumGpsAccuracyMeters;

  /// Tests whether any segment between reliable fixes passes within the coverage radius.
  bool _trackPassesWithinRadius(
    PatrolLocation checkpoint,
    List<PatrolLocation> locations,
  ) {
    // Sparse GPS samples still cover the straight-line segment between reliable fixes.
    for (var index = 1; index < locations.length; index++) {
      if (metrics.distanceToSegmentMeters(
            checkpoint,
            locations[index - 1],
            locations[index],
          ) <=
          coverageRadiusMeters) {
        return true;
      }
    }
    return false;
  }
}
