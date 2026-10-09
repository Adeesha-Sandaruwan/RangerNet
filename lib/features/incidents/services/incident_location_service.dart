// Gets the phone's current GPS coordinates and explains location failures.
import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Holds the latitude, longitude, and accuracy returned by GPS.
class IncidentCoordinates {
  const IncidentCoordinates({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

/// Checks location settings and asks the phone for its current position.
class IncidentLocationService {
  // Stop with a clear message if GPS or location permission is unavailable.
  Future<IncidentCoordinates> captureCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const IncidentLocationException(
        'Location services are off. Turn on GPS or enter coordinates manually.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const IncidentLocationException(
        'Location permission was denied. Allow it or enter coordinates manually.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const IncidentLocationException(
        'Location permission is blocked in settings. Allow it or enter coordinates manually.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return IncidentCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } on TimeoutException {
      throw const IncidentLocationException(
        'GPS timed out. Retry or enter coordinates manually.',
      );
    }
  }
}

/// A location problem with a message that can be shown to the ranger.
class IncidentLocationException implements Exception {
  const IncidentLocationException(this.message);
  final String message;

  @override
  String toString() => message;
}
