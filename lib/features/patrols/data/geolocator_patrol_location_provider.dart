import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/patrol_location_provider.dart';
import '../domain/patrol_records.dart';

class GeolocatorPatrolLocationProvider implements PatrolLocationProvider {
  const GeolocatorPatrolLocationProvider();

  @override
  Future<PatrolLocation> currentLocation() async {
    await _ensureReady();
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return _fromPosition(position);
    } on TimeoutException {
      throw const PatrolLocationException(
        'GPS did not produce a fix in time. Retry or place a manual waypoint.',
      );
    }
  }

  @override
  Future<PatrolGpsStatus> checkStatus() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const PatrolGpsStatus(
          state: PatrolGpsState.disabled,
          message: 'Device location services are off.',
        );
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return const PatrolGpsStatus(
          state: PatrolGpsState.permissionDenied,
          message: 'Location permission is unavailable.',
        );
      }
      return const PatrolGpsStatus(
        state: PatrolGpsState.acquiring,
        message: 'Waiting for a GPS position.',
      );
    } catch (error) {
      return PatrolGpsStatus(
        state: PatrolGpsState.unavailable,
        message: 'Could not check GPS status: $error',
      );
    }
  }

  @override
  Future<Stream<PatrolLocation>> watchLocations() async {
    await _ensureReady();
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).map(_fromPosition);
  }

  Future<void> _ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const PatrolLocationException(
        'Location services are off. Turn on GPS or use a manual map waypoint.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const PatrolLocationException(
        'Location permission is unavailable. Allow it or use a manual map waypoint.',
      );
    }
  }

  PatrolLocation _fromPosition(Position position) => PatrolLocation(
    latitude: position.latitude,
    longitude: position.longitude,
    recordedAt: position.timestamp.toUtc(),
    source: PatrolLocationSource.gps,
    accuracyMeters: position.accuracy,
  );
}

class PatrolLocationException implements Exception {
  const PatrolLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}
