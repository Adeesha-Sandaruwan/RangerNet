import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../application/patrol_service.dart';
import '../application/patrol_sync_service.dart';
import '../application/patrol_tracking_service.dart';
import '../application/patrol_metrics_service.dart';
import '../data/patrol_photo_picker.dart';
import '../data/geolocator_patrol_location_provider.dart';
import '../domain/patrol.dart';
import '../domain/patrol_location_provider.dart';
import '../domain/patrol_network_status.dart';
import '../domain/patrol_records.dart';
import 'manual_waypoint_map_page.dart';
import 'patrol_completion_review_page.dart';
import 'patrol_network_status_card.dart';
import 'patrol_primary_action_button.dart';
import 'patrol_route_map.dart';

/// Ranger's active patrol screen for recording observations and managing its
/// lifecycle. DIP: delegates patrol, tracking, and sync operations to services.
class PatrolSessionPage extends StatefulWidget {
  const PatrolSessionPage({
    required this.patrol,
    required this.service,
    required this.trackingService,
    required this.syncService,
    required this.networkStatus,
    super.key,
  });

  /// Patrol record to display and conduct.
  final Patrol patrol;

  /// Application boundary for recording patrol lifecycle and field data.
  final PatrolService service;

  /// Boundary for GPS updates and tracking control.
  final PatrolTrackingService trackingService;

  /// Boundary for synchronizing a completed patrol.
  final PatrolSyncService syncService;

  /// Supplies connectivity changes used to retry pending sync.
  final PatrolNetworkStatusProvider networkStatus;

  @override
  State<PatrolSessionPage> createState() => _PatrolSessionPageState();
}

/// Coordinates patrol actions, GPS/network updates, and elapsed-time display.
/// Cancels timers/subscriptions and removes the lifecycle observer on dispose.
class _PatrolSessionPageState extends State<PatrolSessionPage>
    with WidgetsBindingObserver {
  static const _uuid = Uuid();
  static const _maxGpsAccuracyMeters = 50.0;
  static const _metrics = PatrolMetricsService();

  late Patrol _patrol = widget.patrol;
  PatrolTrackingState _trackingState = const PatrolTrackingState(
    gpsStatus: PatrolGpsStatus(state: PatrolGpsState.acquiring),
  );

  /// Tracking-state listener, cancelled when the page is disposed.
  StreamSubscription<PatrolTrackingState>? _trackingSubscription;

  /// Connectivity listener, cancelled when the page is disposed.
  StreamSubscription<bool>? _networkSubscription;

  /// Elapsed-time refresh timer, cancelled when the page is disposed.
  Timer? _clock;
  bool _busy = false;
  bool _reviewingCompletion = false;
  bool? _online;
  String? _error;

  /// Subscribes to tracking/connectivity and resumes tracking when appropriate.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _trackingState = widget.trackingService.currentState;
    _trackingSubscription = widget.trackingService.states.listen((state) {
      if (mounted) {
        setState(() {
          _trackingState = state;
          _patrol = state.patrol ?? _patrol;
        });
      }
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

  /// Cancels timers/subscriptions and removes this page's lifecycle observer.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trackingSubscription?.cancel();
    _networkSubscription?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  /// Restarts tracking after foregrounding an active patrol.
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

  /// Retries sync while retaining the last locally saved status on failure.
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

  /// Starts an assigned patrol, using a manual location only after confirmation
  /// when reliable GPS cannot be acquired.
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

  /// Pauses tracking and records the patrol pause through the service.
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

  /// Resumes the paused patrol and its location tracking.
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

  /// Records an interruption and stops active tracking.
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

  /// Ends a patrol early with the ranger-provided reason.
  Future<void> _endEarly() async {
    final confirmed = await _confirmAction(
      title: 'End patrol early?',
      message:
          'The patrol will be marked as aborted. You will be asked to record '
          'a reason, and saved patrol data will be retained.',
      confirmLabel: 'Continue',
    );
    if (confirmed != true || !mounted) return;
    final reason = await _reasonDialog(
      title: 'End patrol early',
      prompt: 'Record why the patrol is ending before completion.',
    );
    if (reason == null) return;
    var saved = false;
    var reasonToSave = reason;
    while (mounted && !saved) {
      saved = await _runAction('Patrol termination was not saved', () async {
        await widget.trackingService.stop();
        _patrol = await widget.service.abort(
          rangerId: _patrol.rangerId,
          localId: _patrol.localId,
          reason: reasonToSave,
          at: DateTime.now().toUtc(),
          endLocation: _reliableLatestFix,
        );
      });
      if (!saved && mounted) {
        if (_patrol.status == PatrolStatus.inProgress) {
          await _restartTracking();
        }
        final retryReason = await _reasonDialog(
          title: 'Retry ending patrol early',
          prompt: 'The reason is retained. Edit it if needed, then retry.',
          initialValue: reasonToSave,
        );
        if (retryReason == null) return;
        reasonToSave = retryReason;
      }
    }
  }

  /// Adds a map-selected manual waypoint to the active patrol.
  Future<void> _addWaypoint() async {
    final location = await _selectManualLocation();
    if (location == null || !mounted) return;
    final enteredDescription = await _textDialog(
      title: 'Describe waypoint',
      label: 'Waypoint description',
    );
    if (enteredDescription == null || !mounted) return;
    var description = enteredDescription;
    final waypointId = _uuid.v4();
    var saved = false;
    while (mounted && !saved) {
      saved = await _runAction('Waypoint was not saved', () async {
        _patrol = await widget.service.addManualWaypoint(
          rangerId: _patrol.rangerId,
          localId: _patrol.localId,
          waypoint: PatrolWaypoint(
            id: waypointId,
            description: description,
            location: location,
          ),
        );
      });
      if (!saved && mounted) {
        final retryDescription = await _textDialog(
          title: 'Retry saving waypoint',
          label: 'The description is retained. Edit it if needed.',
          initialValue: description,
        );
        if (retryDescription == null) return;
        description = retryDescription;
      }
    }
  }

  /// Collects an observation and records it against the patrol.
  Future<void> _addObservation() async {
    final enteredInput = await _recordInputDialog(
      title: 'Add patrol observation',
      label: 'Observation details',
      maxLines: 4,
      categories: const [
        'Wildlife',
        'Habitat',
        'Safety',
        'Infrastructure',
        'Other',
      ],
    );
    if (enteredInput == null || !mounted) return;
    var input = enteredInput;
    var location = _reliableLatestFix;
    if (location == null) {
      location = await _selectManualLocation();
      if (location == null || !mounted) return;
    }
    var saved = false;
    final observationId = _uuid.v4();
    while (mounted && !saved) {
      saved = await _runAction('Observation was not saved', () async {
        _patrol = await widget.service.addObservation(
          rangerId: _patrol.rangerId,
          localId: _patrol.localId,
          observation: PatrolObservation(
            id: observationId,
            description: input.description,
            category: input.category,
            location: location!,
          ),
        );
      });
      if (!saved && mounted) {
        final retryInput = await _recordInputDialog(
          title: 'Retry saving observation',
          label: 'The details and category are retained.',
          maxLines: 4,
          categories: const [
            'Wildlife',
            'Habitat',
            'Safety',
            'Infrastructure',
            'Other',
          ],
          initialValue: input.description,
          initialCategory: input.category,
        );
        if (retryInput == null) return;
        input = retryInput;
      }
    }
  }

  /// Captures or selects evidence and attaches it to the patrol.
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

  /// Opens the completion review before the ranger confirms patrol completion.
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
            gpsStatus: _trackingState.gpsStatus,
            service: widget.service,
            syncService: widget.syncService,
            networkStatus: widget.networkStatus,
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
    String? initialValue,
  }) => _textDialog(
    title: title,
    label: prompt,
    maxLines: 4,
    initialValue: initialValue,
  );

  Future<String?> _textDialog({
    required String title,
    required String label,
    int maxLines = 2,
    String? initialValue,
  }) async => (await _recordInputDialog(
    title: title,
    label: label,
    maxLines: maxLines,
    initialValue: initialValue,
  ))?.description;

  Future<_PatrolRecordInput?> _recordInputDialog({
    required String title,
    required String label,
    int maxLines = 2,
    String? initialValue,
    String? initialCategory,
    List<String> categories = const [],
  }) async {
    final formKey = GlobalKey<FormState>();
    var description = initialValue ?? '';
    final value = await showDialog<_PatrolRecordInput>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var category = initialCategory;
        var allowPop = false;
        StateSetter? updateDialog;

        Future<void> cancel() async {
          if (description.trim().isNotEmpty ||
              description != (initialValue ?? '') ||
              category != initialCategory) {
            final discard = await _confirmAction(
              title: 'Discard unsaved changes?',
              message: 'Your entered information will be lost.',
              confirmLabel: 'Discard',
            );
            if (discard != true || !dialogContext.mounted) return;
          }
          updateDialog?.call(() => allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          });
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            updateDialog = setDialogState;
            return PopScope<_PatrolRecordInput>(
              canPop: allowPop,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) unawaited(cancel());
              },
              child: AlertDialog(
                title: Text(title),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (categories.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Observation category',
                            border: OutlineInputBorder(),
                          ),
                          items: categories
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option,
                                  child: Text(option),
                                ),
                              )
                              .toList(),
                          validator: (selected) => selected == null
                              ? 'Choose an observation category.'
                              : null,
                          onChanged: (selected) =>
                              setDialogState(() => category = selected),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        initialValue: initialValue,
                        autofocus: true,
                        maxLines: maxLines,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: label,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (text) => text == null || text.trim().isEmpty
                            ? 'This field is required.'
                            : null,
                        onChanged: (text) => description = text,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: cancel, child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      formKey.currentState!.save();
                      setDialogState(() => allowPop = true);
                      final result = _PatrolRecordInput(
                        description.trim(),
                        category: category,
                      );
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, result);
                        }
                      });
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    return value;
  }

  Future<bool> _runAction(
    String failureMessage,
    Future<void> Function() action,
  ) async {
    if (_busy) return false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      try {
        await widget.trackingService.refreshPatrol(_patrol);
        if (mounted) {
          setState(() => _trackingState = widget.trackingService.currentState);
        }
      } catch (error) {
        if (mounted) {
          setState(
            () => _error =
                'The patrol record was saved, but its tracking display could not refresh: $error',
          );
        }
      }
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = '$failureMessage: $error');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  PatrolLocation? get _reliableLatestFix {
    final fix = _trackingState.latestFix;
    if (_trackingState.gpsStatus.state != PatrolGpsState.available ||
        (fix?.accuracyMeters != null &&
            fix!.accuracyMeters! > _maxGpsAccuracyMeters)) {
      return null;
    }
    return fix;
  }

  String get _manualWaypointActionLabel {
    final gpsState = _trackingState.gpsStatus.state;
    if (gpsState == PatrolGpsState.available) {
      return 'Add manual waypoint on map';
    }
    return 'GPS unavailable/inaccurate — mark manual waypoint';
  }

  @override
  Widget build(BuildContext context) {
    final active = _isActive;
    final showRouteMap =
        _patrol.plannedRoute != null ||
        _patrol.startLocation != null ||
        _patrol.routePoints.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F3),
      appBar: AppBar(title: const Text('Patrol details')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (showRouteMap) ...[
                Text(
                  _patrol.plannedRoute == null
                      ? 'Recorded patrol route'
                      : 'Assigned route and actual track',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                PatrolRouteMap(
                  patrol: _patrol,
                  latestLocation: _reliableLatestFix,
                  height: 280,
                ),
                const SizedBox(height: 8),
                _routeLegend(),
                if (_patrol.startedAt != null) ...[
                  const SizedBox(height: 10),
                  _liveRouteSummary(),
                ],
                const SizedBox(height: 12),
              ],
              PatrolNetworkStatusCard(
                online: _online,
                onRefresh: _refreshNetworkStatus,
              ),
              _patrolDetailsCard(),
              if (active) _statusCard(),
              if (!active)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.gps_not_fixed),
                    title: Text('GPS status: Not tracking'),
                    subtitle: Text(
                      'GPS tracking starts when this assigned patrol begins.',
                    ),
                  ),
                ),
              if (_error != null)
                Card(
                  color: const Color(0xFFFFE9E5),
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('Action needs attention'),
                    subtitle: Text(_error!),
                  ),
                ),
              if (_busy)
                const Card(
                  child: ListTile(
                    leading: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text('Working…'),
                    subtitle: Text(
                      'Saving patrol data on this device. Please wait.',
                    ),
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
                PatrolPrimaryActionButton(
                  label: 'Start patrol',
                  icon: Icons.play_arrow,
                  onPressed: _busy ? null : _startPatrol,
                  busy: _busy,
                ),
              if (_patrol.status == PatrolStatus.inProgress) ...[
                PatrolPrimaryActionButton(
                  label: 'Pause patrol',
                  icon: Icons.pause,
                  onPressed: _busy ? null : _pause,
                  busy: _busy,
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _addWaypoint,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: Text(_manualWaypointActionLabel),
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
                PatrolPrimaryActionButton(
                  label: 'Review and complete patrol',
                  icon: Icons.fact_check_outlined,
                  onPressed: _busy ? null : _reviewCompletion,
                  busy: _busy,
                ),
              ],
              if (_patrol.status == PatrolStatus.paused ||
                  _patrol.status == PatrolStatus.interrupted) ...[
                PatrolPrimaryActionButton(
                  label: 'Resume patrol',
                  icon: Icons.play_arrow,
                  onPressed: _busy ? null : _resume,
                  busy: _busy,
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
          if (_patrol.plannedCoverageSections.isNotEmpty)
            _detail(
              'Planned coverage sections',
              '${_patrol.plannedCoverageSections.length}',
            ),
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

  Widget _routeLegend() => Wrap(
    spacing: 14,
    runSpacing: 8,
    children: [
      if (_patrol.plannedRoute != null)
        const _RouteLegendItem(
          color: Color(0xFF17613F),
          label: 'Manager assigned',
        ),
      if (_patrol.startLocation != null || _patrol.routePoints.isNotEmpty)
        const _RouteLegendItem(
          color: Color(0xFF2673B8),
          label: 'Ranger recorded track',
        ),
      if (_patrol.manualWaypoints.isNotEmpty)
        const _RouteLegendItem(
          color: Colors.deepPurple,
          label: 'Manual waypoint',
        ),
    ],
  );

  Widget _liveRouteSummary() {
    final distanceMeters = _metrics.distanceTravelledMeters(_patrol);
    final duration = _metrics.durationAt(_patrol, DateTime.now());
    final distanceLabel = distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(2)} km'
        : '${distanceMeters.toStringAsFixed(0)} m';
    final durationLabel =
        '${duration.inHours.toString().padLeft(2, '0')}:'
        '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}';

    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFFEAF2EC),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth < 480
                    ? (constraints.maxWidth - 12) / 2
                    : (constraints.maxWidth - 24) / 3;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _RouteMetric(
                        icon: Icons.route_outlined,
                        label: 'Actual route distance',
                        value: distanceLabel,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _RouteMetric(
                        icon: Icons.timer_outlined,
                        label: 'Active duration',
                        value: durationLabel,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _RouteMetric(
                        icon: Icons.my_location_outlined,
                        label: 'GPS points',
                        value: '${_patrol.routePoints.length}',
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_patrol.manualWaypoints.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Includes ${_patrol.manualWaypoints.length} map-marked '
                'location(s). Distance follows saved GPS and manual points '
                'in recorded order.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

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
            Text('Recorded GPS points: ${_trackingState.recordedPointCount}'),
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
                    label: Text(_manualWaypointActionLabel),
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
      '${location.source == PatrolLocationSource.gps ? 'GPS' : 'Manual'}'
      '${location.accuracyMeters == null ? '' : ' · ±${location.accuracyMeters!.toStringAsFixed(0)} m'}';

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

/// Holds validated form values before they are recorded against a patrol.
class _PatrolRecordInput {
  const _PatrolRecordInput(this.description, {this.category});

  /// Observation description entered by the ranger.
  final String description;

  /// Optional observation category.
  final String? category;
}

/// Shows one route metric with its label and value. SRP: presentation only.
class _RouteMetric extends StatelessWidget {
  const _RouteMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF17613F)),
      const SizedBox(height: 4),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 2),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

/// Labels a route-map symbol with its corresponding status colour.
class _RouteLegendItem extends StatelessWidget {
  const _RouteLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
