import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../application/patrol_service.dart';
import '../application/patrol_sync_service.dart';
import '../application/patrol_tracking_service.dart';
import '../data/patrol_photo_picker.dart';
import '../data/geolocator_patrol_location_provider.dart';
import '../domain/patrol.dart';
import '../domain/patrol_location_provider.dart';
import '../domain/patrol_network_status.dart';
import '../domain/patrol_records.dart';
import 'manual_waypoint_map_page.dart';
import 'patrol_completion_review_page.dart';

class PatrolSessionPage extends StatefulWidget {
  const PatrolSessionPage({
    required this.patrol,
    required this.service,
    required this.trackingService,
    required this.syncService,
    required this.networkStatus,
    super.key,
  });

  final Patrol patrol;
  final PatrolService service;
  final PatrolTrackingService trackingService;
  final PatrolSyncService syncService;
  final PatrolNetworkStatusProvider networkStatus;

  @override
  State<PatrolSessionPage> createState() => _PatrolSessionPageState();
}

class _PatrolSessionPageState extends State<PatrolSessionPage>
    with WidgetsBindingObserver {
  static const _uuid = Uuid();
  static const _maxGpsAccuracyMeters = 50.0;

  late Patrol _patrol = widget.patrol;
  PatrolTrackingState _trackingState = const PatrolTrackingState(
    gpsStatus: PatrolGpsStatus(state: PatrolGpsState.acquiring),
  );
  StreamSubscription<PatrolTrackingState>? _trackingSubscription;
  StreamSubscription<bool>? _networkSubscription;
  Timer? _clock;
  bool _busy = false;
  bool _reviewingCompletion = false;
  bool? _online;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _trackingState = widget.trackingService.currentState;
    _trackingSubscription = widget.trackingService.states.listen((state) {
      if (mounted) setState(() => _trackingState = state);
    });
    _networkSubscription = widget.networkStatus.onlineChanges.listen((online) {
      if (mounted) setState(() => _online = online);
      if (online &&
          _patrol.status == PatrolStatus.completedPendingSync &&
          !_busy) {
        unawaited(_retryPendingSync());
      }
    });
    unawaited(_refreshNetworkStatus());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _patrol.startedAt != null && _isActive) setState(() {});
    });
    if (_patrol.status == PatrolStatus.inProgress) {
      unawaited(_restartTracking());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trackingSubscription?.cancel();
    _networkSubscription?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_reviewingCompletion &&
        _patrol.status == PatrolStatus.inProgress) {
      unawaited(_restartTracking());
    }
  }

  bool get _isActive =>
      _patrol.status == PatrolStatus.inProgress ||
      _patrol.status == PatrolStatus.paused ||
      _patrol.status == PatrolStatus.interrupted;

  Future<void> _restartTracking() async {
    await widget.trackingService.start(_patrol);
    if (mounted) {
      setState(() => _trackingState = widget.trackingService.currentState);
    }
  }

  Future<void> _retryGps() async {
    if (_patrol.status != PatrolStatus.inProgress || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.trackingService.start(_patrol);
      if (mounted) {
        setState(() => _trackingState = widget.trackingService.currentState);
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'GPS retry failed: $error');
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
        setState(() => _error = 'Network status unavailable: $error');
      }
    }
  }

  Future<void> _retryPendingSync() async {
    if (_busy || _patrol.status != PatrolStatus.completedPendingSync) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _patrol = await widget.syncService.synchronize(_patrol);
      if (mounted) setState(() {});
    } catch (error) {
      var message =
          'Synchronization failed. The patrol remains in its last saved local state: $error';
      try {
        final saved = await widget.service.listForRanger(_patrol.rangerId);
        for (final patrol in saved) {
          if (patrol.localId == _patrol.localId) _patrol = patrol;
        }
        message =
            'Synchronization failed. The locally saved patrol remains pending: $error';
      } catch (storageError) {
        message += ' Could not reload local sync status: $storageError';
      }
      if (mounted) {
        setState(() => _error = message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startPatrol() async {
    if (_busy || _patrol.status != PatrolStatus.assigned) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      PatrolLocation location;
      try {
        location = await widget.trackingService.currentLocation();
        if (location.accuracyMeters != null &&
            location.accuracyMeters! > _maxGpsAccuracyMeters) {
          throw const PatrolLocationException(
            'GPS accuracy is too low to start at a reliable location.',
          );
        }
      } catch (error) {
        if (!mounted) return;
        final useManual = await _confirmManualStart(error.toString());
        if (useManual != true || !mounted) return;
        final manualLocation = await _selectManualLocation();
        if (manualLocation == null) return;
        location = manualLocation;
      }
      _patrol = await widget.service.start(
        rangerId: _patrol.rangerId,
        localId: _patrol.localId,
        location: location,
        at: DateTime.now().toUtc(),
      );
      if (mounted) setState(() {});
      try {
        await widget.trackingService.start(_patrol);
        if (mounted) {
          setState(() => _trackingState = widget.trackingService.currentState);
        }
      } catch (error) {
        if (mounted) {
          setState(
            () => _error =
                'Patrol started and saved locally, but GPS tracking could not start: $error',
          );
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Patrol could not be started: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmManualStart(String reason) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('GPS unavailable'),
      content: Text(
        '$reason\n\nYou can start using a manually selected map location. '
        'GPS route tracking will remain unconfirmed until a reliable fix arrives.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Choose start location'),
        ),
      ],
    ),
  );

  Future<void> _pause() async {
    await _runAction('Could not pause patrol', () async {
      await widget.trackingService.stop();
      _patrol = await widget.service.pause(
        rangerId: _patrol.rangerId,
        localId: _patrol.localId,
        at: DateTime.now().toUtc(),
      );
    });
  }

  Future<void> _resume() async {
    await _runAction('Could not resume patrol', () async {
      _patrol = await widget.service.resume(
        rangerId: _patrol.rangerId,
        localId: _patrol.localId,
        at: DateTime.now().toUtc(),
      );
      await widget.trackingService.start(_patrol);
      _trackingState = widget.trackingService.currentState;
    });
  }

  Future<void> _interrupt() async {
    final reason = await _reasonDialog(
      title: 'Interrupt patrol',
      prompt: 'Describe the critical incident or urgent interruption.',
    );
    if (reason == null) return;
    await _runAction('Patrol interruption was not saved', () async {
      await widget.trackingService.stop();
      _patrol = await widget.service.interrupt(
        rangerId: _patrol.rangerId,
        localId: _patrol.localId,
        reason: reason,
        at: DateTime.now().toUtc(),
      );
    });
  }

  Future<void> _endEarly() async {
    final reason = await _reasonDialog(
      title: 'End patrol early',
      prompt: 'Record why the patrol is ending before completion.',
    );
    if (reason == null) return;
    await _runAction('Patrol termination was not saved', () async {
      await widget.trackingService.stop();
      _patrol = await widget.service.abort(
        rangerId: _patrol.rangerId,
        localId: _patrol.localId,
        reason: reason,
        at: DateTime.now().toUtc(),
        endLocation: _reliableLatestFix,
      );
    });
  }

  Future<void> _addWaypoint() async {
    final location = await _selectManualLocation();
    if (location == null || !mounted) return;
    final description = await _textDialog(
      title: 'Describe waypoint',
      label: 'Waypoint description',
    );
    if (description == null || !mounted) return;
    await _runAction('Waypoint was not saved', () async {
      _patrol = await widget.service.addManualWaypoint(
        rangerId: _patrol.rangerId,
        localId: _patrol.localId,
        waypoint: PatrolWaypoint(
          id: _uuid.v4(),
          description: description,
          location: location,
        ),
      );
    });
  }

  Future<void> _addObservation() async {
    final description = await _textDialog(
      title: 'Add patrol observation',
      label: 'Observation details',
      maxLines: 4,
    );
    if (description == null || !mounted) return;
    var location = _reliableLatestFix;
    if (location == null) {
      location = await _selectManualLocation();
      if (location == null || !mounted) return;
    }
    await _runAction('Observation was not saved', () async {
      _patrol = await widget.service.addObservation(
        rangerId: _patrol.rangerId,
        localId: _patrol.localId,
        observation: PatrolObservation(
          id: _uuid.v4(),
          description: description,
          location: location!,
        ),
      );
    });
  }

  Future<void> _addPhoto(PatrolPhotoSource source) async {
    if (_patrol.photographs.length >= PatrolPhotoPicker.maxPhotos) {
      setState(() => _error = 'Up to three compressed photos can be attached.');
      return;
    }
    await _runAction('Photograph was not saved', () async {
      final photo = await PatrolPhotoPicker().pick(source);
      if (photo == null) return;
      _patrol = await widget.service.addPhotograph(
        rangerId: _patrol.rangerId,
        localId: _patrol.localId,
        photograph: photo,
      );
    });
  }

  Future<void> _reviewCompletion() async {
    if (_busy ||
        (_patrol.status != PatrolStatus.inProgress &&
            _patrol.status != PatrolStatus.paused)) {
      return;
    }
    if (_patrol.status == PatrolStatus.inProgress) {
      await widget.trackingService.stop();
    }
    if (!mounted) return;
    _reviewingCompletion = true;
    try {
      final result = await Navigator.of(context).push<Patrol>(
        MaterialPageRoute<Patrol>(
          builder: (_) => PatrolCompletionReviewPage(
            patrol: _patrol,
            suggestedEndLocation: _reliableLatestFix,
            service: widget.service,
            syncService: widget.syncService,
          ),
        ),
      );
      if (result != null && mounted) {
        setState(() => _patrol = result);
      } else if (mounted && _patrol.status == PatrolStatus.inProgress) {
        await _restartTracking();
      }
    } finally {
      _reviewingCompletion = false;
    }
  }

  Future<PatrolLocation?> _selectManualLocation() =>
      Navigator.of(context).push<PatrolLocation>(
        MaterialPageRoute<PatrolLocation>(
          builder: (_) => ManualWaypointMapPage(
            patrol: _patrol,
            initialLocation: _trackingState.latestFix ?? _patrol.startLocation,
          ),
        ),
      );

  Future<String?> _reasonDialog({
    required String title,
    required String prompt,
  }) => _textDialog(title: title, label: prompt, maxLines: 4);

  Future<String?> _textDialog({
    required String title,
    required String label,
    int maxLines = 2,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: maxLines,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> _runAction(
    String failureMessage,
    Future<void> Function() action,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await widget.trackingService.refreshPatrol(_patrol);
      if (mounted) {
        setState(() => _trackingState = widget.trackingService.currentState);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$failureMessage: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  PatrolLocation? get _reliableLatestFix {
    final fix = _trackingState.latestFix;
    if (_trackingState.gpsStatus.state != PatrolGpsState.available ||
        (fix?.accuracyMeters != null &&
            fix!.accuracyMeters! > _maxGpsAccuracyMeters)) {
      return null;
    }
    return fix;
  }

  @override
  Widget build(BuildContext context) {
    final active = _isActive;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F3),
      appBar: AppBar(title: const Text('Patrol details')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _patrolDetailsCard(),
              if (active) _statusCard(),
              if (_error != null)
                Card(
                  color: const Color(0xFFFFE9E5),
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('Action needs attention'),
                    subtitle: Text(_error!),
                  ),
                ),
              if (_patrol.syncInfo.status == PatrolSyncStatus.failed)
                Card(
                  color: const Color(0xFFFFF1D6),
                  child: ListTile(
                    leading: const Icon(Icons.sync_problem),
                    title: const Text('Patrol is saved locally'),
                    subtitle: Text(
                      _patrol.syncInfo.lastError ??
                          'Synchronization will need to be retried.',
                    ),
                  ),
                ),
              if (_patrol.status == PatrolStatus.assigned)
                FilledButton.icon(
                  onPressed: _busy ? null : _startPatrol,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start patrol'),
                ),
              if (_patrol.status == PatrolStatus.inProgress) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : _pause,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause patrol'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _addWaypoint,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Place manual waypoint on map'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _addObservation,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Add observation'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _showPhotoOptions,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Add patrol photograph'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _interrupt,
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('Interrupt for critical incident'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _endEarly,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('End patrol early'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : _reviewCompletion,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Review and complete patrol'),
                ),
              ],
              if (_patrol.status == PatrolStatus.paused ||
                  _patrol.status == PatrolStatus.interrupted) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : _resume,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume patrol'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _reviewCompletion,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Review and complete patrol'),
                ),
                if (_patrol.status == PatrolStatus.paused)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _interrupt,
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text('Interrupt for critical incident'),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _endEarly,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('End patrol early'),
                ),
              ],
              if (_patrol.status == PatrolStatus.completedPendingSync ||
                  _patrol.status == PatrolStatus.completedSynced)
                ListTile(
                  leading: Icon(
                    _patrol.status == PatrolStatus.completedSynced
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_upload_outlined,
                  ),
                  title: Text(
                    _patrol.status == PatrolStatus.completedSynced
                        ? 'Patrol completed and synchronized'
                        : 'Patrol completed · pending synchronization',
                  ),
                  subtitle: Text(
                    _patrol.syncInfo.lastSyncedAt == null
                        ? 'Pending Sync · retained on this device.'
                        : 'Last synchronized ${_patrol.syncInfo.lastSyncedAt!.toLocal()}',
                  ),
                ),
              if (_patrol.status == PatrolStatus.completedPendingSync)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _retryPendingSync,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('Retry Sync'),
                ),
              if (_patrol.status == PatrolStatus.aborted ||
                  _patrol.status == PatrolStatus.incomplete)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text('Patrol ${_patrol.status.name}'),
                  subtitle: Text(_patrol.earlyTerminationReason ?? ''),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _patrolDetailsCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _patrol.area.routeName.isEmpty
                ? 'Patrol ${_patrol.patrolId}'
                : _patrol.area.routeName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _detail('Park', _patrol.area.parkName),
          _detail('Zone', _patrol.area.zoneName),
          _detail('Assigned ranger', _patrol.rangerName),
          _detail('Patrol ID', _patrol.patrolId),
          _detail('Status', _statusLabel(_patrol.status)),
          if (_patrol.assignedAt != null)
            _detail('Assigned', _formatDate(_patrol.assignedAt!)),
          if (_patrol.startedAt != null)
            _detail('Started', _formatDate(_patrol.startedAt!)),
          if (_patrol.startLocation != null)
            _detail('Start location', _locationLabel(_patrol.startLocation!)),
          if (_patrol.interruptionReason != null)
            _detail('Interruption', _patrol.interruptionReason!),
          _detail('Route points', '${_patrol.routePoints.length}'),
          _detail('Waypoints', '${_patrol.manualWaypoints.length}'),
          _detail('Observations', '${_patrol.observations.length}'),
          _detail('Photographs', '${_patrol.photographs.length}'),
          _detail('Sync status', _syncStatusLabel),
          _detail(
            'Last successful sync',
            _patrol.syncInfo.lastSyncedAt == null
                ? 'Never'
                : _formatDate(_patrol.syncInfo.lastSyncedAt!),
          ),
          if (_patrol.syncInfo.lastError != null)
            _detail('Last sync failure', _patrol.syncInfo.lastError!),
        ],
      ),
    ),
  );

  Widget _statusCard() {
    final gps = _trackingState.gpsStatus;
    final gpsText = switch (gps.state) {
      PatrolGpsState.acquiring => 'GPS: searching for a position',
      PatrolGpsState.available => 'GPS: tracking',
      PatrolGpsState.inaccurate => 'GPS: inaccurate',
      PatrolGpsState.disabled => 'GPS: device location is off',
      PatrolGpsState.permissionDenied => 'GPS: permission unavailable',
      PatrolGpsState.unavailable => 'GPS: unavailable',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gpsText, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (gps.accuracyMeters != null)
              Text(
                'Reported accuracy: ±${gps.accuracyMeters!.toStringAsFixed(1)} m',
              ),
            Text(gps.message ?? 'No GPS status available.'),
            if (_trackingState.error != null)
              Text(
                _trackingState.error!,
                style: const TextStyle(color: Color(0xFFB42318)),
              ),
            const Divider(),
            Row(
              children: [
                Icon(_online == true ? Icons.wifi : Icons.wifi_off, size: 18),
                const SizedBox(width: 6),
                Text(
                  _online == null
                      ? 'Checking network'
                      : _online!
                      ? 'Online'
                      : 'Offline · patrol saved locally',
                ),
                const Spacer(),
                Text('Route points: ${_trackingState.recordedPointCount}'),
              ],
            ),
            Text('Sync status: $_syncStatusLabel'),
            Text(
              'Last successful synchronization: '
              '${_patrol.syncInfo.lastSyncedAt == null ? 'never' : _formatDate(_patrol.syncInfo.lastSyncedAt!)}',
            ),
            if (_patrol.syncInfo.lastError != null)
              Text(
                'Last sync failure: ${_patrol.syncInfo.lastError}',
                style: const TextStyle(color: Color(0xFFB42318)),
              ),
            if (gps.state != PatrolGpsState.available)
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : _retryGps,
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('Retry GPS'),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _addWaypoint,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Place manual waypoint'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPhotoOptions() async {
    final source = await showModalBottomSheet<PatrolPhotoSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, PatrolPhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, PatrolPhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _addPhoto(source);
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 136,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );

  String _formatDate(DateTime date) =>
      date.toLocal().toString().substring(0, 16);

  String _locationLabel(PatrolLocation location) =>
      '${location.latitude.toStringAsFixed(6)}, '
      '${location.longitude.toStringAsFixed(6)} · '
      '${location.source.name}${location.accuracyMeters == null ? '' : ' · ±${location.accuracyMeters!.toStringAsFixed(0)} m'}';

  String get _syncStatusLabel => switch (_patrol.syncInfo.status) {
    PatrolSyncStatus.localOnly => 'Local only',
    PatrolSyncStatus.pendingSync => 'Pending Sync',
    PatrolSyncStatus.syncing => 'Pending Sync · retry after interruption',
    PatrolSyncStatus.synced => 'Synced',
    PatrolSyncStatus.failed => 'Pending Sync · last attempt failed',
  };

  String _statusLabel(PatrolStatus status) => switch (status) {
    PatrolStatus.assigned => 'Assigned',
    PatrolStatus.inProgress => 'In progress',
    PatrolStatus.paused => 'Paused',
    PatrolStatus.completedPendingSync => 'Completed · pending sync',
    PatrolStatus.completedSynced => 'Completed',
    PatrolStatus.incomplete => 'Incomplete',
    PatrolStatus.aborted => 'Aborted',
    PatrolStatus.interrupted => 'Interrupted',
  };
}
