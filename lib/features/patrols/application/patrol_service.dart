import 'package:uuid/uuid.dart';

import '../domain/patrol.dart';
import '../domain/patrol_records.dart';
import '../domain/patrol_repository.dart';
import '../domain/patrol_workflow_policy.dart';
import 'patrol_coverage_service.dart';

class PatrolListResult {
  const PatrolListResult({required this.patrols, this.assignmentError});

  final List<Patrol> patrols;
  final Object? assignmentError;
}

class PatrolService {
  PatrolService({
    required PatrolRepository repository,
    PatrolAssignmentSource? assignmentSource,
    this.coverageService = const PatrolCoverageService(),
    Uuid? uuid,
  }) : _repository = repository,
       _assignmentSource = assignmentSource,
       _uuid = uuid ?? const Uuid();

  final PatrolRepository _repository;
  final PatrolAssignmentSource? _assignmentSource;
  final PatrolCoverageService coverageService;
  final Uuid _uuid;

  Future<List<Patrol>> listForRanger(String rangerId) =>
      _repository.listForRanger(rangerId);

  Future<PatrolListResult> loadAssignedPatrols(String rangerId) async {
    final local = await _repository.listForRanger(rangerId);
    final source = _assignmentSource;
    if (source == null) {
      return PatrolListResult(
        patrols: List.unmodifiable(local),
        assignmentError: StateError(
          'No patrol assignment source is configured.',
        ),
      );
    }
    try {
      final assignments = await source.loadAssignedTo(rangerId);
      return await _mergeAssignments(rangerId, local, assignments);
    } catch (error) {
      return PatrolListResult(
        patrols: List.unmodifiable(local),
        assignmentError: error,
      );
    }
  }

  Stream<PatrolListResult> watchAssignedPatrols(String rangerId) {
    final source = _assignmentSource;
    if (source == null) {
      return Stream.error(
        StateError('No patrol assignment source is configured.'),
      );
    }
    return source.watchAssignedTo(rangerId).asyncMap((assignments) async {
      final local = await _repository.listForRanger(rangerId);
      return _mergeAssignments(rangerId, local, assignments);
    });
  }

  Future<PatrolListResult> _mergeAssignments(
    String rangerId,
    List<Patrol> local,
    List<Patrol> assignments,
  ) async {
    final merged = <String, Patrol>{};
    final persistenceErrors = <String>[];
    for (final assignment in assignments) {
      if (assignment.rangerId != rangerId) {
        persistenceErrors.add(
          'The assignment source returned a patrol for a different ranger.',
        );
        continue;
      }
      final current = local.where(
        (patrol) => patrol.patrolId == assignment.patrolId,
      );
      final patrol = current.isEmpty
          ? assignment
          : current.first.status == PatrolStatus.assigned
          ? current.first.copyWith(
              rangerName: assignment.rangerName,
              area: assignment.area,
              plannedRoute: assignment.plannedRoute,
              clearPlannedRoute: assignment.plannedRoute == null,
            )
          : current.first;
      merged[patrol.patrolId] = patrol;
      if (current.isEmpty || current.first.status == PatrolStatus.assigned) {
        try {
          await _repository.save(patrol);
        } catch (error) {
          persistenceErrors.add(
            'Assignment ${assignment.patrolId} loaded from server but '
            'could not be cached locally: $error',
          );
        }
      }
    }
    for (final patrol in local) {
      merged.putIfAbsent(patrol.patrolId, () => patrol);
    }
    return PatrolListResult(
      patrols: List.unmodifiable(merged.values),
      assignmentError: persistenceErrors.isEmpty
          ? null
          : StateError(persistenceErrors.join('\n')),
    );
  }

  Future<void> saveAssignedPatrol(Patrol patrol) async {
    PatrolWorkflowPolicy.validateAssignment(patrol);
    await _repository.save(patrol);
  }

  Future<Patrol> start({
    required String rangerId,
    required String localId,
    required PatrolLocation location,
    required DateTime at,
  }) async {
    final patrol = await _load(rangerId, localId);
    PatrolWorkflowPolicy.validateTransition(
      current: patrol.status,
      next: PatrolStatus.inProgress,
    );
    if (patrol.status == PatrolStatus.assigned) {
      PatrolWorkflowPolicy.validateAssignment(patrol);
    }
    return _save(
      patrol.copyWith(
        status: PatrolStatus.inProgress,
        startedAt: at,
        startLocation: location,
        syncInfo: PatrolSyncInfo(
          status: PatrolSyncStatus.pendingSync,
          lastAttemptAt: patrol.syncInfo.lastAttemptAt,
          lastSyncedAt: patrol.syncInfo.lastSyncedAt,
        ),
      ),
    );
  }

  Future<Patrol> pause({
    required String rangerId,
    required String localId,
    required DateTime at,
    String? reason,
  }) async {
    final patrol = await _load(rangerId, localId);
    PatrolWorkflowPolicy.validateTransition(
      current: patrol.status,
      next: PatrolStatus.paused,
    );
    return _save(
      patrol.copyWith(
        status: PatrolStatus.paused,
        pauseResumeEvents: [
          ...patrol.pauseResumeEvents,
          _pauseEvent(PatrolPauseResumeAction.pause, at, reason),
        ],
      ),
    );
  }

  Future<Patrol> resume({
    required String rangerId,
    required String localId,
    required DateTime at,
  }) async {
    final patrol = await _load(rangerId, localId);
    PatrolWorkflowPolicy.validateTransition(
      current: patrol.status,
      next: PatrolStatus.inProgress,
    );
    return _save(
      patrol.copyWith(
        status: PatrolStatus.inProgress,
        interruptionReason: null,
        clearInterruptionReason: true,
        pauseResumeEvents: [
          ...patrol.pauseResumeEvents,
          _pauseEvent(PatrolPauseResumeAction.resume, at, null),
        ],
      ),
    );
  }

  Future<Patrol> complete({
    required String rangerId,
    required String localId,
    required PatrolLocation endLocation,
    required DateTime at,
  }) async {
    final patrol = await _load(rangerId, localId);
    PatrolWorkflowPolicy.validateTransition(
      current: patrol.status,
      next: PatrolStatus.completedPendingSync,
    );
    return _save(
      patrol.copyWith(
        status: PatrolStatus.completedPendingSync,
        endedAt: at,
        endLocation: endLocation,
        syncInfo: PatrolSyncInfo(
          status: PatrolSyncStatus.pendingSync,
          lastAttemptAt: patrol.syncInfo.lastAttemptAt,
          lastSyncedAt: patrol.syncInfo.lastSyncedAt,
        ),
      ),
    );
  }

  Future<Patrol> abort({
    required String rangerId,
    required String localId,
    required String reason,
    required DateTime at,
    PatrolLocation? endLocation,
  }) => _terminate(
    rangerId: rangerId,
    localId: localId,
    status: PatrolStatus.aborted,
    reason: reason,
    at: at,
    endLocation: endLocation,
  );

  Future<Patrol> markIncomplete({
    required String rangerId,
    required String localId,
    required String reason,
    required DateTime at,
    PatrolLocation? endLocation,
  }) => _terminate(
    rangerId: rangerId,
    localId: localId,
    status: PatrolStatus.incomplete,
    reason: reason,
    at: at,
    endLocation: endLocation,
  );

  Future<Patrol> interrupt({
    required String rangerId,
    required String localId,
    required String reason,
    DateTime? at,
  }) async {
    final patrol = await _load(rangerId, localId);
    PatrolWorkflowPolicy.validateTransition(
      current: patrol.status,
      next: PatrolStatus.interrupted,
      reason: reason,
    );
    return _save(
      patrol.copyWith(
        status: PatrolStatus.interrupted,
        interruptionReason: reason.trim(),
        pauseResumeEvents: [
          ...patrol.pauseResumeEvents,
          _pauseEvent(
            PatrolPauseResumeAction.pause,
            (at ?? DateTime.now()).toUtc(),
            reason,
          ),
        ],
      ),
    );
  }

  Future<Patrol> recordRoutePoint({
    required String rangerId,
    required String localId,
    required PatrolRoutePoint point,
  }) async {
    final patrol = await _load(rangerId, localId);
    if (patrol.status != PatrolStatus.inProgress) {
      throw StateError('Route points can only be recorded during a patrol.');
    }
    if (point.location.source != PatrolLocationSource.gps) {
      throw ArgumentError('A tracked route point must use GPS location.');
    }
    _ensureUniqueId(patrol.routePoints.map((item) => item.id), point.id);
    return _save(patrol.copyWith(routePoints: [...patrol.routePoints, point]));
  }

  Future<Patrol> addManualWaypoint({
    required String rangerId,
    required String localId,
    required PatrolWaypoint waypoint,
  }) async {
    final patrol = await _load(rangerId, localId);
    PatrolWorkflowPolicy.ensureCanRecord(patrol, recordType: 'a waypoint');
    if (waypoint.location.source != PatrolLocationSource.manual) {
      throw ArgumentError(
        'A manually placed waypoint must use manual location.',
      );
    }
    _requireText(waypoint.id, 'Waypoint ID');
    _requireText(waypoint.description, 'Waypoint description');
    _ensureUniqueId(patrol.manualWaypoints.map((item) => item.id), waypoint.id);
    return _save(
      patrol.copyWith(manualWaypoints: [...patrol.manualWaypoints, waypoint]),
    );
  }

  Future<Patrol> addObservation({
    required String rangerId,
    required String localId,
    required PatrolObservation observation,
  }) async {
    final patrol = await _load(rangerId, localId);
    PatrolWorkflowPolicy.ensureCanRecord(patrol, recordType: 'an observation');
    _requireText(observation.id, 'Observation ID');
    _requireText(observation.description, 'Observation description');
    _ensureUniqueId(patrol.observations.map((item) => item.id), observation.id);
    return _save(
      patrol.copyWith(observations: [...patrol.observations, observation]),
    );
  }

  Future<Patrol> addPhotograph({
    required String rangerId,
    required String localId,
    required PatrolPhoto photograph,
  }) async {
    final patrol = await _load(rangerId, localId);
    PatrolWorkflowPolicy.ensureCanRecord(patrol, recordType: 'a photograph');
    _requireText(photograph.id, 'Photograph ID');
    _requireText(photograph.fileName, 'Photograph file name');
    _requireText(photograph.base64Data, 'Photograph data');
    if (photograph.observationId != null &&
        !patrol.observations.any(
          (item) => item.id == photograph.observationId,
        )) {
      throw ArgumentError('The photograph references an unknown observation.');
    }
    _ensureUniqueId(patrol.photographs.map((item) => item.id), photograph.id);
    return _save(
      patrol.copyWith(photographs: [...patrol.photographs, photograph]),
    );
  }

  Future<Patrol> updateCoverage({
    required String rangerId,
    required String localId,
    required PatrolCoverage coverage,
  }) async {
    final patrol = await _load(rangerId, localId);
    if (patrol.status == PatrolStatus.assigned) {
      throw StateError('Coverage cannot be calculated before patrol starts.');
    }
    return _save(patrol.copyWith(coverage: coverage));
  }

  Future<Patrol> calculateCoverage({
    required String rangerId,
    required String localId,
    DateTime? calculatedAt,
    PatrolLocation? additionalLocation,
  }) async {
    final patrol = await _load(rangerId, localId);
    if (patrol.status != PatrolStatus.inProgress &&
        patrol.status != PatrolStatus.paused) {
      throw StateError('Coverage can only be calculated for an active patrol.');
    }
    final coverage = coverageService.calculate(
      patrol,
      calculatedAt: calculatedAt,
      additionalLocation: additionalLocation,
    );
    if (coverage == null) return patrol;
    return _save(patrol.copyWith(coverage: coverage));
  }

  Future<Patrol> markSyncing({
    required String rangerId,
    required String localId,
    required DateTime attemptedAt,
  }) async {
    final patrol = await _load(rangerId, localId);
    return _save(
      patrol.copyWith(
        syncInfo: PatrolSyncInfo(
          status: PatrolSyncStatus.syncing,
          lastAttemptAt: attemptedAt,
          lastSyncedAt: patrol.syncInfo.lastSyncedAt,
        ),
      ),
    );
  }

  Future<Patrol> markSyncFailed({
    required String rangerId,
    required String localId,
    required DateTime attemptedAt,
    required String error,
  }) async {
    _requireText(error, 'Synchronization error');
    final patrol = await _load(rangerId, localId);
    return _save(
      patrol.copyWith(
        syncInfo: PatrolSyncInfo(
          status: PatrolSyncStatus.failed,
          lastAttemptAt: attemptedAt,
          lastSyncedAt: patrol.syncInfo.lastSyncedAt,
          lastError: error,
        ),
      ),
    );
  }

  Future<Patrol> markCompletedSynced({
    required String rangerId,
    required String localId,
    required DateTime syncedAt,
  }) async {
    final patrol = await _load(rangerId, localId);
    PatrolWorkflowPolicy.validateCompletionSync(patrol);
    PatrolWorkflowPolicy.validateTransition(
      current: patrol.status,
      next: PatrolStatus.completedSynced,
    );
    return _save(
      patrol.copyWith(
        status: PatrolStatus.completedSynced,
        syncInfo: PatrolSyncInfo(
          status: PatrolSyncStatus.synced,
          lastAttemptAt: syncedAt,
          lastSyncedAt: syncedAt,
        ),
      ),
    );
  }

  Future<Patrol> _terminate({
    required String rangerId,
    required String localId,
    required PatrolStatus status,
    required String reason,
    required DateTime at,
    required PatrolLocation? endLocation,
  }) async {
    _requireText(reason, 'Termination reason');
    final patrol = await _load(rangerId, localId);
    PatrolWorkflowPolicy.validateTransition(
      current: patrol.status,
      next: status,
      reason: reason,
    );
    return _save(
      patrol.copyWith(
        status: status,
        endedAt: at,
        endLocation: endLocation,
        earlyTerminationReason: reason.trim(),
        interruptionReason: null,
        clearInterruptionReason: true,
        syncInfo: PatrolSyncInfo(
          status: PatrolSyncStatus.pendingSync,
          lastAttemptAt: patrol.syncInfo.lastAttemptAt,
          lastSyncedAt: patrol.syncInfo.lastSyncedAt,
        ),
      ),
    );
  }

  PatrolPauseResumeEvent _pauseEvent(
    PatrolPauseResumeAction action,
    DateTime at,
    String? reason,
  ) => PatrolPauseResumeEvent(
    id: _uuid.v4(),
    action: action,
    occurredAt: at,
    reason: reason?.trim().isEmpty == true ? null : reason?.trim(),
  );

  Future<Patrol> _load(String rangerId, String localId) async {
    final patrol = await _repository.findByLocalId(rangerId, localId);
    if (patrol == null) {
      throw StateError('The saved patrol could not be found.');
    }
    return patrol;
  }

  Future<Patrol> _save(Patrol patrol) async {
    await _repository.save(patrol);
    return patrol;
  }

  void _ensureUniqueId(Iterable<String> existingIds, String id) {
    _requireText(id, 'Record ID');
    if (existingIds.contains(id)) {
      throw StateError('This patrol already contains a record with ID "$id".');
    }
  }

  void _requireText(String value, String label) {
    if (value.trim().isEmpty) throw ArgumentError('$label cannot be empty.');
  }
}
