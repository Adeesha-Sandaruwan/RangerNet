import '../domain/patrol.dart';
import '../domain/patrol_repository.dart';
import '../domain/patrol_records.dart';
import '../domain/patrol_network_status.dart';
import 'patrol_service.dart';

class PatrolSyncService {
  PatrolSyncService({
    required PatrolService patrolService,
    required PatrolSyncRepository syncRepository,
    required this.networkStatus,
  }) : _patrolService = patrolService,
       _syncRepository = syncRepository;

  final PatrolService _patrolService;
  final PatrolSyncRepository _syncRepository;
  final PatrolNetworkStatusProvider networkStatus;
  final Map<String, Future<Patrol>> _inFlight = {};

  Future<PatrolSyncBatchResult> synchronizePending(String rangerId) async {
    final patrols = await _patrolService.listForRanger(rangerId);
    var synchronized = 0;
    final failures = <String>[];
    for (final patrol in patrols.where(
      (item) =>
          item.status == PatrolStatus.completedPendingSync &&
          item.syncInfo.status != PatrolSyncStatus.synced,
    )) {
      try {
        await synchronize(patrol);
        synchronized++;
      } catch (error) {
        failures.add('${patrol.patrolId}: $error');
      }
    }
    return PatrolSyncBatchResult(
      synchronizedCount: synchronized,
      failures: List.unmodifiable(failures),
    );
  }

  Future<Patrol> synchronize(Patrol patrol, {DateTime? now}) {
    if (patrol.status == PatrolStatus.completedSynced ||
        patrol.syncInfo.status == PatrolSyncStatus.synced) {
      return Future.value(patrol);
    }
    if (patrol.status != PatrolStatus.completedPendingSync) {
      return Future.error(
        StateError('Only completed pending patrols can be synchronized.'),
      );
    }
    final key = '${patrol.rangerId}:${patrol.localId}';
    return _inFlight.putIfAbsent(key, () {
      final operation = _synchronize(patrol, now: now);
      return operation.whenComplete(() {
        _inFlight.remove(key);
      });
    });
  }

  Future<Patrol> _synchronize(Patrol patrol, {DateTime? now}) async {
    final attemptedAt = (now ?? DateTime.now()).toUtc();
    Patrol latest = patrol;
    try {
      final savedPatrols = await _patrolService.listForRanger(patrol.rangerId);
      var isPersisted = false;
      for (final saved in savedPatrols) {
        if (saved.localId == patrol.localId) {
          latest = saved;
          isPersisted = true;
          break;
        }
      }
      if (!isPersisted ||
          latest.status != PatrolStatus.completedPendingSync) {
        if (latest.status == PatrolStatus.completedSynced ||
            latest.syncInfo.status == PatrolSyncStatus.synced) {
          return latest;
        }
        throw StateError(
          'The locally saved patrol is unavailable or no longer pending sync.',
        );
      }
      if (!await networkStatus.isOnline) {
        throw StateError(
          'No network connection is available. The completed patrol remains saved locally.',
        );
      }
      latest = await _patrolService.markSyncing(
        rangerId: latest.rangerId,
        localId: latest.localId,
        attemptedAt: attemptedAt,
      );
      await _syncRepository.syncCompletedPatrol(latest);
      return await _patrolService.markCompletedSynced(
        rangerId: latest.rangerId,
        localId: latest.localId,
        syncedAt: (now ?? DateTime.now()).toUtc(),
      );
    } catch (error) {
      try {
        await _patrolService.markSyncFailed(
          rangerId: latest.rangerId,
          localId: latest.localId,
          attemptedAt: attemptedAt,
          error: error.toString(),
        );
      } catch (storageError) {
        Error.throwWithStackTrace(
          StateError(
            'Synchronization failed: $error. '
            'The failure state could not be stored locally: $storageError. '
            'The patrol remains in its last successfully saved local state.',
          ),
          StackTrace.current,
        );
      }
      rethrow;
    }
  }
}

class PatrolSyncBatchResult {
  const PatrolSyncBatchResult({
    required this.synchronizedCount,
    required this.failures,
  });

  final int synchronizedCount;
  final List<String> failures;
}
