import 'dart:math' as math;

import '../domain/patrol.dart';
import '../domain/patrol_records.dart';

class PatrolMetricsService {
  const PatrolMetricsService();

  double distanceTravelledMeters(Patrol patrol) {
    if (patrol.routePoints.isEmpty) return 0;
    final locations = <PatrolLocation>[
      if (patrol.startLocation != null) patrol.startLocation!,
      ...patrol.routePoints.map((point) => point.location),
      if (patrol.endLocation?.source == PatrolLocationSource.gps &&
          patrol.endLocation!.recordedAt.isAfter(
            patrol.routePoints.last.location.recordedAt,
          ))
        patrol.endLocation!,
    ];
    var distance = 0.0;
    for (var index = 1; index < locations.length; index++) {
      distance += _distanceBetween(
        locations[index - 1],
        locations[index],
      );
    }
    return distance;
  }

  double distanceBetween(PatrolLocation first, PatrolLocation second) =>
      _distanceBetween(first, second);

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

  static double _distanceBetween(PatrolLocation first, PatrolLocation second) {
    const earthRadiusMeters = 6371000.0;
    final latitude1 = _radians(first.latitude);
    final latitude2 = _radians(second.latitude);
    final latitudeDelta = _radians(second.latitude - first.latitude);
    final longitudeDelta = _radians(second.longitude - first.longitude);
    final a =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(latitude1) *
            math.cos(latitude2) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
