import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/wildlife_alerts/domain/models/animal.dart';
import 'package:rangernet/features/wildlife_alerts/domain/models/geo_location.dart';
import 'package:rangernet/features/wildlife_alerts/domain/models/high_risk_zone.dart';
import 'package:rangernet/features/wildlife_alerts/domain/models/sensor.dart';
import 'package:rangernet/features/wildlife_alerts/domain/models/wildlife_alert.dart';
import 'package:rangernet/features/wildlife_alerts/domain/services/sensor_processing_strategy.dart';
import 'package:rangernet/features/wildlife_alerts/domain/services/sensor_processor_factory.dart';

void main() {
  group('SensorProcessingStrategy & Factory', () {
    final baseTime = DateTime.parse('2026-10-08T10:00:00Z');

    final testZone = HighRiskZone(
      zoneId: 'ZONE-01',
      name: 'Danger Buffer',
      severityLevel: ZoneSeverityLevel.high,
      boundaryPolygon: [
        GeoLocation(latitude: 6.3500, longitude: 81.4500, timestamp: baseTime),
        GeoLocation(latitude: 6.3700, longitude: 81.4500, timestamp: baseTime),
        GeoLocation(latitude: 6.3700, longitude: 81.4800, timestamp: baseTime),
        GeoLocation(latitude: 6.3500, longitude: 81.4800, timestamp: baseTime),
      ],
    );

    final elephant = const Animal(
      id: 'ANIMAL-01',
      name: 'Raja',
      species: 'Elephant',
      collarId: 'COLLAR-01',
      riskProfile: AnimalRiskProfile.high,
    );

    test('Factory: Resolves appropriate strategy based on sensor type', () {
      final factory = SensorProcessorFactory();

      final gpsStrategy = factory.getStrategy(SensorType.gpsCollar);
      expect(gpsStrategy, isA<GPSCollarProcessingStrategy>());

      final cameraStrategy = factory.getStrategy(SensorType.cameraTrap);
      expect(cameraStrategy, isA<CameraTrapProcessingStrategy>());
    });

    test('GPS Strategy: Flags HIGH risk alert when endangered animal enters high-risk zone', () {
      const strategy = GPSCollarProcessingStrategy();
      final collar = GPSCollar(
        id: 'COLLAR-01',
        batteryLevel: 85.0,
        status: SensorStatus.active,
        lastActiveAt: baseTime,
        animalId: elephant.id,
        currentLocation: GeoLocation(
          latitude: 6.3600, // Inside polygon
          longitude: 81.4650,
          timestamp: baseTime,
        ),
      );

      final result = strategy.evaluate(
        sensor: collar,
        zones: [testZone],
        animal: elephant,
      );

      expect(result.shouldAlert, isTrue);
      expect(result.riskLevel, equals(AlertRiskLevel.high));
      expect(result.triggerType, equals(AlertTriggerType.geofenceBreach));
      expect(result.zoneId, equals('ZONE-01'));
    });

    test('GPS Strategy: Safe coordinates generate no alert', () {
      const strategy = GPSCollarProcessingStrategy();
      final safeCollar = GPSCollar(
        id: 'COLLAR-01',
        batteryLevel: 85.0,
        status: SensorStatus.active,
        lastActiveAt: baseTime,
        animalId: elephant.id,
        currentLocation: GeoLocation(
          latitude: 6.5000, // Outside polygon
          longitude: 81.4650,
          timestamp: baseTime,
        ),
      );

      final result = strategy.evaluate(
        sensor: safeCollar,
        zones: [testZone],
        animal: elephant,
      );

      expect(result.shouldAlert, isFalse);
    });

    test('GPS Strategy: Critical battery (<= 10%) generates battery warning alert', () {
      const strategy = GPSCollarProcessingStrategy();
      final lowBatteryCollar = GPSCollar(
        id: 'COLLAR-01',
        batteryLevel: 8.0, // Critical
        status: SensorStatus.active,
        lastActiveAt: baseTime,
        animalId: elephant.id,
        currentLocation: GeoLocation(
          latitude: 6.5000,
          longitude: 81.4650,
          timestamp: baseTime,
        ),
      );

      final result = strategy.evaluate(
        sensor: lowBatteryCollar,
        zones: [testZone],
        animal: elephant,
      );

      expect(result.shouldAlert, isTrue);
      expect(result.triggerType, equals(AlertTriggerType.criticalBattery));
    });

    test('Camera Trap Strategy: Unauthorized human / weapon intrusion generates HIGH THREAT alert', () {
      const strategy = CameraTrapProcessingStrategy();
      final cam = CameraTrap(
        id: 'CAM-01',
        batteryLevel: 90.0,
        status: SensorStatus.active,
        lastActiveAt: baseTime,
        cameraLocation: GeoLocation(
          latitude: 6.4000,
          longitude: 81.4000,
          timestamp: baseTime,
        ),
        triggerTimestamp: baseTime,
        simulatedDetectionTag: 'POACHER_WEAPON_DETECTED',
      );

      final result = strategy.evaluate(sensor: cam, zones: [testZone]);

      expect(result.shouldAlert, isTrue);
      expect(result.riskLevel, equals(AlertRiskLevel.high));
      expect(result.triggerType, equals(AlertTriggerType.cameraDetection));
      expect(result.simulatedDetectionTag, equals('POACHER_WEAPON_DETECTED'));
    });

    test('Camera Trap Strategy: Distressed wildlife generates HIGH priority veterinary alert', () {
      const strategy = CameraTrapProcessingStrategy();
      final cam = CameraTrap(
        id: 'CAM-02',
        batteryLevel: 90.0,
        status: SensorStatus.active,
        lastActiveAt: baseTime,
        cameraLocation: GeoLocation(
          latitude: 6.4000,
          longitude: 81.4000,
          timestamp: baseTime,
        ),
        triggerTimestamp: baseTime,
        simulatedDetectionTag: 'DISTRESSED_INJURED_ANIMAL',
        targetAnimalId: elephant.id,
      );

      final result = strategy.evaluate(
        sensor: cam,
        zones: [testZone],
        animal: elephant,
      );

      expect(result.shouldAlert, isTrue);
      expect(result.riskLevel, equals(AlertRiskLevel.high));
      expect(result.triggerType, equals(AlertTriggerType.cameraDetection));
    });

    test('Camera Trap Strategy: NORMAL_PASSAGE or SAFE tag generates no alert', () {
      const strategy = CameraTrapProcessingStrategy();
      final cam = CameraTrap(
        id: 'CAM-03',
        batteryLevel: 90.0,
        status: SensorStatus.active,
        lastActiveAt: baseTime,
        cameraLocation: GeoLocation(
          latitude: 6.4000,
          longitude: 81.4000,
          timestamp: baseTime,
        ),
        triggerTimestamp: baseTime,
        simulatedDetectionTag: 'NORMAL_PASSAGE',
      );

      final result = strategy.evaluate(sensor: cam, zones: [testZone]);

      expect(result.shouldAlert, isFalse);
    });

    test('Strategy Type Safety: Throws ArgumentError if mismatched sensor passed', () {
      const gpsStrategy = GPSCollarProcessingStrategy();
      const cameraStrategy = CameraTrapProcessingStrategy();

      final cam = CameraTrap(
        id: 'CAM-01',
        batteryLevel: 90.0,
        status: SensorStatus.active,
        lastActiveAt: baseTime,
        cameraLocation: GeoLocation(
          latitude: 6.4000,
          longitude: 81.4000,
          timestamp: baseTime,
        ),
        triggerTimestamp: baseTime,
      );

      final collar = GPSCollar(
        id: 'COLLAR-01',
        batteryLevel: 85.0,
        status: SensorStatus.active,
        lastActiveAt: baseTime,
        animalId: elephant.id,
        currentLocation: GeoLocation(
          latitude: 6.3600,
          longitude: 81.4650,
          timestamp: baseTime,
        ),
      );

      expect(() => gpsStrategy.evaluate(sensor: cam, zones: []), throwsArgumentError);
      expect(() => cameraStrategy.evaluate(sensor: collar, zones: []), throwsArgumentError);
    });
  });
}
