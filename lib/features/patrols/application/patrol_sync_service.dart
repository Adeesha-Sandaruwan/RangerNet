import 'package:connectivity_plus/connectivity_plus.dart';

import '../domain/patrol.dart';
import '../domain/patrol_repository.dart';
import '../domain/patrol_records.dart';
import 'patrol_service.dart';

class PatrolSyncService {
  PatrolSyncService({
    required PatrolService patrolService,
    required PatrolSyncRepository syncRepository,
    Connectivity? connectivity,
  }) : _patrolService = patrolService,
       _syncRepository = syncRepository,
       _connectivity = connectivity ?? Connectivity();

  final PatrolService _patrolService;
  final PatrolSyncRepository _syncRepository;
  final Connectivity _connectivity;

  Future<PatrolSyncBatchResult> synchronizePending(String rangerId) async {
    final patrols = await _patrolService.listForRanger(rangerId);
    var synchronized = 0;
    final failures = <String>[];
    for (final patrol in patrols.where(
      (item) => item.status == PatrolStatus.completedPendingSync,
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

  Future<Patrol> synchronize(Patrol patrol, {DateTime? now}) async {
    final attemptedAt = (now ?? DateTime.now()).toUtc();
    var latest = patrol;
    try {
      final connection = await _connectivity.checkConnectivity();
      if (connection.isEmpty ||
          connection.every((item) => item == ConnectivityResult.none)) {
        throw StateError(
          'No network connection is available. The completed patrol remains saved locally.',
        );
      }
      latest = await _patrolService.markSyncing(
        rangerId: patrol.rangerId,
        localId: patrol.localId,
        attemptedAt: attemptedAt,
      );
      await _syncRepository.syncCompletedPatrol(latest);
      return await _patrolService.markCompletedSynced(
        rangerId: patrol.rangerId,
        localId: patrol.localId,
        syncedAt: (now ?? DateTime.now()).toUtc(),
      );
    } catch (error) {
      await _patrolService.markSyncFailed(
        rangerId: patrol.rangerId,
        localId: patrol.localId,
        attemptedAt: attemptedAt,
        error: error.toString(),
      );
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
