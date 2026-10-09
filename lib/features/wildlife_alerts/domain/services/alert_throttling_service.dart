import '../models/geo_location.dart';
import '../models/wildlife_alert.dart';

class ThrottlingResult {
  const ThrottlingResult({
    required this.wasThrottled,
    this.updatedAlert,
    this.throttledReason,
  });

  final bool wasThrottled;
  final WildlifeAlert? updatedAlert;
  final String? throttledReason;

  static const notThrottled = ThrottlingResult(wasThrottled: false);
}

/// Service to prevent alert fatigue by throttling and deduplicating alerts.
/// If an active or acknowledged alert already exists for the same target in the
/// same risk zone within the cooldown period, the new telemetry ping is appended
/// to the existing alert's location history rather than creating a duplicate alert.
class AlertThrottlingService {
  const AlertThrottlingService({
    this.cooldownDuration = const Duration(minutes: 15),
  });

  final Duration cooldownDuration;

  /// Evaluates whether an alert should be throttled against existing alerts.
  ThrottlingResult evaluate({
    required String targetId,
    required String? zoneId,
    required GeoLocation newLocation,
    required List<WildlifeAlert> activeAlerts,
    DateTime? eventTime,
  }) {
    final now = eventTime ?? DateTime.now();

    // Look for an existing unresolved alert matching target and zone
    for (final existingAlert in activeAlerts) {
      if (existingAlert.status == AlertStatus.resolved) {
        continue;
      }

      final isSameTarget = existingAlert.targetId == targetId;
      final isSameZone = zoneId != null && existingAlert.zoneId == zoneId;

      if (isSameTarget && (isSameZone || zoneId == null)) {
        final referenceTime =
            existingAlert.lastUpdatedAt ?? existingAlert.triggeredAt;
        final difference = now.difference(referenceTime).abs();

        if (difference <= cooldownDuration) {
          // Throttling match found! Append to location history
          final updatedHistory = List<GeoLocation>.from(
            existingAlert.locationHistory,
          )..add(newLocation);

          final updatedAlert = existingAlert.copyWith(
            currentLocation: newLocation,
            locationHistory: updatedHistory,
            lastUpdatedAt: now,
          );

          return ThrottlingResult(
            wasThrottled: true,
            updatedAlert: updatedAlert,
            throttledReason:
                'Telemetry appended to existing alert ${existingAlert.alertId}. '
                'Within cooldown window (${difference.inMinutes}m elapsed of ${cooldownDuration.inMinutes}m).',
          );
        }
      }
    }

    return ThrottlingResult.notThrottled;
  }
}
