import 'dart:math' as math;

import '../domain/patrol.dart';
import '../domain/patrol_records.dart';

/// Calculates recorded/planned route distances and active duration from patrol evidence.
class PatrolMetricsService {
  const PatrolMetricsService();

  /// Returns route locations in timestamp order, excluding fixes before patrol start.
  List<PatrolLocation> actualRouteLocations(Patrol patrol) {
    final start = patrol.startLocation;
    final startTime = start?.recordedAt ?? patrol.startedAt;
    final locations = <(int, PatrolLocation)>[];

    if (start != null) locations.add((0, start));
    locations.addAll(
      patrol.routePoints.indexed.map(
        (entry) => (entry.$1 + 1, entry.$2.location),
      ),
    );
    locations.addAll(
      patrol.manualWaypoints.indexed.map(
        (entry) =>
            (entry.$1 + patrol.routePoints.length + 1, entry.$2.location),
      ),
    );
    final end = patrol.endLocation;
    if (end != null) {
      locations.add((
        patrol.routePoints.length + patrol.manualWaypoints.length + 1,
        end,
      ));
    }

    locations.sort((first, second) {
      final timeOrder = first.$2.recordedAt.compareTo(second.$2.recordedAt);
      return timeOrder == 0 ? first.$1.compareTo(second.$1) : timeOrder;
    });

    return List.unmodifiable([
      for (final entry in locations)
        if (startTime == null ||
            !entry.$2.recordedAt.isBefore(startTime) ||
            identical(entry.$2, start))
          entry.$2,
    ]);
  }

  /// Sums geodesic distances between ordered recorded route locations.
  double distanceTravelledMeters(Patrol patrol) {
    final locations = actualRouteLocations(patrol);
    var distance = 0.0;
    for (var index = 1; index < locations.length; index++) {
      distance += _distanceBetween(locations[index - 1], locations[index]);
    }
    return distance;
  }

  /// Calculates geodesic distance between two patrol locations.
  double distanceBetween(PatrolLocation first, PatrolLocation second) =>
      _distanceBetween(first, second);

  /// Calculates the local projected distance from a location to a route segment.
  double distanceToSegmentMeters(
    PatrolLocation point,
    PatrolLocation segmentStart,
    PatrolLocation segmentEnd,
  ) {
    const earthRadiusMeters = 6371000.0;
    final latitudeRadians = _radians(point.latitude);
    final metersPerDegree = earthRadiusMeters * math.pi / 180;

    (double, double) project(PatrolLocation location) => (
      (location.longitude - point.longitude) *
          math.cos(latitudeRadians) *
          metersPerDegree,
      (location.latitude - point.latitude) * metersPerDegree,
    );

    final start = project(segmentStart);
    final end = project(segmentEnd);
    final deltaX = end.$1 - start.$1;
    final deltaY = end.$2 - start.$2;
    final lengthSquared = deltaX * deltaX + deltaY * deltaY;
    if (lengthSquared == 0) {
      return math.sqrt(start.$1 * start.$1 + start.$2 * start.$2);
    }

    final fraction = (-(start.$1 * deltaX + start.$2 * deltaY) /
            lengthSquared)
        .clamp(0.0, 1.0);
    final nearestX = start.$1 + fraction * deltaX;
    final nearestY = start.$2 + fraction * deltaY;
    return math.sqrt(nearestX * nearestX + nearestY * nearestY);
  }

  /// Sums geodesic distance across ordered planned route locations.
  double plannedRouteDistanceMeters(PatrolRoutePlan route) {
    final locations = route.routeLocations;
    var distance = 0.0;
    for (var index = 1; index < locations.length; index++) {
      final previous = locations[index - 1];
      final current = locations[index];
      distance += _distanceBetweenCoordinates(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );
    }
    return distance;
  }

  /// Computes elapsed patrol time through [now], excluding recorded paused intervals.
  Duration durationAt(Patrol patrol, DateTime now) {
    final start = patrol.startedAt;
    if (start == null) return Duration.zero;
    final finish = patrol.endedAt ?? now;
    if (!finish.isAfter(start)) return Duration.zero;

    final events = patrol.pauseResumeEvents.toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    DateTime? pauseStartedAt;
    var pausedDuration = Duration.zero;
    for (final event in events) {
      if (event.occurredAt.isAfter(finish)) continue;
      if (event.action == PatrolPauseResumeAction.pause) {
        pauseStartedAt ??= event.occurredAt;
      } else if (pauseStartedAt != null) {
        final resumeAt = event.occurredAt.isBefore(finish)
            ? event.occurredAt
            : finish;
        if (resumeAt.isAfter(pauseStartedAt)) {
          pausedDuration += resumeAt.difference(pauseStartedAt);
        }
        pauseStartedAt = null;
      }
    }
    if (pauseStartedAt != null && finish.isAfter(pauseStartedAt)) {
      pausedDuration += finish.difference(pauseStartedAt);
    }
    final activeDuration = finish.difference(start) - pausedDuration;
    return activeDuration.isNegative ? Duration.zero : activeDuration;
  }

  /// Calculates distance using the shared coordinate-based geodesic helper.
  static double _distanceBetween(PatrolLocation first, PatrolLocation second) {
    return _distanceBetweenCoordinates(
      first.latitude,
      first.longitude,
      second.latitude,
      second.longitude,
    );
  }

  /// Calculates great-circle distance with the haversine formula.
  static double _distanceBetweenCoordinates(
    double firstLatitude,
    double firstLongitude,
    double secondLatitude,
    double secondLongitude,
  ) {
    const earthRadiusMeters = 6371000.0;
    final latitude1 = _radians(firstLatitude);
    final latitude2 = _radians(secondLatitude);
    final latitudeDelta = _radians(secondLatitude - firstLatitude);
    final longitudeDelta = _radians(secondLongitude - firstLongitude);
    final a =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(latitude1) *
            math.cos(latitude2) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Converts degrees to radians for spherical calculations.
  static double _radians(double degrees) => degrees * math.pi / 180;
}
