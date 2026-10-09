import '../models/animal.dart';
import '../models/high_risk_zone.dart';
import '../models/sensor.dart';
import '../models/wildlife_alert.dart';
import 'geofence_service.dart';

class SensorEvaluationResult {
  const SensorEvaluationResult({
    required this.shouldAlert,
    this.riskLevel,
    this.title = '',
    this.description = '',
    this.triggerType,
    this.zoneId,
    this.zoneName,
    this.capturedImageUrl,
    this.simulatedDetectionTag,
  });

  final bool shouldAlert;
  final AlertRiskLevel? riskLevel;
  final String title;
  final String description;
  final AlertTriggerType? triggerType;
  final String? zoneId;
  final String? zoneName;
  final String? capturedImageUrl;
  final String? simulatedDetectionTag;

  static const noAlert = SensorEvaluationResult(shouldAlert: false);
}

/// Strategy interface for processing telemetry from distinct sensor hardware types.
abstract class SensorProcessingStrategy {
  SensorEvaluationResult evaluate({
    required Sensor sensor,
    required List<HighRiskZone> zones,
    Animal? animal,
  });
}

/// Processing Strategy for animal-attached GPS collars.
/// Evaluates coordinates against active geofences and monitors critical battery levels.
class GPSCollarProcessingStrategy implements SensorProcessingStrategy {
  const GPSCollarProcessingStrategy({
    this.geofenceService = const GeofenceService(),
  });

  final GeofenceService geofenceService;

  @override
  SensorEvaluationResult evaluate({
    required Sensor sensor,
    required List<HighRiskZone> zones,
    Animal? animal,
  }) {
    if (sensor is! GPSCollar) {
      throw ArgumentError('GPSCollarProcessingStrategy expects a GPSCollar');
    }

    // 1. Check critical battery level
    if (sensor.batteryLevel <= 10.0) {
      return SensorEvaluationResult(
        shouldAlert: true,
        riskLevel: AlertRiskLevel.medium,
        title: 'Critical Battery: Collar ${sensor.id}',
        description:
            'Collar battery is at ${sensor.batteryLevel.toStringAsFixed(1)}%. '
            'Tracking signal for ${animal?.name ?? 'Animal ${sensor.animalId}'} at risk.',
        triggerType: AlertTriggerType.criticalBattery,
      );
    }

    // 2. Evaluate geofence breach
    final breachResult = geofenceService.evaluateLocation(
      sensor.currentLocation,
      zones,
    );

    if (breachResult.isBreached && breachResult.breachedZone != null) {
      final zone = breachResult.breachedZone!;
      final animalName = animal?.name ?? 'Animal (${sensor.animalId})';
      final animalSpecies = animal?.species ?? 'Wildlife';

      // Combine animal vulnerability and zone severity to calculate alert priority
      final isHighPriority =
          zone.severityLevel == ZoneSeverityLevel.high ||
          (animal?.riskProfile == AnimalRiskProfile.high &&
              zone.severityLevel != ZoneSeverityLevel.low);

      final riskLevel = isHighPriority
          ? AlertRiskLevel.high
          : zone.severityLevel == ZoneSeverityLevel.medium
              ? AlertRiskLevel.medium
              : AlertRiskLevel.low;

      final boundaryNotice = breachResult.isExactBoundary
          ? ' [Exact Boundary Edge]'
          : '';

      return SensorEvaluationResult(
        shouldAlert: true,
        riskLevel: riskLevel,
        title: '$riskLevel Risk: $animalName entered ${zone.name}$boundaryNotice',
        description:
            '$animalSpecies "$animalName" breached high-risk zone "${zone.name}" '
            '(${zone.description.isNotEmpty ? zone.description : zone.severityLevel.label}) '
            'at lat: ${sensor.latitude.toStringAsFixed(5)}, lon: ${sensor.longitude.toStringAsFixed(5)}.',
        triggerType: AlertTriggerType.geofenceBreach,
        zoneId: zone.zoneId,
        zoneName: zone.name,
      );
    }

    return SensorEvaluationResult.noAlert;
  }
}

/// Processing Strategy for remote camera traps.
/// Evaluates simulated vision detections such as human trespass, weapons, or distressed wildlife.
class CameraTrapProcessingStrategy implements SensorProcessingStrategy {
  const CameraTrapProcessingStrategy();

  @override
  SensorEvaluationResult evaluate({
    required Sensor sensor,
    required List<HighRiskZone> zones,
    Animal? animal,
  }) {
    if (sensor is! CameraTrap) {
      throw ArgumentError('CameraTrapProcessingStrategy expects a CameraTrap');
    }

    final tag = sensor.simulatedDetectionTag?.toUpperCase();
    if (tag == null || tag.isEmpty || tag == 'NORMAL_PASSAGE' || tag == 'SAFE') {
      return SensorEvaluationResult.noAlert;
    }

    if (tag.contains('HUMAN_TRESPASS') ||
        tag.contains('POACHER') ||
        tag.contains('WEAPON') ||
        tag.contains('SNARE')) {
      return SensorEvaluationResult(
        shouldAlert: true,
        riskLevel: AlertRiskLevel.high,
        title: 'HIGH THREAT: Human Intrusion / Poaching Detected',
        description:
            'Camera Trap ${sensor.id} captured an unauthorized perimeter breach '
            'or armed human presence. Detection: $tag.',
        triggerType: AlertTriggerType.cameraDetection,
        capturedImageUrl: sensor.capturedImageUrl,
        simulatedDetectionTag: tag,
      );
    }

    if (tag.contains('DISTRESSED') ||
        tag.contains('INJURED') ||
        tag.contains('TRAPPED')) {
      final subject = animal?.name != null
          ? '${animal!.name} (${animal.species})'
          : 'Wildlife';
      return SensorEvaluationResult(
        shouldAlert: true,
        riskLevel: AlertRiskLevel.high,
        title: 'HIGH ALERT: Distressed Wildlife Detected',
        description:
            'Camera Trap ${sensor.id} captured a potentially injured or distressed '
            '$subject requiring immediate veterinary/ranger intervention. Detection: $tag.',
        triggerType: AlertTriggerType.cameraDetection,
        capturedImageUrl: sensor.capturedImageUrl,
        simulatedDetectionTag: tag,
      );
    }

    // Default catch for other suspicious/unknown tags
    return SensorEvaluationResult(
      shouldAlert: true,
      riskLevel: AlertRiskLevel.medium,
      title: 'Alert: Camera Detection Flagged ($tag)',
      description:
          'Camera Trap ${sensor.id} triggered with classification tag: $tag.',
      triggerType: AlertTriggerType.cameraDetection,
      capturedImageUrl: sensor.capturedImageUrl,
      simulatedDetectionTag: tag,
    );
  }
}
