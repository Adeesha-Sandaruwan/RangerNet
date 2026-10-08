import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/patrols/application/patrol_metrics_service.dart';
import 'package:rangernet/features/patrols/application/patrol_route_coverage_generator.dart';
import 'package:rangernet/features/patrols/domain/patrol_records.dart';

void main() {
  const generator = PatrolRouteCoverageGenerator(maximumSpacingMeters: 100);

  test('generates coverage sections along start, stops, and destination', () {
    final start = _point('start', 'Start', 6.1, 81.2);
    final stop = _point('stop', 'Stop 1', 6.101, 81.2);
    final end = _point('end', 'Destination', 6.102, 81.2);

    final route = generator.generate(start: start, stops: [stop], end: end);

    expect(route.start, start);
    expect(route.stops, [stop]);
    expect(route.end, end);
    expect(route.coverageSections.length, greaterThan(2));
    expect(route.coverageSections.first.latitude, start.latitude);
    expect(route.coverageSections.last.latitude, end.latitude);
    expect(
      route.coverageSections.map((section) => section.id).toSet(),
      hasLength(route.coverageSections.length),
    );
    for (var index = 1; index < route.coverageSections.length; index++) {
      final distance = const PatrolMetricsService().distanceBetween(
        _location(route.coverageSections[index - 1]),
        _location(route.coverageSections[index]),
      );
      expect(distance, lessThanOrEqualTo(100.01));
    }
  });

  test('rejects duplicate route locations and excessive coverage size', () {
    // These guards prevent invalid assignments and unbounded section generation.
    final start = _point('start', 'Start', 6.1, 81.2);
    final end = _point('end', 'Destination', 6.1, 81.2);
    expect(
      () => generator.generate(start: start, end: end),
      throwsArgumentError,
    );

    expect(
      () =>
          const PatrolRouteCoverageGenerator(
            maximumSpacingMeters: 10,
            maximumSections: 2,
          ).generate(
            start: start,
            end: _point('far-end', 'Destination', 6.2, 81.2),
          ),
      throwsArgumentError,
    );
  });
}

PatrolLocation _location(PatrolCoverageCheckpoint point) => PatrolLocation(
  latitude: point.latitude,
  longitude: point.longitude,
  recordedAt: DateTime.utc(2026),
  source: PatrolLocationSource.manual,
);

PatrolCoverageCheckpoint _point(
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
