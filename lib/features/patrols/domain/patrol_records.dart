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

enum PatrolSyncStatus { localOnly, pendingSync, syncing, synced, failed }

enum PatrolLocationSource { gps, manual }

enum PatrolGpsState {
  acquiring,
  available,
  inaccurate,
  disabled,
  permissionDenied,
  unavailable,
}

enum PatrolPauseResumeAction { pause, resume }

enum PatrolCompletionState {
  active,
  completed,
  incomplete,
  aborted,
  interrupted,
}

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

  final String? parkId;
  final String parkName;
  final String? zoneId;
  final String zoneName;
  final String? routeId;
  final String routeName;
  final double? centerLatitude;
  final double? centerLongitude;
}

class PatrolLocation {
  PatrolLocation({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.source,
    this.accuracyMeters,
  }) {
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError.value(latitude, 'latitude', 'Must be between -90 and 90.');
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

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final PatrolLocationSource source;
  final double? accuracyMeters;
}

class PatrolRoutePoint {
  const PatrolRoutePoint({required this.id, required this.location});

  final String id;
  final PatrolLocation location;
}

class PatrolWaypoint {
  const PatrolWaypoint({
    required this.id,
    required this.description,
    required this.location,
  });

  final String id;
  final String description;
  final PatrolLocation location;
}

class PatrolObservation {
  const PatrolObservation({
    required this.id,
    required this.description,
    required this.location,
    this.category,
  });

  final String id;
  final String description;
  final PatrolLocation location;
  final String? category;
}

class PatrolPhoto {
  const PatrolPhoto({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.base64Data,
    required this.capturedAt,
    this.observationId,
  });

  final String id;
  final String fileName;
  final String contentType;
  final String base64Data;
  final DateTime capturedAt;
  final String? observationId;
}

class PatrolPauseResumeEvent {
  const PatrolPauseResumeEvent({
    required this.id,
    required this.action,
    required this.occurredAt,
    this.reason,
  });

  final String id;
  final PatrolPauseResumeAction action;
  final DateTime occurredAt;
  final String? reason;
}

class PatrolSyncInfo {
  const PatrolSyncInfo({
    this.status = PatrolSyncStatus.localOnly,
    this.lastAttemptAt,
    this.lastSyncedAt,
    this.lastError,
  });

  final PatrolSyncStatus status;
  final DateTime? lastAttemptAt;
  final DateTime? lastSyncedAt;
  final String? lastError;
}

class PatrolCoverage {
  PatrolCoverage({
    required this.totalSections,
    required this.coveredSections,
    required Iterable<String> uncoveredSectionIds,
    required this.calculatedAt,
  }) : uncoveredSectionIds = List.unmodifiable(uncoveredSectionIds) {
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
    if (this.uncoveredSectionIds.toSet().length !=
        this.uncoveredSectionIds.length) {
      throw ArgumentError('Uncovered section IDs must be unique.');
    }
  }

  final int totalSections;
  final int coveredSections;
  final List<String> uncoveredSectionIds;
  final DateTime calculatedAt;

  double get coveragePercent =>
      totalSections == 0 ? 0 : coveredSections * 100 / totalSections;
}
