import 'patrol_records.dart';

class PatrolGpsStatus {
  const PatrolGpsStatus({
    required this.state,
    this.accuracyMeters,
    this.lastFixAt,
    this.message,
  });

  final PatrolGpsState state;
  final double? accuracyMeters;
  final DateTime? lastFixAt;
  final String? message;
}

abstract interface class PatrolLocationProvider {
  Future<PatrolLocation> currentLocation();

  Future<PatrolGpsStatus> checkStatus();

  Future<Stream<PatrolLocation>> watchLocations();
}
