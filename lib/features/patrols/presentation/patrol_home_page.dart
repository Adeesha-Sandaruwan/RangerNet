import 'dart:async';

import 'package:flutter/material.dart';

import '../application/patrol_metrics_service.dart';
import '../application/patrol_service.dart';
import '../application/patrol_sync_service.dart';
import '../application/patrol_tracking_service.dart';
import '../domain/patrol.dart';
import '../domain/patrol_network_status.dart';
import '../domain/patrol_records.dart';
import 'patrol_network_status_card.dart';
import 'patrol_session_page.dart';

/// Ranger-facing assigned-patrol list and entry point for conducting a patrol.
/// DIP: receives patrol, tracking, sync, and network service abstractions.
/// The ranger UI uses a green gradient header and semantic status colours.
class PatrolHomePage extends StatefulWidget {
  const PatrolHomePage({
    required this.rangerId,
    required this.rangerName,
    required this.service,
    required this.trackingService,
    required this.syncService,
    required this.networkStatus,
    this.onReportIncident,
    super.key,
  });

  /// Forwarded to the session page to start a linked incident report.
  final Future<void> Function(Patrol patrol)? onReportIncident;

  /// ID used to load this ranger's assigned patrols.
  final String rangerId;

  /// Name shown to the ranger in the patrol interface.
  final String rangerName;

  /// Application boundary for patrol assignment and lifecycle operations.
  final PatrolService service;

  /// Boundary for location acquisition and ongoing patrol tracking.
  final PatrolTrackingService trackingService;

  /// Boundary for retrying synchronization of locally saved patrols.
  final PatrolSyncService syncService;

  /// Supplies current connectivity and online/offline change notifications.
  final PatrolNetworkStatusProvider networkStatus;

  @override
  State<PatrolHomePage> createState() => _PatrolHomePageState();
}

/// Coordinates live assignments, local-first patrol status, and sync feedback.
/// Cancels timers and subscriptions and removes its lifecycle observer on dispose.
class _PatrolHomePageState extends State<PatrolHomePage>
    with WidgetsBindingObserver {
  static const _metrics = PatrolMetricsService();

  List<Patrol> _patrols = const [];

  /// Connectivity listener, cancelled when this page is disposed.
  StreamSubscription<bool>? _connectivitySubscription;

  /// Live assignment listener, cancelled when this page is disposed.
  StreamSubscription<PatrolListResult>? _assignmentSubscription;

  /// Refreshes displayed elapsed time for active patrols; disposed with state.
  Timer? _clock;
  bool _loading = true;
  bool _syncing = false;
  bool _syncRequestedAgain = false;
  bool? _online;
  String? _error;
  String? _assignmentWarning;
  String? _syncMessage;
  bool _syncFailed = false;

  /// Starts assignment, network, and pending-sync observation for the ranger.
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

  /// Cancels timers/subscriptions and removes this page's lifecycle observer.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _assignmentSubscription?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  /// Refreshes assignments and sync state when the app returns to foreground.
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

  /// Runs an elapsed-time timer only while a patrol needs live duration.
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
          onReportIncident: widget.onReportIncident,
        ),
      ),
    );
    await _load();
  }

  /// Retries eligible local patrols and reports their pending/synced status.
  Future<void> _synchronizePending({bool manual = false}) async {
    if (_syncing) {
      _syncRequestedAgain = true;
      return;
    }
    _syncing = true;
    if (mounted) {
      setState(() {
        _syncMessage = null;
        _syncFailed = false;
      });
    }
    try {
      do {
        _syncRequestedAgain = false;
        final result = await widget.syncService.synchronizePending(
          widget.rangerId,
        );
        if (mounted &&
            (result.synchronizedCount > 0 || result.failures.isNotEmpty)) {
          await _load();
        }
        if (mounted) {
          setState(() {
            _syncFailed = result.failures.isNotEmpty;
            _syncMessage = result.failures.isNotEmpty
                ? 'Could not sync ${result.failures.length} patrol(s). '
                      '${result.failures.first}'
                : result.synchronizedCount > 0
                ? 'Synced ${result.synchronizedCount} patrol(s) successfully.'
                : manual
                ? 'No patrols are waiting to sync.'
                : null;
          });
        }
      } while (_syncRequestedAgain &&
          mounted &&
          await widget.networkStatus.isOnline);
    } catch (error) {
      if (mounted) {
        setState(() {
          _syncFailed = true;
          _syncMessage =
              'Patrol sync failed. Local patrol data is retained: $error';
        });
      }
    } finally {
      _syncing = false;
      if (mounted) setState(() {});
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
          tooltip: _syncing ? 'Synchronizing patrols' : 'Synchronize patrols',
          onPressed: _syncing ? null : () => _synchronizePending(manual: true),
          icon: _syncing
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_sync_outlined),
        ),
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF17613F), Color(0xFF2E8B5E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assigned patrols',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 18,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ranger: ${widget.rangerName}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              PatrolNetworkStatusCard(
                online: _online,
                onRefresh: _refreshNetworkStatus,
              ),
              if (_syncMessage != null ||
                  _patrols.any(
                    (patrol) =>
                        patrol.status == PatrolStatus.completedPendingSync,
                  ))
                Card(
                  color: _syncFailed
                      ? const Color(0xFFFFF1D6)
                      : const Color(0xFFEAF2EC),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                _syncing
                                    ? Icons.sync
                                    : _syncFailed
                                    ? Icons.sync_problem
                                    : Icons.cloud_done_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _syncing
                                        ? 'Synchronizing patrols'
                                        : _syncMessage ??
                                              '${_patrols.where((patrol) => patrol.status == PatrolStatus.completedPendingSync).length} patrol(s) waiting to sync',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Patrol records remain saved on this device until sync succeeds.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _syncing
                                  ? null
                                  : () => _synchronizePending(manual: true),
                              icon: _syncing
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sync),
                              label: Text(_syncing ? 'Syncing' : 'Sync now'),
                            ),
                          ),
                        ),
                      ],
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
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: _statusColor(patrol.status), width: 5),
            ),
          ),
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
                        value:
                            '${duration.inHours}h '
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

  /// Maps lifecycle statuses to the page's consistent semantic colours.
  Color _statusColor(PatrolStatus status) => switch (status) {
    PatrolStatus.assigned => const Color(0xFF2F6FDE),
    PatrolStatus.inProgress => const Color(0xFF17613F),
    PatrolStatus.paused => const Color(0xFFC77700),
    PatrolStatus.interrupted => const Color(0xFFB42318),
    PatrolStatus.completedPendingSync => const Color(0xFF7A5AF8),
    PatrolStatus.completedSynced => const Color(0xFF536459),
    PatrolStatus.incomplete => const Color(0xFFC77700),
    PatrolStatus.aborted => const Color(0xFF8A8F8C),
  };

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

/// Displays a compact patrol status label and icon. SRP: presentation only.
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

/// Displays one patrol metric in a list card. SRP: presentation only.
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
