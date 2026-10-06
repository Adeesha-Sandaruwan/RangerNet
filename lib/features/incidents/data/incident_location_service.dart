import 'dart:async';

import 'package:geolocator/geolocator.dart';

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

class IncidentLocationService {
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

class IncidentLocationException implements Exception {
  const IncidentLocationException(this.message);
  final String message;

  @override
  String toString() => message;
}
