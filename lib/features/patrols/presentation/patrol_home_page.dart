import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../application/patrol_service.dart';
import '../application/patrol_sync_service.dart';
import '../application/patrol_tracking_service.dart';
import '../domain/patrol.dart';
import '../domain/patrol_records.dart';
import 'patrol_session_page.dart';

class PatrolHomePage extends StatefulWidget {
  const PatrolHomePage({
    required this.rangerId,
    required this.rangerName,
    required this.service,
    required this.trackingService,
    required this.syncService,
    super.key,
  });

  final String rangerId;
  final String rangerName;
  final PatrolService service;
  final PatrolTrackingService trackingService;
  final PatrolSyncService syncService;

  @override
  State<PatrolHomePage> createState() => _PatrolHomePageState();
}

class _PatrolHomePageState extends State<PatrolHomePage> {
  List<Patrol> _patrols = const [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  String? _assignmentWarning;

  @override
  void initState() {
    super.initState();
    _load();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(_synchronizePending());
      }
    });
    unawaited(_synchronizePending());
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
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
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
      if (mounted && result.synchronizedCount > 0) await _load();
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
              if (_assignmentWarning != null)
                Card(
                  color: const Color(0xFFFFF1D6),
                  child: ListTile(
                    leading: const Icon(Icons.cloud_off_outlined),
                    title: const Text('Showing patrols saved on this device'),
                    subtitle: Text(
                      'Could not refresh assignments: $_assignmentWarning',
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

  Widget _patrolCard(Patrol patrol) => Card(
    child: ListTile(
      onTap: () => _open(patrol),
      leading: Icon(
        patrol.status == PatrolStatus.assigned
            ? Icons.assignment_outlined
            : Icons.route,
        color: const Color(0xFF17613F),
      ),
      title: Text(
        patrol.area.routeName.isEmpty
            ? 'Patrol ${patrol.patrolId}'
            : patrol.area.routeName,
      ),
      subtitle: Text(
        '${patrol.area.parkName} · ${patrol.area.zoneName}\n'
        '${_statusLabel(patrol.status)} · ${_syncLabel(patrol)}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
    ),
  );

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
    PatrolSyncStatus.syncing => 'Synchronizing',
    PatrolSyncStatus.synced => 'Synchronized',
    PatrolSyncStatus.failed => 'Synchronization needs retry',
  };
}
