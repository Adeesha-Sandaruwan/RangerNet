/// Represents geographical coordinates with optional altitude and timestamp.
class GeoLocation {
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double? altitude;
  final DateTime timestamp;

  /// Validates standard earth coordinates.
  bool get isValid =>
      latitude >= -90.0 &&
      latitude <= 90.0 &&
      longitude >= -180.0 &&
      longitude <= 180.0;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'timestamp': timestamp.toIso8601String(),
  };

  factory GeoLocation.fromJson(Map<String, dynamic> json) => GeoLocation(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    altitude: (json['altitude'] as num?)?.toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoLocation &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          altitude == other.altitude;

  @override
  int get hashCode => Object.hash(latitude, longitude, altitude);

  @override
  String toString() =>
      'GeoLocation($latitude, $longitude, alt: ${altitude ?? 0}m, $timestamp)';
}
