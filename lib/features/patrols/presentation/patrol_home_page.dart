import 'dart:async';

import 'package:flutter/material.dart';

import '../application/patrol_metrics_service.dart';
import '../application/patrol_service.dart';
import '../application/patrol_sync_service.dart';
import '../application/patrol_tracking_service.dart';
import '../domain/patrol.dart';
import '../domain/patrol_network_status.dart';
import '../domain/patrol_records.dart';
import 'patrol_session_page.dart';

class PatrolHomePage extends StatefulWidget {
  const PatrolHomePage({
    required this.rangerId,
    required this.rangerName,
    required this.service,
    required this.trackingService,
    required this.syncService,
    required this.networkStatus,
    super.key,
  });

  final String rangerId;
  final String rangerName;
  final PatrolService service;
  final PatrolTrackingService trackingService;
  final PatrolSyncService syncService;
  final PatrolNetworkStatusProvider networkStatus;

  @override
  State<PatrolHomePage> createState() => _PatrolHomePageState();
}

class _PatrolHomePageState extends State<PatrolHomePage>
    with WidgetsBindingObserver {
  static const _metrics = PatrolMetricsService();

  List<Patrol> _patrols = const [];
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<PatrolListResult>? _assignmentSubscription;
  Timer? _clock;
  bool _loading = true;
  bool _syncing = false;
  bool? _online;
  String? _error;
  String? _assignmentWarning;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _assignmentSubscription = widget.service
        .watchAssignedPatrols(widget.rangerId)
        .listen(
          (result) {
            if (!mounted) return;
            setState(() {
              _patrols = result.patrols;
              _assignmentWarning = result.assignmentError?.toString();
              _loading = false;
            });
            _updateClock();
          },
          onError: (Object error) {
            if (mounted) {
              setState(() {
                _assignmentWarning =
                    'Live assignment updates are unavailable: $error';
              });
            }
          },
        );
    unawaited(_refreshNetworkStatus());
    _connectivitySubscription = widget.networkStatus.onlineChanges.listen((
      online,
    ) {
      if (mounted) setState(() => _online = online);
      if (online) {
        unawaited(_load());
        unawaited(_synchronizePending());
      }
    });
    unawaited(_synchronizePending());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _assignmentSubscription?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
      unawaited(_synchronizePending());
      unawaited(_refreshNetworkStatus());
    }
  }

  Future<void> _refreshNetworkStatus() async {
    try {
      final online = await widget.networkStatus.isOnline;
      if (mounted) setState(() => _online = online);
    } catch (error) {
      if (mounted) {
        setState(
          () => _assignmentWarning = 'Network status unavailable: $error',
        );
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _assignmentWarning = null;
    });
    try {
      final result = await widget.service.loadAssignedPatrols(widget.rangerId);
      if (mounted) {
        setState(() {
          _patrols = result.patrols;
          _assignmentWarning = result.assignmentError?.toString();
        });
        _updateClock();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updateClock() {
    final hasActivePatrol = _patrols.any(
      (patrol) =>
          patrol.status == PatrolStatus.inProgress ||
          patrol.status == PatrolStatus.paused ||
          patrol.status == PatrolStatus.interrupted,
    );
    if (hasActivePatrol) {
      _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _clock?.cancel();
      _clock = null;
    }
  }

  Future<void> _open(Patrol patrol) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PatrolSessionPage(
          patrol: patrol,
          service: widget.service,
          trackingService: widget.trackingService,
          syncService: widget.syncService,
          networkStatus: widget.networkStatus,
        ),
      ),
    );
    await _load();
  }

  Future<void> _synchronizePending() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final result = await widget.syncService.synchronizePending(
        widget.rangerId,
      );
      if (mounted &&
          (result.synchronizedCount > 0 || result.failures.isNotEmpty)) {
        await _load();
      }
      if (mounted && result.failures.isNotEmpty) {
        setState(
          () => _assignmentWarning =
              'Patrol sync needs retry: ${result.failures.first}',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _assignmentWarning = 'Patrol sync failed: $error');
      }
    } finally {
      _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F8F3),
    appBar: AppBar(
      title: const Text('Ranger patrols'),
      backgroundColor: const Color(0xFFF5F8F3),
      actions: [
        IconButton(
          tooltip: 'Refresh assigned patrols',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Assigned patrols',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text('Ranger: ${widget.rangerName}'),
              Card(
                child: ListTile(
                  dense: true,
                  leading: Icon(_online == true ? Icons.wifi : Icons.wifi_off),
                  title: Text(
                    _online == null
                        ? 'Checking network status'
                        : _online!
                        ? 'Online'
                        : 'Offline · local patrol data remains available',
                  ),
                  trailing: IconButton(
                    tooltip: 'Refresh network status',
                    onPressed: _refreshNetworkStatus,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ),
              if (_assignmentWarning != null)
                Card(
                  color: const Color(0xFFFFF1D6),
                  child: ListTile(
                    leading: const Icon(Icons.cloud_off_outlined),
                    title: const Text(
                      'Patrol assignment update needs attention',
                    ),
                    subtitle: Text(_assignmentWarning!),
                    trailing: IconButton(
                      tooltip: 'Retry assignment refresh',
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
              if (_error != null)
                Card(
                  color: const Color(0xFFFFE9E5),
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('Patrols could not be loaded'),
                    subtitle: Text(_error!),
                  ),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_patrols.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.route_outlined),
                    title: Text('No assigned patrols'),
                    subtitle: Text(
                      'Assigned patrols will appear here when they are made '
                      'available to your ranger account.',
                    ),
                  ),
                )
              else
                ..._patrols.map(_patrolCard),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _patrolCard(Patrol patrol) {
    final routeName = patrol.area.routeName.isEmpty
        ? 'Patrol ${patrol.patrolId}'
        : patrol.area.routeName;
    final duration = _metrics.durationAt(patrol, DateTime.now());
    final distance = _metrics.distanceTravelledMeters(patrol);
    final hasStarted = patrol.startedAt != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(patrol),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFEAF2EC),
                    child: Icon(Icons.route, color: Color(0xFF17613F)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routeName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${patrol.area.parkName} · ${patrol.area.zoneName}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    label: _statusLabel(patrol.status),
                    icon: patrol.status == PatrolStatus.assigned
                        ? Icons.assignment_outlined
                        : Icons.route_outlined,
                  ),
                  _StatusChip(
                    label: _syncLabel(patrol),
                    icon: patrol.syncInfo.status == PatrolSyncStatus.synced
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_outlined,
                  ),
                ],
              ),
              if (patrol.plannedRoute case final route?) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      size: 18,
                      color: Color(0xFF17613F),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${route.start.name} → ${route.end.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '${route.stops.length} optional stop${route.stops.length == 1 ? '' : 's'} · '
                            '${route.coverageSections.length} coverage sections',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              if (hasStarted) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _PatrolCardMetric(
                        label: 'Actual route distance',
                        value: distance >= 1000
                            ? '${(distance / 1000).toStringAsFixed(2)} km'
                            : '${distance.toStringAsFixed(0)} m',
                      ),
                    ),
                    Expanded(
                      child: _PatrolCardMetric(
                        label: 'Active duration',
                        value: '${duration.inHours}h '
                            '${duration.inMinutes.remainder(60)}m',
                      ),
                    ),
                    Expanded(
                      child: _PatrolCardMetric(
                        label: 'GPS points',
                        value: '${patrol.routePoints.length}',
                      ),
                    ),
                  ],
                ),
                if (patrol.manualWaypoints.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${patrol.manualWaypoints.length} map-marked location(s) '
                    'included in the route distance',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
              const SizedBox(height: 10),
              Text(
                'Last successful sync: '
                '${patrol.syncInfo.lastSyncedAt == null ? 'Never' : patrol.syncInfo.lastSyncedAt!.toLocal().toString().substring(0, 16)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (patrol.syncInfo.lastError != null)
                Text(
                  patrol.syncInfo.lastError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFB42318),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(PatrolStatus status) => switch (status) {
    PatrolStatus.assigned => 'Assigned',
    PatrolStatus.inProgress => 'In progress',
    PatrolStatus.paused => 'Paused',
    PatrolStatus.completedPendingSync => 'Completed · pending sync',
    PatrolStatus.completedSynced => 'Completed',
    PatrolStatus.incomplete => 'Incomplete',
    PatrolStatus.aborted => 'Ended early',
    PatrolStatus.interrupted => 'Interrupted',
  };

  String _syncLabel(Patrol patrol) => switch (patrol.syncInfo.status) {
    PatrolSyncStatus.localOnly => 'Saved on device',
    PatrolSyncStatus.pendingSync => 'Pending synchronization',
    PatrolSyncStatus.syncing => 'Pending Sync · retry after interruption',
    PatrolSyncStatus.synced => 'Synchronized',
    PatrolSyncStatus.failed => 'Synchronization needs retry',
  };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 16),
    label: Text(label),
    visualDensity: VisualDensity.compact,
  );
}

class _PatrolCardMetric extends StatelessWidget {
  const _PatrolCardMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 3),
      Text(value, style: Theme.of(context).textTheme.titleSmall),
    ],
  );
}
