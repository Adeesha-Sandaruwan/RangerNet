import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/wildlife_alerts/data/repositories/wildlife_alert_repository_impl.dart';
import 'package:rangernet/features/wildlife_alerts/domain/models/wildlife_alert.dart';
import 'package:rangernet/features/wildlife_alerts/domain/services/sensor_telemetry_service.dart';

void main() {
  group('SensorTelemetryService Ingestion Pipeline', () {
    late WildlifeAlertRepositoryImpl repository;
    late SensorTelemetryService service;

    setUp(() {
      repository = WildlifeAlertRepositoryImpl();
      service = SensorTelemetryService(repository: repository);
    });

    test('Positive: Ingesting GPS telemetry that breaches high-risk zone spawns new WildlifeAlert', () async {
      final result = await service.ingestGpsTelemetry(
        collarId: 'COLLAR-001', // Raja the Elephant
        latitude: 6.3650, // Inside Southern Boundary zone
        longitude: 81.4650,
        altitude: 48.0,
        batteryLevel: 85.0,
      );

      expect(result.success, isTrue);
      expect(result.alert, isNotNull);
      expect(result.wasThrottled, isFalse);
      expect(result.alert?.status, equals(AlertStatus.active));
      expect(result.alert?.riskLevel, equals(AlertRiskLevel.high));
      expect(result.alert?.triggerType, equals(AlertTriggerType.geofenceBreach));
    });

    test('Edge: Rapid pings for same collar in risk zone triggers throttling and appends history', () async {
      final now = DateTime.now();

      // Ping 1: Spawns new alert
      final ping1 = await service.ingestGpsTelemetry(
        collarId: 'COLLAR-002', // Maya
        latitude: 6.3650, // Inside Southern Boundary
        longitude: 81.4650,
        batteryLevel: 92.0,
        timestamp: now,
      );
      expect(ping1.success, isTrue);
      expect(ping1.wasThrottled, isFalse);
      final alertId = ping1.alert!.alertId;

      // Ping 2: Sent 2 minutes later -> Should be throttled and appended
      final ping2 = await service.ingestGpsTelemetry(
        collarId: 'COLLAR-002',
        latitude: 6.3660,
        longitude: 81.4660,
        batteryLevel: 91.9,
        timestamp: now.add(const Duration(minutes: 2)),
      );

      expect(ping2.success, isTrue);
      expect(ping2.wasThrottled, isTrue);
      expect(ping2.alert?.alertId, equals(alertId));
      expect(ping2.alert?.locationHistory.length, equals(2));
    });

    test('Negative: Invalid GPS coordinates are rejected with descriptive error message', () async {
      final result = await service.ingestGpsTelemetry(
        collarId: 'COLLAR-001',
        latitude: 95.0, // Invalid: > 90
        longitude: 81.4650,
        batteryLevel: 80.0,
      );

      expect(result.success, isFalse);
      expect(result.alert, isNull);
      expect(result.message, contains('Invalid GPS coordinates'));
    });

    test('Negative: Out of bounds battery level is rejected', () async {
      final result = await service.ingestGpsTelemetry(
        collarId: 'COLLAR-001',
        latitude: 6.3650,
        longitude: 81.4650,
        batteryLevel: 105.0, // Invalid: > 100
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Invalid battery level'));
    });

    test('Negative: Unregistered sensor collar returns failure', () async {
      final result = await service.ingestGpsTelemetry(
        collarId: 'NON_EXISTENT_COLLAR_999',
        latitude: 6.3650,
        longitude: 81.4650,
        batteryLevel: 80.0,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('not registered'));
    });

    test('Positive: Ingesting Camera Trap threat creates camera detection alert', () async {
      final result = await service.ingestCameraTrapTrigger(
        cameraTrapId: 'CAM-TRAP-101',
        batteryLevel: 85.0,
        detectionTag: 'POACHER_WEAPON_DETECTED',
        capturedImageUrl: 'https://example.com/poacher.jpg',
      );

      expect(result.success, isTrue);
      expect(result.alert, isNotNull);
      expect(result.alert?.triggerType, equals(AlertTriggerType.cameraDetection));
      expect(result.alert?.riskLevel, equals(AlertRiskLevel.high));
      expect(result.alert?.simulatedDetectionTag, equals('POACHER_WEAPON_DETECTED'));
    });

    test('Positive: Normal camera passage creates no threat alert', () async {
      final result = await service.ingestCameraTrapTrigger(
        cameraTrapId: 'CAM-TRAP-101',
        batteryLevel: 85.0,
        detectionTag: 'NORMAL_PASSAGE',
      );

      expect(result.success, isTrue);
      expect(result.alert, isNull);
      expect(result.message, contains('safely without threats'));
    });
  });
}
