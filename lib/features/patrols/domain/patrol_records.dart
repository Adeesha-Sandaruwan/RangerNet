/// Operational lifecycle states for an assigned or conducted patrol.
enum PatrolStatus {
  assigned,
  inProgress,
  paused,
  completedPendingSync,
  completedSynced,
  incomplete,
  aborted,
  interrupted,
}

/// Local synchronization state, separate from the patrol lifecycle status.
enum PatrolSyncStatus { localOnly, pendingSync, syncing, synced, failed }

/// Identifies whether a recorded patrol location came from GPS or manual entry.
enum PatrolLocationSource { gps, manual }

/// Availability and quality states reported by the patrol GPS provider.
enum PatrolGpsState {
  acquiring,
  available,
  inaccurate,
  disabled,
  permissionDenied,
  unavailable,
}

/// Action recorded in a patrol pause/resume history event.
enum PatrolPauseResumeAction { pause, resume }

/// Coarser completion classification derived from a patrol lifecycle status.
enum PatrolCompletionState {
  active,
  completed,
  incomplete,
  aborted,
  interrupted,
}

/// Park, zone, and route context assigned to a patrol.
class PatrolArea {
  const PatrolArea({
    this.parkId,
    required this.parkName,
    this.zoneId,
    required this.zoneName,
    this.routeId,
    required this.routeName,
    this.centerLatitude,
    this.centerLongitude,
  });

  /// Optional stable park identifier.
  final String? parkId;

  /// Display name of the park.
  final String parkName;

  /// Optional stable zone identifier.
  final String? zoneId;

  /// Display name of the zone.
  final String zoneName;

  /// Optional stable route identifier.
  final String? routeId;

  /// Display name of the route.
  final String routeName;

  /// Optional area-center latitude in decimal degrees.
  final double? centerLatitude;

  /// Optional area-center longitude in decimal degrees.
  final double? centerLongitude;
}

/// A timestamped coordinate captured from GPS or entered manually; validates coordinate ranges and accuracy.
class PatrolLocation {
  PatrolLocation({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.source,
    this.accuracyMeters,
  }) {
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError.value(
        latitude,
        'latitude',
        'Must be between -90 and 90.',
      );
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'Must be between -180 and 180.',
      );
    }
    if (accuracyMeters != null &&
        (!accuracyMeters!.isFinite || accuracyMeters! < 0)) {
      throw ArgumentError.value(
        accuracyMeters,
        'accuracyMeters',
        'Must be a non-negative finite value.',
      );
    }
  }

  /// Latitude in decimal degrees, validated to the range -90 through 90.
  final double latitude;

  /// Longitude in decimal degrees, validated to the range -180 through 180.
  final double longitude;

  /// Time at which the location was captured or entered.
  final DateTime recordedAt;

  /// Whether the coordinate came from GPS or manual entry.
  final PatrolLocationSource source;

  /// Optional reported horizontal accuracy; GPS quality checks use this value.
  final double? accuracyMeters;
}

/// A uniquely identified location sample recorded along the tracked patrol route.
class PatrolRoutePoint {
  const PatrolRoutePoint({required this.id, required this.location});

  /// Unique ID for this recorded route point.
  final String id;

  /// GPS location associated with this point.
  final PatrolLocation location;
}

/// A ranger-placed route location with a required descriptive purpose.
class PatrolWaypoint {
  const PatrolWaypoint({
    required this.id,
    required this.description,
    required this.location,
  });

  /// Unique ID for this manual waypoint.
  final String id;

  /// Ranger-provided description of the waypoint.
  final String description;

  /// Manually entered waypoint location.
  final PatrolLocation location;
}

/// A validated named coordinate used as a route stop or planned coverage section.
class PatrolCoverageCheckpoint {
  PatrolCoverageCheckpoint({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  }) {
    if (id.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('Coverage checkpoint ID and name are required.');
    }
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError.value(
        latitude,
        'latitude',
        'Must be between -90 and 90.',
      );
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'Must be between -180 and 180.',
      );
    }
  }

  /// Unique checkpoint or coverage-section ID.
  final String id;

  /// Human-readable checkpoint label.
  final String name;

  /// Checkpoint latitude in decimal degrees.
  final double latitude;

  /// Checkpoint longitude in decimal degrees.
  final double longitude;
}

/// Immutable planned route and coverage sections, with unique route/section IDs and a section limit.
class PatrolRoutePlan {
  PatrolRoutePlan({
    required this.start,
    required this.end,
    Iterable<PatrolCoverageCheckpoint> stops = const [],
    Iterable<PatrolCoverageCheckpoint> coverageSections = const [],
  }) : stops = List.unmodifiable(stops),
       coverageSections = List.unmodifiable(coverageSections) {
    final routeIds = [start.id, ...this.stops.map((stop) => stop.id), end.id];
    if (routeIds.toSet().length != routeIds.length) {
      throw ArgumentError('Route start, stop, and end IDs must be unique.');
    }
    final coverageIds = this.coverageSections.map((section) => section.id);
    if (coverageIds.toSet().length != coverageIds.length) {
      throw ArgumentError('Route coverage section IDs must be unique.');
    }
    if (this.coverageSections.length > 2000) {
      throw ArgumentError(
        'A patrol route cannot exceed 2000 coverage sections.',
      );
    }
  }

  /// First checkpoint on the planned route.
  final PatrolCoverageCheckpoint start;

  /// Final checkpoint on the planned route.
  final PatrolCoverageCheckpoint end;

  /// Ordered intermediate stops between start and end.
  final List<PatrolCoverageCheckpoint> stops;

  /// Planned sections used by patrol coverage calculations.
  final List<PatrolCoverageCheckpoint> coverageSections;

  /// Ordered start, stop, and end checkpoints for route-distance calculations.
  List<PatrolCoverageCheckpoint> get routeLocations => [start, ...stops, end];
}

/// A field observation recorded during an active or paused patrol.
class PatrolObservation {
  const PatrolObservation({
    required this.id,
    required this.description,
    required this.location,
    this.category,
  });

  /// Unique ID for this observation.
  final String id;

  /// Ranger-provided description of the field observation.
  final String description;

  /// Location associated with this observation.
  final PatrolLocation location;

  /// Optional observation category.
  final String? category;
}

/// Photo evidence stored with its metadata and Base64 payload, optionally linked to an observation.
class PatrolPhoto {
  const PatrolPhoto({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.base64Data,
    required this.capturedAt,
    this.observationId,
  });

  /// Unique ID for this photo record.
  final String id;

  /// Original or display filename for the captured image.
  final String fileName;

  /// Media content type for the photo payload.
  final String contentType;

  /// Base64-encoded image data stored with the record.
  final String base64Data;

  /// Time the photo was captured.
  final DateTime capturedAt;

  /// Optional ID of the observation associated with this photo.
  final String? observationId;
}

/// Timestamped pause/resume event used to retain patrol history and calculate active duration.
class PatrolPauseResumeEvent {
  const PatrolPauseResumeEvent({
    required this.id,
    required this.action,
    required this.occurredAt,
    this.reason,
  });

  /// Unique ID for this lifecycle event.
  final String id;

  /// Whether this event paused or resumed the patrol.
  final PatrolPauseResumeAction action;

  /// Time when the action occurred.
  final DateTime occurredAt;

  /// Optional ranger-provided reason for the action.
  final String? reason;
}

/// Synchronization metadata kept independently of the patrol lifecycle.
class PatrolSyncInfo {
  const PatrolSyncInfo({
    this.status = PatrolSyncStatus.localOnly,
    this.lastAttemptAt,
    this.lastSyncedAt,
    this.lastError,
  });

  /// Current synchronization phase for the patrol record.
  final PatrolSyncStatus status;

  /// Time of the most recent sync attempt.
  final DateTime? lastAttemptAt;

  /// Time the patrol was last successfully synchronized.
  final DateTime? lastSyncedAt;

  /// Most recent sync failure message, if any.
  final String? lastError;
}

/// Coverage summary with consistent counts and IDs for planned route sections.
class PatrolCoverage {
  PatrolCoverage({
    required this.totalSections,
    required this.coveredSections,
    Iterable<String> coveredSectionIds = const [],
    required Iterable<String> uncoveredSectionIds,
    required this.calculatedAt,
  }) : coveredSectionIds = List.unmodifiable(coveredSectionIds),
       uncoveredSectionIds = List.unmodifiable(uncoveredSectionIds) {
    if (totalSections < 0 ||
        coveredSections < 0 ||
        coveredSections > totalSections) {
      throw ArgumentError('Patrol coverage section counts are inconsistent.');
    }
    if (this.uncoveredSectionIds.length != totalSections - coveredSections) {
      throw ArgumentError(
        'Uncovered section IDs must match the number of uncovered sections.',
      );
    }
    if (this.coveredSectionIds.isNotEmpty &&
        this.coveredSectionIds.length != coveredSections) {
      throw ArgumentError(
        'Covered section IDs must match the number of covered sections.',
      );
    }
    if (this.uncoveredSectionIds.toSet().length !=
        this.uncoveredSectionIds.length) {
      throw ArgumentError('Uncovered section IDs must be unique.');
    }
  }

  /// Number of planned sections included in this calculation.
  final int totalSections;

  /// Number of planned sections considered covered.
  final int coveredSections;

  /// IDs of covered sections when supplied by the calculator.
  final List<String> coveredSectionIds;

  /// IDs of planned sections not covered by the recorded route.
  final List<String> uncoveredSectionIds;

  /// Time this coverage summary was calculated.
  final DateTime calculatedAt;

  /// Percentage of planned sections covered; returns zero for an empty plan.
  double get coveragePercent =>
      totalSections == 0 ? 0 : coveredSections * 100 / totalSections;
}
