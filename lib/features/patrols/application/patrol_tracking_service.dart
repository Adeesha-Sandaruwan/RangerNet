import 'dart:async';

import 'package:uuid/uuid.dart';

import '../domain/patrol.dart';
import '../domain/patrol_location_provider.dart';
import '../domain/patrol_records.dart';
import 'patrol_metrics_service.dart';
import 'patrol_service.dart';

class PatrolTrackingState {
  const PatrolTrackingState({
    required this.gpsStatus,
    this.patrol,
    this.latestFix,
    this.recordedPointCount = 0,
    this.error,
  });

  final PatrolGpsStatus gpsStatus;
  final Patrol? patrol;
  final PatrolLocation? latestFix;
  final int recordedPointCount;
  final String? error;
}

class PatrolTrackingService {
  PatrolTrackingService({
    required this._patrolService,
    required this._locationProvider,
    this._metrics = const PatrolMetricsService(),
    Uuid? uuid,
    this.maximumAccuracyMeters = 50,
    this.minimumPointDistanceMeters = 8,
    this.minimumPointInterval = const Duration(seconds: 5),
  }) : _uuid = uuid ?? const Uuid();

  final PatrolService _patrolService;
  final PatrolLocationProvider _locationProvider;
  final PatrolMetricsService _metrics;
  final Uuid _uuid;
  final double maximumAccuracyMeters;
  final double minimumPointDistanceMeters;
  final Duration minimumPointInterval;
  final _states = StreamController<PatrolTrackingState>.broadcast();

  StreamSubscription<PatrolLocation>? _subscription;
  Timer? _retryTimer;
  Timer? _healthTimer;
  Future<void> _writeTail = Future<void>.value();
  Patrol? _patrol;
  PatrolLocation? _latestFix;
  PatrolGpsStatus _gpsStatus = const PatrolGpsStatus(
    state: PatrolGpsState.unavailable,
  );
  String? _error;
  DateTime? _trackingStartedAt;
  bool _disposed = false;
  bool _retryInProgress = false;

  Stream<PatrolTrackingState> get states => _states.stream;

  PatrolTrackingState get currentState => PatrolTrackingState(
    gpsStatus: _gpsStatus,
    patrol: _patrol,
    latestFix: _latestFix,
    recordedPointCount: _patrol?.routePoints.length ?? 0,
    error: _error,
  );

  Future<PatrolLocation> currentLocation() =>
      _locationProvider.currentLocation();

  Future<void> start(Patrol patrol) async {
    if (patrol.status != PatrolStatus.inProgress) {
      throw StateError('GPS tracking requires an in-progress patrol.');
    }
    await stop();
    _patrol = patrol;
    _trackingStartedAt = DateTime.now().toUtc();
    _error = null;
    try {
      _gpsStatus = await _locationProvider.checkStatus();
    } catch (error) {
      _gpsStatus = PatrolGpsStatus(
        state: PatrolGpsState.unavailable,
        message: 'Could not check GPS status: $error',
      );
      _error = error.toString();
    }
    _emit();
    try {
      final positions = await _locationProvider.watchLocations();
      _subscription = positions.listen(
        (fix) => unawaited(_queueFix(fix)),
        onError: (Object error) {
          _gpsStatus = PatrolGpsStatus(
            state: PatrolGpsState.unavailable,
            accuracyMeters: _latestFix?.accuracyMeters,
            lastFixAt: _latestFix?.recordedAt,
            message:
                'GPS tracking paused; previously recorded route points are saved.',
          );
          _error = error.toString();
          _subscription = null;
          _emit();
          _scheduleRetry();
        },
      );
      _startHealthChecks();
    } catch (error) {
      _gpsStatus = PatrolGpsStatus(
        state: PatrolGpsState.unavailable,
        accuracyMeters: _latestFix?.accuracyMeters,
        lastFixAt: _latestFix?.recordedAt,
        message:
            'GPS tracking is unavailable; previously recorded route points are saved.',
      );
      _error = error.toString();
      _emit();
      _scheduleRetry();
      _startHealthChecks();
    }
  }

  Future<void> stop() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    _healthTimer?.cancel();
    _healthTimer = null;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    await _writeTail;
  }

  void _startHealthChecks() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_disposed || _patrol?.status != PatrolStatus.inProgress) return;
      PatrolGpsStatus status;
      try {
        status = await _locationProvider.checkStatus();
      } catch (error) {
        _error = 'Could not check GPS status: $error';
        _gpsStatus = PatrolGpsStatus(
          state: PatrolGpsState.unavailable,
          message: _error,
        );
        _emit();
        if (_subscription == null) _scheduleRetry();
        return;
      }
      if (status.state == PatrolGpsState.disabled ||
          status.state == PatrolGpsState.permissionDenied) {
        _gpsStatus = status;
        _emit();
        if (_subscription == null) _scheduleRetry();
        return;
      }
      final now = DateTime.now().toUtc();
      final lastFixAt = _latestFix?.recordedAt;
      final reference = lastFixAt ?? _trackingStartedAt;
      if (reference != null &&
          now.difference(reference) > const Duration(seconds: 45)) {
        _gpsStatus = PatrolGpsStatus(
          state: PatrolGpsState.unavailable,
          accuracyMeters: _latestFix?.accuracyMeters,
          lastFixAt: lastFixAt,
          message:
              'No recent GPS fix. The saved route is preserved; retry GPS or place a manual waypoint.',
        );
        _emit();
      } else if (_latestFix == null &&
          _gpsStatus.state != PatrolGpsState.inaccurate) {
        _gpsStatus = status;
        _emit();
      }
      if (_subscription == null) _scheduleRetry();
    });
  }

  Future<void> refreshPatrol(Patrol patrol) async {
    _patrol = patrol;
    _emit();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _states.close();
  }

  void _scheduleRetry() {
    _retryTimer ??= Timer.periodic(const Duration(seconds: 15), (_) async {
      if (_disposed || _subscription != null) {
        _retryTimer?.cancel();
        _retryTimer = null;
        return;
      }
      if (_retryInProgress) return;
      _retryInProgress = true;
      try {
        final status = await _locationProvider.checkStatus();
        _gpsStatus = status;
        _emit();
        if (status.state == PatrolGpsState.disabled ||
            status.state == PatrolGpsState.permissionDenied ||
            status.state == PatrolGpsState.unavailable) {
          return;
        }
        final positions = await _locationProvider.watchLocations();
        _retryTimer?.cancel();
        _retryTimer = null;
        _subscription = positions.listen(
          (fix) => unawaited(_queueFix(fix)),
          onError: (Object error) {
            _subscription = null;
            _gpsStatus = PatrolGpsStatus(
              state: PatrolGpsState.unavailable,
              accuracyMeters: _latestFix?.accuracyMeters,
              lastFixAt: _latestFix?.recordedAt,
              message:
                  'GPS tracking paused; previously recorded route points are saved.',
            );
            _error = error.toString();
            _emit();
            _scheduleRetry();
          },
        );
      } catch (error) {
        _error = error.toString();
        _gpsStatus = PatrolGpsStatus(
          state: PatrolGpsState.unavailable,
          accuracyMeters: _latestFix?.accuracyMeters,
          lastFixAt: _latestFix?.recordedAt,
          message:
              'GPS tracking is unavailable; previously recorded route points are saved.',
        );
        _emit();
      } finally {
        _retryInProgress = false;
      }
    });
  }

  Future<void> _queueFix(PatrolLocation fix) async {
    // Serialize async local writes so rapid GPS fixes cannot reorder the track.
    final previous = _writeTail;
    final completed = Completer<void>();
    _writeTail = completed.future;
    await previous;
    try {
      await _acceptFix(fix);
    } finally {
      completed.complete();
    }
  }

  Future<void> _acceptFix(PatrolLocation fix) async {
    _latestFix = fix;
    final accuracy = fix.accuracyMeters;
    if (accuracy != null && accuracy > maximumAccuracyMeters) {
      _gpsStatus = PatrolGpsStatus(
        state: PatrolGpsState.inaccurate,
        accuracyMeters: accuracy,
        lastFixAt: fix.recordedAt,
        message:
            'GPS accuracy is too low to record a route point. Use a manual waypoint.',
      );
      _emit();
      return;
    }
    _gpsStatus = PatrolGpsStatus(
      state: PatrolGpsState.available,
      accuracyMeters: accuracy,
      lastFixAt: fix.recordedAt,
      message: 'GPS tracking is active.',
    );
    final patrol = _patrol;
    if (patrol == null || patrol.status != PatrolStatus.inProgress) {
      _emit();
      return;
    }

    final previous = patrol.routePoints.isEmpty
        ? patrol.startLocation
        : patrol.routePoints.last.location;
    if (previous != null) {
      final distance = _metrics.distanceBetween(previous, fix);
      final elapsed = fix.recordedAt.difference(previous.recordedAt);
      if (distance < minimumPointDistanceMeters ||
          elapsed < minimumPointInterval) {
        _emit();
        return;
      }
    }
    try {
      _patrol = await _patrolService.recordRoutePoint(
        rangerId: patrol.rangerId,
        localId: patrol.localId,
        point: PatrolRoutePoint(id: _uuid.v4(), location: fix),
      );
      _error = null;
    } catch (error) {
      _error = 'GPS fix received but route point was not saved: $error';
      _gpsStatus = PatrolGpsStatus(
        state: PatrolGpsState.unavailable,
        accuracyMeters: accuracy,
        lastFixAt: fix.recordedAt,
        message:
            'Route storage failed. Tracking is not confirmed; retry or use manual waypoints.',
      );
    }
    _emit();
  }

  void _emit() {
    if (!_disposed && !_states.isClosed) _states.add(currentState);
  }
}
