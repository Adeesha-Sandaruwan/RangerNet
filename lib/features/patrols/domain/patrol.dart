import 'dart:math' as math;

import 'patrol_records.dart';

class Patrol {
  Patrol({
    required this.patrolId,
    required this.localId,
    required this.rangerId,
    required this.rangerName,
    required this.area,
    this.status = PatrolStatus.assigned,
    this.assignedAt,
    this.startedAt,
    this.endedAt,
    this.startLocation,
    this.endLocation,
    Iterable<PatrolRoutePoint> routePoints = const [],
    Iterable<PatrolWaypoint> manualWaypoints = const [],
    Iterable<PatrolObservation> observations = const [],
    Iterable<PatrolPhoto> photographs = const [],
    Iterable<PatrolPauseResumeEvent> pauseResumeEvents = const [],
    this.earlyTerminationReason,
    this.interruptionReason,
    this.syncInfo = const PatrolSyncInfo(),
    this.coverage,
  }) : routePoints = List.unmodifiable(routePoints),
       manualWaypoints = List.unmodifiable(manualWaypoints),
       observations = List.unmodifiable(observations),
       photographs = List.unmodifiable(photographs),
       pauseResumeEvents = List.unmodifiable(pauseResumeEvents) {
    if (patrolId.trim().isEmpty ||
        localId.trim().isEmpty ||
        rangerId.trim().isEmpty) {
      throw ArgumentError('Patrol, local, and assigned ranger IDs are required.');
    }
    if (startedAt != null && endedAt != null && endedAt!.isBefore(startedAt!)) {
      throw ArgumentError('Patrol end time cannot be before its start time.');
    }
    if (_requiresStartTime(status) && startedAt == null) {
      throw ArgumentError('A started patrol must have a start time.');
    }
    if (_requiresEndTime(status) && endedAt == null) {
      throw ArgumentError('A finished patrol must have an end time.');
    }
    if (status == PatrolStatus.completedPendingSync ||
        status == PatrolStatus.completedSynced) {
      if (startedAt == null || startLocation == null) {
        throw ArgumentError('A completed patrol must have started with a location.');
      }
    }
  }

  final String patrolId;
  final String localId;
  final String rangerId;
  final String rangerName;
  final PatrolArea area;
  final PatrolStatus status;
  final DateTime? assignedAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final PatrolLocation? startLocation;
  final PatrolLocation? endLocation;
  final List<PatrolRoutePoint> routePoints;
  final List<PatrolWaypoint> manualWaypoints;
  final List<PatrolObservation> observations;
  final List<PatrolPhoto> photographs;
  final List<PatrolPauseResumeEvent> pauseResumeEvents;
  final String? earlyTerminationReason;
  final String? interruptionReason;
  final PatrolSyncInfo syncInfo;
  final PatrolCoverage? coverage;

  PatrolCompletionState get completionState => switch (status) {
    PatrolStatus.assigned ||
    PatrolStatus.inProgress ||
    PatrolStatus.paused => PatrolCompletionState.active,
    PatrolStatus.completedPendingSync ||
    PatrolStatus.completedSynced => PatrolCompletionState.completed,
    PatrolStatus.incomplete => PatrolCompletionState.incomplete,
    PatrolStatus.aborted => PatrolCompletionState.aborted,
    PatrolStatus.interrupted => PatrolCompletionState.interrupted,
  };

  double get distanceTravelledMeters {
    var distance = 0.0;
    for (var index = 1; index < routePoints.length; index++) {
      distance += _distanceBetween(
        routePoints[index - 1].location,
        routePoints[index].location,
      );
    }
    return distance;
  }

  Duration durationAt(DateTime now) {
    final start = startedAt;
    if (start == null) return Duration.zero;
    final finish = endedAt ?? now;
    if (!finish.isAfter(start)) return Duration.zero;

    final events = pauseResumeEvents.toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    DateTime? pauseStartedAt;
    var pausedDuration = Duration.zero;
    for (final event in events) {
      if (!event.occurredAt.isAfter(finish)) {
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
    }
    if (pauseStartedAt != null && finish.isAfter(pauseStartedAt)) {
      pausedDuration += finish.difference(pauseStartedAt);
    }
    final activeDuration = finish.difference(start) - pausedDuration;
    return activeDuration.isNegative ? Duration.zero : activeDuration;
  }

  Patrol copyWith({
    String? rangerName,
    PatrolArea? area,
    PatrolStatus? status,
    DateTime? assignedAt,
    DateTime? startedAt,
    DateTime? endedAt,
    PatrolLocation? startLocation,
    PatrolLocation? endLocation,
    Iterable<PatrolRoutePoint>? routePoints,
    Iterable<PatrolWaypoint>? manualWaypoints,
    Iterable<PatrolObservation>? observations,
    Iterable<PatrolPhoto>? photographs,
    Iterable<PatrolPauseResumeEvent>? pauseResumeEvents,
    String? earlyTerminationReason,
    bool clearEarlyTerminationReason = false,
    String? interruptionReason,
    bool clearInterruptionReason = false,
    PatrolSyncInfo? syncInfo,
    PatrolCoverage? coverage,
    bool clearCoverage = false,
  }) => Patrol(
    patrolId: patrolId,
    localId: localId,
    rangerId: rangerId,
    rangerName: rangerName ?? this.rangerName,
    area: area ?? this.area,
    status: status ?? this.status,
    assignedAt: assignedAt ?? this.assignedAt,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    startLocation: startLocation ?? this.startLocation,
    endLocation: endLocation ?? this.endLocation,
    routePoints: routePoints ?? this.routePoints,
    manualWaypoints: manualWaypoints ?? this.manualWaypoints,
    observations: observations ?? this.observations,
    photographs: photographs ?? this.photographs,
    pauseResumeEvents: pauseResumeEvents ?? this.pauseResumeEvents,
    earlyTerminationReason: clearEarlyTerminationReason
        ? null
        : earlyTerminationReason ?? this.earlyTerminationReason,
    interruptionReason: clearInterruptionReason
        ? null
        : interruptionReason ?? this.interruptionReason,
    syncInfo: syncInfo ?? this.syncInfo,
    coverage: clearCoverage ? null : coverage ?? this.coverage,
  );

  static bool _requiresStartTime(PatrolStatus status) => {
    PatrolStatus.inProgress,
    PatrolStatus.paused,
    PatrolStatus.completedPendingSync,
    PatrolStatus.completedSynced,
    PatrolStatus.incomplete,
    PatrolStatus.interrupted,
  }.contains(status);

  static bool _requiresEndTime(PatrolStatus status) => {
    PatrolStatus.completedPendingSync,
    PatrolStatus.completedSynced,
    PatrolStatus.incomplete,
    PatrolStatus.aborted,
  }.contains(status);

  static double _distanceBetween(PatrolLocation first, PatrolLocation second) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = _radians(first.latitude);
    final lat2 = _radians(second.latitude);
    final latitudeDelta = _radians(second.latitude - first.latitude);
    final longitudeDelta = _radians(second.longitude - first.longitude);
    final a =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
