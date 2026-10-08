import 'package:uuid/uuid.dart';
import '../models/animal.dart';
import '../models/geo_location.dart';
import '../models/sensor.dart';
import '../models/wildlife_alert.dart';
import '../repositories/wildlife_alert_repository.dart';
import 'alert_throttling_service.dart';
import 'sensor_processor_factory.dart';

class TelemetryIngestionResult {
  const TelemetryIngestionResult({
    required this.success,
    this.alert,
    this.wasThrottled = false,
    this.message = '',
  });

  final bool success;
  final WildlifeAlert? alert;
  final bool wasThrottled;
  final String message;

  factory TelemetryIngestionResult.failure(String message) =>
      TelemetryIngestionResult(success: false, message: message);
}

/// Primary telemetry ingestion service handling incoming GPS pings and Camera Trap triggers.
/// Coordinates validation, processor strategy dispatch, de-duplication/throttling, and alert persistence.
class SensorTelemetryService {
  SensorTelemetryService({
    required this.repository,
    SensorProcessorFactory? processorFactory,
    AlertThrottlingService? throttlingService,
    Uuid? uuid,
  })  : _processorFactory = processorFactory ?? SensorProcessorFactory(),
        _throttlingService = throttlingService ?? const AlertThrottlingService(),
        _uuid = uuid ?? const Uuid();

  final WildlifeAlertRepository repository;
  final SensorProcessorFactory _processorFactory;
  final AlertThrottlingService _throttlingService;
  final Uuid _uuid;

  /// Ingests GPS telemetry data sent from an animal's collar.
  Future<TelemetryIngestionResult> ingestGpsTelemetry({
    required String collarId,
    required double latitude,
    required double longitude,
    double? altitude,
    required double batteryLevel,
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    final location = GeoLocation(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      timestamp: now,
    );

    // 1. Validate inputs
    if (!location.isValid) {
      return TelemetryIngestionResult.failure(
        'Invalid GPS coordinates: ($latitude, $longitude). Latitude must be [-90, 90] and Longitude [-180, 180].',
      );
    }

    if (batteryLevel < 0.0 || batteryLevel > 100.0) {
      return TelemetryIngestionResult.failure(
        'Invalid battery level: $batteryLevel. Must be between 0% and 100%.',
      );
    }

    // 2. Fetch sensor, animal, and active zones
    final sensor = await repository.getSensorById(collarId);
    if (sensor == null || sensor is! GPSCollar) {
      return TelemetryIngestionResult.failure(
        'GPS Collar with ID "$collarId" is not registered in the system.',
      );
    }

    final animal = await repository.getAnimalById(sensor.animalId);
    final zones = await repository.getHighRiskZones();

    // 3. Update sensor telemetry state
    final updatedSensor = sensor.copyWith(
      currentLocation: location,
      batteryLevel: batteryLevel,
      lastActiveAt: now,
      status: batteryLevel <= 10.0
          ? SensorStatus.lowBattery
          : SensorStatus.active,
    );
    await repository.updateSensor(updatedSensor);

    // 4. Select strategy via factory and evaluate risk
    final strategy = _processorFactory.getStrategy(SensorType.gpsCollar);
    final evalResult = strategy.evaluate(
      sensor: updatedSensor,
      zones: zones,
      animal: animal,
    );

    if (!evalResult.shouldAlert) {
      return const TelemetryIngestionResult(
        success: true,
        message: 'Telemetry received safely. Animal is within normal bounds.',
      );
    }

    // 5. Evaluate alert throttling / de-duplication
    final existingAlerts = await repository.getActiveAlerts();
    final throttling = _throttlingService.evaluate(
      targetId: animal?.id ?? sensor.animalId,
      zoneId: evalResult.zoneId,
      newLocation: location,
      activeAlerts: existingAlerts,
      eventTime: now,
    );

    if (throttling.wasThrottled && throttling.updatedAlert != null) {
      await repository.saveAlert(throttling.updatedAlert!);
      return TelemetryIngestionResult(
        success: true,
        alert: throttling.updatedAlert,
        wasThrottled: true,
        message: throttling.throttledReason ?? 'Alert throttled.',
      );
    }

    // 6. Spawn new WildlifeAlert
    final newAlert = WildlifeAlert(
      alertId: _uuid.v4(),
      sensorId: collarId,
      targetId: animal?.id ?? sensor.animalId,
      riskLevel: evalResult.riskLevel ?? AlertRiskLevel.medium,
      status: AlertStatus.active,
      triggerType: evalResult.triggerType ?? AlertTriggerType.geofenceBreach,
      title: evalResult.title,
      description: evalResult.description,
      triggeredAt: now,
      locationHistory: [location],
      currentLocation: location,
      zoneId: evalResult.zoneId,
      zoneName: evalResult.zoneName,
      lastUpdatedAt: now,
      targetSpecies: animal?.species,
      targetName: animal?.name,
    );

    await repository.saveAlert(newAlert);
    return TelemetryIngestionResult(
      success: true,
      alert: newAlert,
      wasThrottled: false,
      message: 'New wildlife alert triggered.',
    );
  }

  /// Ingests Camera Trap detection events.
  Future<TelemetryIngestionResult> ingestCameraTrapTrigger({
    required String cameraTrapId,
    required double batteryLevel,
    required String detectionTag,
    String? capturedImageUrl,
    String? targetAnimalId,
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();

    if (batteryLevel < 0.0 || batteryLevel > 100.0) {
      return TelemetryIngestionResult.failure(
        'Invalid battery level: $batteryLevel. Must be between 0% and 100%.',
      );
    }

    final sensor = await repository.getSensorById(cameraTrapId);
    if (sensor == null || sensor is! CameraTrap) {
      return TelemetryIngestionResult.failure(
        'Camera Trap with ID "$cameraTrapId" is not registered in the system.',
      );
    }

    Animal? animal;
    if (targetAnimalId != null) {
      animal = await repository.getAnimalById(targetAnimalId);
    }

    // Update sensor state
    final updatedSensor = sensor.copyWith(
      batteryLevel: batteryLevel,
      triggerTimestamp: now,
      lastActiveAt: now,
      simulatedDetectionTag: detectionTag,
      capturedImageUrl: capturedImageUrl,
      targetAnimalId: targetAnimalId,
    );
    await repository.updateSensor(updatedSensor);

    final strategy = _processorFactory.getStrategy(SensorType.cameraTrap);
    final zones = await repository.getHighRiskZones();
    final evalResult = strategy.evaluate(
      sensor: updatedSensor,
      zones: zones,
      animal: animal,
    );

    if (!evalResult.shouldAlert) {
      return const TelemetryIngestionResult(
        success: true,
        message: 'Camera trigger evaluated safely without threats.',
      );
    }

    // Camera threat alerts
    final newAlert = WildlifeAlert(
      alertId: _uuid.v4(),
      sensorId: cameraTrapId,
      targetId: targetAnimalId ?? cameraTrapId,
      riskLevel: evalResult.riskLevel ?? AlertRiskLevel.high,
      status: AlertStatus.active,
      triggerType: evalResult.triggerType ?? AlertTriggerType.cameraDetection,
      title: evalResult.title,
      description: evalResult.description,
      triggeredAt: now,
      currentLocation: sensor.cameraLocation,
      locationHistory: [sensor.cameraLocation],
      capturedImageUrl: capturedImageUrl,
      simulatedDetectionTag: detectionTag,
      lastUpdatedAt: now,
      targetSpecies: animal?.species,
      targetName: animal?.name,
    );

    await repository.saveAlert(newAlert);
    return TelemetryIngestionResult(
      success: true,
      alert: newAlert,
      wasThrottled: false,
      message: 'New camera trap alert triggered.',
    );
  }
}
