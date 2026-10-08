import 'package:flutter/material.dart';

import '../application/patrol_metrics_service.dart';
import '../application/patrol_service.dart';
import '../application/patrol_sync_service.dart';
import '../domain/patrol.dart';
import '../domain/patrol_records.dart';
import 'manual_waypoint_map_page.dart';
import 'patrol_coverage_summary.dart';
import 'patrol_route_map.dart';

class PatrolCompletionReviewPage extends StatefulWidget {
  const PatrolCompletionReviewPage({
    required this.patrol,
    required this.suggestedEndLocation,
    required this.service,
    required this.syncService,
    super.key,
  });

  final Patrol patrol;
  final PatrolLocation? suggestedEndLocation;
  final PatrolService service;
  final PatrolSyncService syncService;

  @override
  State<PatrolCompletionReviewPage> createState() =>
      _PatrolCompletionReviewPageState();
}

class _PatrolCompletionReviewPageState
    extends State<PatrolCompletionReviewPage> {
  static const _metrics = PatrolMetricsService();
  late Patrol _patrol = widget.patrol;
  late PatrolLocation? _endLocation = widget.suggestedEndLocation;
  bool _busy = false;
  bool _coverageReady = false;
  String? _coverageError;
  String? _message;

  @override
  void initState() {
    super.initState();
    _calculateCoverage();
  }

  bool get _canConfirm =>
      (_patrol.status == PatrolStatus.inProgress ||
          _patrol.status == PatrolStatus.paused) &&
      _endLocation != null &&
      _coverageReady;

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

  Future<void> _confirmCompletion() async {
    if (_busy || !_canConfirm) return;
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
                FilledButton.icon(
                  onPressed:
                      _busy || _patrol.status == PatrolStatus.completedSynced
                      ? null
                      : _synchronize,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                    _patrol.status == PatrolStatus.completedSynced
                        ? 'Completed'
                        : 'Retry synchronization',
                  ),
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
                FilledButton.icon(
                  onPressed: _busy || !_canConfirm ? null : _confirmCompletion,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm completion'),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pop(_patrol),
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

  String _locationLabel(PatrolLocation? location) => location == null
      ? 'Not recorded'
      : '${location.latitude.toStringAsFixed(6)}, '
            '${location.longitude.toStringAsFixed(6)} '
            '(${location.source.name})';

}

class _CoveragePendingMessage extends StatelessWidget {
  const _CoveragePendingMessage();

  @override
  Widget build(BuildContext context) => const Text(
    'Coverage calculation is pending.',
    style: TextStyle(color: Colors.black54),
  );
}
