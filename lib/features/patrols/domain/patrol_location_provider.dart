import 'patrol_records.dart';

/// Current GPS state, including recent fix quality and diagnostic context.
class PatrolGpsStatus {
  const PatrolGpsStatus({
    required this.state,
    this.accuracyMeters,
    this.lastFixAt,
    this.message,
  });

  /// Current GPS availability or quality state.
  final PatrolGpsState state;

  /// Accuracy of the most recent location fix, when known.
  final double? accuracyMeters;

  /// Timestamp of the most recent GPS fix, when known.
  final DateTime? lastFixAt;

  /// Optional user-facing explanation of the current GPS state.
  final String? message;
}

/// ISP: small GPS boundary for obtaining a fix, checking GPS state, and watching fixes.
abstract interface class PatrolLocationProvider {
  /// Obtains one current location fix.
  Future<PatrolLocation> currentLocation();

  /// Reads current GPS availability and quality.
  Future<PatrolGpsStatus> checkStatus();

  /// Opens a stream of location fixes for live tracking.
  Future<Stream<PatrolLocation>> watchLocations();
}
