import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../domain/patrol_records.dart';
import 'patrol_metrics_service.dart';

class PatrolRouteCoverageGenerator {
  const PatrolRouteCoverageGenerator({
    this.maximumSpacingMeters = 100,
    this.maximumSections = 2000,
    PatrolMetricsService metrics = const PatrolMetricsService(),
  }) : _metrics = metrics;

  final double maximumSpacingMeters;
  final int maximumSections;
  final PatrolMetricsService _metrics;
  static const _uuid = Uuid();

  PatrolRoutePlan generate({
    required PatrolCoverageCheckpoint start,
    required PatrolCoverageCheckpoint end,
    Iterable<PatrolCoverageCheckpoint> stops = const [],
  }) {
    final routeStops = List<PatrolCoverageCheckpoint>.unmodifiable(stops);
    final route = [start, ...routeStops, end];
    if (route.length < 2) {
      throw ArgumentError('A route needs a start and end location.');
    }
    final sectionCount = _sectionCount(route);
    if (sectionCount == 0) {
      throw ArgumentError('Choose different start and end locations.');
    }
    if (sectionCount > maximumSections) {
      throw ArgumentError(
        'Route is too long to generate safely. Shorten the route or add stops.',
      );
    }

    final sections = <PatrolCoverageCheckpoint>[];
    for (var segmentIndex = 0; segmentIndex < route.length - 1; segmentIndex++) {
      final segmentStart = route[segmentIndex];
      final segmentEnd = route[segmentIndex + 1];
      final distance = _distance(segmentStart, segmentEnd);
      final steps = math.max(1, (distance / maximumSpacingMeters).ceil());
      for (var step = 0; step < steps; step++) {
        final fraction = step / steps;
        sections.add(
          PatrolCoverageCheckpoint(
            id: _uuid.v4(),
            name: 'Route section ${sections.length + 1}',
            latitude:
                segmentStart.latitude +
                (segmentEnd.latitude - segmentStart.latitude) * fraction,
            longitude:
                segmentStart.longitude +
                (segmentEnd.longitude - segmentStart.longitude) * fraction,
          ),
        );
      }
    }
    sections.add(
      PatrolCoverageCheckpoint(
        id: _uuid.v4(),
        name: 'Route section ${sections.length + 1}',
        latitude: end.latitude,
        longitude: end.longitude,
      ),
    );
    return PatrolRoutePlan(
      start: start,
      end: end,
      stops: routeStops,
      coverageSections: sections,
    );
  }

  int _sectionCount(List<PatrolCoverageCheckpoint> route) {
    var count = 1;
    for (var index = 0; index < route.length - 1; index++) {
      final distance = _distance(route[index], route[index + 1]);
      if (distance < 1) {
        throw ArgumentError(
          'Start, stops, and end must not overlap each other.',
        );
      }
      count += (distance / maximumSpacingMeters).ceil();
    }
    return count;
  }

  double _distance(
    PatrolCoverageCheckpoint first,
    PatrolCoverageCheckpoint second,
  ) => _metrics.distanceBetween(
    PatrolLocation(
      latitude: first.latitude,
      longitude: first.longitude,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      source: PatrolLocationSource.manual,
    ),
    PatrolLocation(
      latitude: second.latitude,
      longitude: second.longitude,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      source: PatrolLocationSource.manual,
    ),
  );
}
