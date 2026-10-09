import 'patrol_records.dart';

/// Immutable UC01 patrol aggregate. Validates IDs, timestamps, and completion
/// location; keeps lifecycle and sync status separate. Route distance and active
/// duration are derived from recorded evidence.
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
    this.plannedRoute,
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
      throw ArgumentError(
        'Patrol, local, and assigned ranger IDs are required.',
      );
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
        throw ArgumentError(
          'A completed patrol must have started with a location.',
        );
      }
    }
  }

  /// Stable patrol identifier from the assignment source.
  final String patrolId;

  /// Stable device-local identifier used for local lookup and sync deduplication.
  final String localId;

  /// ID of the ranger assigned to this patrol.
  final String rangerId;

  /// Display name of the assigned ranger.
  final String rangerName;

  /// Park, zone, and route assigned to this patrol.
  final PatrolArea area;

  /// Lifecycle state; sync state is stored separately in [syncInfo].
  final PatrolStatus status;

  /// Time the patrol was assigned, when known.
  final DateTime? assignedAt;

  /// Patrol start time used for duration calculations.
  final DateTime? startedAt;

  /// Patrol end time for completed or otherwise finished patrols.
  final DateTime? endedAt;

  /// Location captured when the patrol started.
  final PatrolLocation? startLocation;

  /// Location captured when the patrol ended.
  final PatrolLocation? endLocation;

  /// Immutable GPS route samples recorded during tracking.
  final List<PatrolRoutePoint> routePoints;

  /// Immutable manually placed points recorded by the ranger.
  final List<PatrolWaypoint> manualWaypoints;

  /// Planned route and coverage sections, when available.
  final PatrolRoutePlan? plannedRoute;

  /// Coverage sections from the planned route, or an empty list when no route is planned.
  List<PatrolCoverageCheckpoint> get plannedCoverageSections =>
      plannedRoute?.coverageSections ?? const [];

  /// Immutable field observations recorded for this patrol.
  final List<PatrolObservation> observations;

  /// Immutable photo evidence associated with this patrol.
  final List<PatrolPhoto> photographs;

  /// Immutable pause/resume history used to exclude paused time.
  final List<PatrolPauseResumeEvent> pauseResumeEvents;

  /// Reason supplied when the patrol is aborted or marked incomplete.
  final String? earlyTerminationReason;

  /// Reason the patrol was interrupted and may need resumption.
  final String? interruptionReason;

  /// Sync status and timestamps, independent of [status].
  final PatrolSyncInfo syncInfo;

  /// Most recently calculated planned-route coverage summary.
  final PatrolCoverage? coverage;

  /// Maps the lifecycle state to a broad active/completed/interrupted classification.
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

  /// Returns a new patrol with selected values replaced while preserving unspecified data.
  Patrol copyWith({
    String? localId,
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
    PatrolRoutePlan? plannedRoute,
    bool clearPlannedRoute = false,
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
    localId: localId ?? this.localId,
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
    plannedRoute: clearPlannedRoute ? null : plannedRoute ?? this.plannedRoute,
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

  /// Whether this lifecycle state requires a recorded start time.
  static bool _requiresStartTime(PatrolStatus status) => {
    PatrolStatus.inProgress,
    PatrolStatus.paused,
    PatrolStatus.completedPendingSync,
    PatrolStatus.completedSynced,
    PatrolStatus.incomplete,
    PatrolStatus.interrupted,
  }.contains(status);

  /// Whether this lifecycle state requires a recorded end time.
  static bool _requiresEndTime(PatrolStatus status) => {
    PatrolStatus.completedPendingSync,
    PatrolStatus.completedSynced,
    PatrolStatus.incomplete,
    PatrolStatus.aborted,
  }.contains(status);
}
