import 'dart:async';

import 'package:flutter/material.dart';

import '../application/patrol_metrics_service.dart';
import '../application/patrol_service.dart';
import '../application/patrol_sync_service.dart';
import '../domain/patrol.dart';
import '../domain/patrol_location_provider.dart';
import '../domain/patrol_network_status.dart';
import '../domain/patrol_records.dart';
import 'manual_waypoint_map_page.dart';
import 'patrol_coverage_summary.dart';
import 'patrol_network_status_card.dart';
import 'patrol_primary_action_button.dart';
import 'patrol_route_map.dart';

/// Lets a ranger confirm a patrol end location and review coverage before
/// completion. DIP: uses injected patrol, sync, and network abstractions.
class PatrolCompletionReviewPage extends StatefulWidget {
  const PatrolCompletionReviewPage({
    required this.patrol,
    required this.suggestedEndLocation,
    required this.gpsStatus,
    required this.service,
    required this.syncService,
    required this.networkStatus,
    super.key,
  });

  /// Current patrol awaiting completion confirmation.
  final Patrol patrol;

  /// Best available end location offered for ranger confirmation.
  final PatrolLocation? suggestedEndLocation;

  /// GPS state shown to the ranger during completion review.
  final PatrolGpsStatus gpsStatus;

  /// Application boundary for coverage calculation and completion.
  final PatrolService service;

  /// Boundary for synchronization after local completion.
  final PatrolSyncService syncService;

  /// Supplies current and changing connectivity status.
  final PatrolNetworkStatusProvider networkStatus;

  @override
  State<PatrolCompletionReviewPage> createState() =>
      _PatrolCompletionReviewPageState();
}

/// Calculates coverage and coordinates completion/sync feedback; cancels the
/// network subscription when the review page is disposed.
class _PatrolCompletionReviewPageState
    extends State<PatrolCompletionReviewPage> {
  static const _metrics = PatrolMetricsService();
  late Patrol _patrol = widget.patrol;
  late PatrolLocation? _endLocation = widget.suggestedEndLocation;
  bool _busy = false;
  bool _coverageReady = false;
  String? _coverageError;
  String? _message;
  bool? _online;

  /// Connectivity listener, cancelled when the page is disposed.
  StreamSubscription<bool>? _networkSubscription;

  /// Subscribes to connectivity and calculates route coverage for review.
  @override
  void initState() {
    super.initState();
    _networkSubscription = widget.networkStatus.onlineChanges.listen((online) {
      if (mounted) setState(() => _online = online);
    });
    unawaited(_refreshNetworkStatus());
    _calculateCoverage();
  }

  /// Cancels the connectivity listener owned by this page.
  @override
  void dispose() {
    _networkSubscription?.cancel();
    super.dispose();
  }

  bool get _canConfirm =>
      (_patrol.status == PatrolStatus.inProgress ||
          _patrol.status == PatrolStatus.paused) &&
      _endLocation != null &&
      _coverageReady;

  /// Requests route coverage for the current patrol and selected end location.
  Future<void> _calculateCoverage() async {
    if (!mounted) return;
    setState(() {
      _coverageReady = false;
      _coverageError = null;
    });
    try {
      _patrol = await widget.service.calculateCoverage(
        rangerId: _patrol.rangerId,
        localId: _patrol.localId,
        additionalLocation: _endLocation,
      );
      if (mounted) setState(() => _coverageReady = true);
    } catch (error) {
      if (mounted) setState(() => _coverageError = error.toString());
    }
  }

  /// Confirms completion and saves locally before attempting synchronization.
  Future<void> _confirmCompletion() async {
    if (_busy || !_canConfirm) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete this patrol?'),
        content: Text(
          _online == false
              ? 'The summary will be saved on this device as Pending Sync. '
                    'You can synchronize it when the network is available.'
              : 'The patrol summary will be saved locally before synchronization. '
                    'You can review the saved status afterward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Return to summary'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete patrol'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      _patrol = await widget.service.complete(
        rangerId: _patrol.rangerId,
        localId: _patrol.localId,
        endLocation: _endLocation!,
        at: DateTime.now().toUtc(),
      );
      if (mounted) setState(() {});
      await _synchronize();
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Completion was not saved: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshNetworkStatus() async {
    try {
      final online = await widget.networkStatus.isOnline;
      if (mounted) setState(() => _online = online);
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = 'Network status could not be checked: $error',
        );
      }
    }
  }

  /// Attempts synchronization while preserving the locally saved sync status.
  Future<void> _synchronize() async {
    if (mounted) setState(() => _busy = true);
    try {
      _patrol = await widget.syncService.synchronize(_patrol);
      if (mounted) {
        setState(() => _message = 'Patrol completion synchronized.');
      }
    } catch (error) {
      var message =
          'Synchronization failed after completion was saved locally: $error';
      try {
        final saved = await widget.service.listForRanger(_patrol.rangerId);
        for (final patrol in saved) {
          if (patrol.localId == _patrol.localId) _patrol = patrol;
        }
      } catch (storageError) {
        message += ' Could not reload local sync status: $storageError';
      }
      if (mounted) {
        setState(() => _message = message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Lets the ranger replace the suggested end point with a manual map point.
  Future<void> _chooseEndLocation() async {
    final location = await Navigator.of(context).push<PatrolLocation>(
      MaterialPageRoute<PatrolLocation>(
        builder: (_) => ManualWaypointMapPage(
          patrol: _patrol,
          initialLocation:
              _endLocation ??
              (_patrol.routePoints.isEmpty
                  ? _patrol.startLocation
                  : _patrol.routePoints.last.location),
        ),
      ),
    );
    if (location != null && mounted) {
      setState(() => _endLocation = location);
      await _calculateCoverage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = _metrics.durationAt(_patrol, DateTime.now());
    final distance = _metrics.distanceTravelledMeters(_patrol);
    return Scaffold(
      appBar: AppBar(title: const Text('Review patrol summary')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PatrolNetworkStatusCard(
                online: _online,
                onRefresh: _refreshNetworkStatus,
              ),
              Card(
                child: ListTile(
                  leading: Icon(
                    widget.gpsStatus.state == PatrolGpsState.available
                        ? Icons.gps_fixed
                        : Icons.gps_not_fixed,
                  ),
                  title: Text(
                    'GPS status: ${_gpsStatusLabel(widget.gpsStatus)}',
                  ),
                  subtitle: Text(
                    widget.gpsStatus.accuracyMeters == null
                        ? widget.gpsStatus.message ??
                              'GPS accuracy is not currently available.'
                        : 'Accuracy ±${widget.gpsStatus.accuracyMeters!.toStringAsFixed(1)} m',
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_patrol.plannedRoute != null) ...[
                        PatrolRouteMap(patrol: _patrol, height: 280),
                        const SizedBox(height: 8),
                        const Text(
                          'Green: assigned route · Blue: recorded GPS track · '
                          'S: start · E: destination',
                        ),
                        const SizedBox(height: 14),
                      ],
                      Text(
                        _patrol.area.routeName.isEmpty
                            ? 'Patrol ${_patrol.patrolId}'
                            : _patrol.area.routeName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      _detail('Park', _patrol.area.parkName),
                      _detail('Zone', _patrol.area.zoneName),
                      _detail('Ranger', _patrol.rangerName),
                      _detail('Patrol ID', _patrol.patrolId),
                      _detail('Sync status', _syncStatusLabel),
                      _detail(
                        'Last successful sync',
                        _patrol.syncInfo.lastSyncedAt == null
                            ? 'Never'
                            : _formatDate(_patrol.syncInfo.lastSyncedAt),
                      ),
                      if (_patrol.syncInfo.lastError != null)
                        _detail(
                          'Last sync failure',
                          _patrol.syncInfo.lastError!,
                        ),
                      _detail('Started', _formatDate(_patrol.startedAt)),
                      _detail(
                        'Duration',
                        '${duration.inHours}h ${duration.inMinutes.remainder(60)}m',
                      ),
                      _detail(
                        'Distance travelled',
                        '${(distance / 1000).toStringAsFixed(2)} km',
                      ),
                      _detail(
                        'GPS route points',
                        '${_patrol.routePoints.length}',
                      ),
                      _detail(
                        'Manual waypoints',
                        '${_patrol.manualWaypoints.length}',
                      ),
                      _detail('Observations', '${_patrol.observations.length}'),
                      _detail('Photographs', '${_patrol.photographs.length}'),
                      _detail(
                        'Pause / resume events',
                        '${_patrol.pauseResumeEvents.length}',
                      ),
                      _detail(
                        'Start location',
                        _locationLabel(_patrol.startLocation),
                      ),
                      _detail('End location', _locationLabel(_endLocation)),
                      if (_patrol.plannedCoverageSections.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        if (_patrol.coverage case final coverage?)
                          PatrolCoverageSummary(coverage: coverage)
                        else
                          const _CoveragePendingMessage(),
                      ] else
                        _detail(
                          'Actual patrol coverage',
                          'No assigned coverage sections',
                        ),
                      if (_patrol.manualWaypoints.isNotEmpty)
                        _recordList(
                          'Manual waypoint details',
                          _patrol.manualWaypoints
                              .map(
                                (item) =>
                                    '${item.description} · ${_locationLabel(item.location)}',
                              )
                              .toList(),
                        ),
                      if (_patrol.observations.isNotEmpty)
                        _recordList(
                          'Observation details',
                          _patrol.observations
                              .map(
                                (item) =>
                                    '${item.category == null ? '' : '${item.category}: '}${item.description}',
                              )
                              .toList(),
                        ),
                      if (_patrol.photographs.isNotEmpty)
                        _recordList(
                          'Photographs',
                          _patrol.photographs
                              .map((item) => item.fileName)
                              .toList(),
                        ),
                      if (_patrol.pauseResumeEvents.isNotEmpty)
                        _recordList(
                          'Pause / resume history',
                          _patrol.pauseResumeEvents
                              .map(
                                (item) =>
                                    '${item.action.name} · ${_formatDate(item.occurredAt)}${item.reason == null ? '' : ' · ${item.reason}'}',
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ),
              if (_message != null)
                Card(
                  color: _patrol.status == PatrolStatus.completedSynced
                      ? const Color(0xFFE6F2E9)
                      : const Color(0xFFFFF1D6),
                  child: ListTile(
                    leading: Icon(
                      _patrol.status == PatrolStatus.completedSynced
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                    ),
                    title: Text(_message!),
                    subtitle: _patrol.syncInfo.lastError == null
                        ? null
                        : Text(
                            'Last sync error: ${_patrol.syncInfo.lastError}',
                          ),
                  ),
                ),
              if (_coverageError != null)
                Card(
                  color: const Color(0xFFFFE9E5),
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('Coverage could not be calculated'),
                    subtitle: Text(_coverageError!),
                    trailing: IconButton(
                      tooltip: 'Retry coverage calculation',
                      onPressed: _busy ? null : _calculateCoverage,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
              if (!_coverageReady && _coverageError == null)
                const LinearProgressIndicator(),
              if (_patrol.status == PatrolStatus.completedPendingSync ||
                  _patrol.status == PatrolStatus.completedSynced)
                PatrolPrimaryActionButton(
                  label: _patrol.status == PatrolStatus.completedSynced
                      ? 'Completed'
                      : 'Retry synchronization',
                  icon: Icons.sync,
                  onPressed:
                      _busy || _patrol.status == PatrolStatus.completedSynced
                      ? null
                      : _synchronize,
                  busy: _busy,
                )
              else ...[
                OutlinedButton.icon(
                  onPressed: _busy ? null : _chooseEndLocation,
                  icon: Icon(
                    _endLocation?.source == PatrolLocationSource.manual
                        ? Icons.add_location_alt_outlined
                        : Icons.my_location_outlined,
                  ),
                  label: Text(
                    _endLocation == null
                        ? 'Choose end location on map'
                        : 'Change end location (${_endLocation!.source.name})',
                  ),
                ),
                PatrolPrimaryActionButton(
                  label: 'Confirm completion',
                  icon: Icons.check_circle_outline,
                  onPressed: _busy || !_canConfirm ? null : _confirmCompletion,
                  busy: _busy,
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pop(_patrol),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Return to patrol'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );

  Widget _recordList(String title, List<String> values) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...values.map(
            (value) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('• $value'),
            ),
          ),
        ],
      ),
    ),
  );

  String _formatDate(DateTime? date) => date == null
      ? 'Not recorded'
      : date.toLocal().toString().substring(0, 16);

  String get _syncStatusLabel => switch (_patrol.syncInfo.status) {
    PatrolSyncStatus.localOnly => 'Saved on this device',
    PatrolSyncStatus.pendingSync => 'Pending Sync',
    PatrolSyncStatus.syncing => 'Synchronization in progress',
    PatrolSyncStatus.synced => 'Synced',
    PatrolSyncStatus.failed => 'Pending Sync · last attempt failed',
  };

  String _gpsStatusLabel(PatrolGpsStatus status) => switch (status.state) {
    PatrolGpsState.acquiring => 'Searching for a position',
    PatrolGpsState.available => 'Available',
    PatrolGpsState.inaccurate => 'Inaccurate',
    PatrolGpsState.disabled => 'Device location is off',
    PatrolGpsState.permissionDenied => 'Permission unavailable',
    PatrolGpsState.unavailable => 'Unavailable',
  };

  String _locationLabel(PatrolLocation? location) => location == null
      ? 'Not recorded'
      : '${location.latitude.toStringAsFixed(6)}, '
            '${location.longitude.toStringAsFixed(6)} '
            '(${location.source == PatrolLocationSource.gps ? 'GPS' : 'Manual'})';
}

/// Explains why coverage is still being calculated or cannot be shown.
class _CoveragePendingMessage extends StatelessWidget {
  const _CoveragePendingMessage();

  @override
  Widget build(BuildContext context) => const Text(
    'Coverage calculation is pending.',
    style: TextStyle(color: Colors.black54),
  );
}
