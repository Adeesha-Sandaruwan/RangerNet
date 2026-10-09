import 'package:connectivity_plus/connectivity_plus.dart';

import '../domain/incident_report.dart';
import 'incident_cloud_repository.dart';
import 'incident_local_store.dart';

/// Offline-first submission of an incident report, reusable outside the
/// Incidents tab (e.g. from an active patrol).
///
/// SRP: only persists a report locally and attempts to publish it.
/// A failed publish keeps the report queued as `syncFailed` so the Incidents
/// tab can retry it later; nothing is lost.
class IncidentSubmissionService {
  IncidentSubmissionService({
    IncidentLocalStore? store,
    IncidentCloudRepository? cloud,
  }) : _store = store ?? IncidentLocalStore(),
       _cloud = cloud ?? IncidentCloudRepository();

  final IncidentLocalStore _store;
  final IncidentCloudRepository _cloud;

  /// Queues the report on this device (Pending Sync).
  Future<void> saveLocally(IncidentReport report) => _store.enqueue(report);

  /// Publishes a queued report; on failure marks it for retry and rethrows.
  Future<void> syncNow(IncidentReport report) async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty ||
          results.every((result) => result == ConnectivityResult.none)) {
        throw StateError(
          'No network is available. The report remains Pending Sync.',
        );
      }
      await _cloud.publish(report).timeout(const Duration(seconds: 25));
      await _store.remove(report.rangerId, report.id);
    } catch (_) {
      await _store.replace(report.copyWith(status: IncidentStatus.syncFailed));
      rethrow;
    }
  }
}
