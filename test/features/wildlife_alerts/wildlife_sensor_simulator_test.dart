import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/wildlife_alerts/data/repositories/wildlife_alert_repository_impl.dart';
import 'package:rangernet/features/wildlife_alerts/domain/models/wildlife_alert.dart';
import 'package:rangernet/features/wildlife_alerts/domain/services/sensor_telemetry_service.dart';
import 'package:rangernet/features/wildlife_alerts/domain/services/wildlife_sensor_simulator.dart';

void main() {
  group('WildlifeSensorSimulator End-to-End Scenarios', () {
    late WildlifeAlertRepositoryImpl repository;
    late SensorTelemetryService telemetryService;
    late WildlifeSensorSimulator simulator;

    setUp(() {
      repository = WildlifeAlertRepositoryImpl();
      telemetryService = SensorTelemetryService(repository: repository);
      simulator = WildlifeSensorSimulator(telemetryService: telemetryService);
    });

    test('Scenario 1: Elephant breaching high-risk zone spawns HIGH risk alert', () async {
      final scenario = await simulator.simulateElephantBreachingZone();

      expect(scenario.telemetryResults.length, equals(1));
      final res = scenario.telemetryResults.first;
      expect(res.success, isTrue);
      expect(res.alert, isNotNull);
      expect(res.alert?.riskLevel, equals(AlertRiskLevel.high));
      expect(res.alert?.zoneName, contains('Southern Boundary'));
    });

    test('Scenario 2: Safe range movement produces successful telemetry without alert', () async {
      final scenario = await simulator.simulateSafeMovement();

      expect(scenario.telemetryResults.length, equals(1));
      final res = scenario.telemetryResults.first;
      expect(res.success, isTrue);
      expect(res.alert, isNull);
    });

    test('Scenario 3: Exact geofence boundary test produces alert with boundary note', () async {
      final scenario = await simulator.simulateBoundaryEdgeTest();

      expect(scenario.telemetryResults.length, equals(1));
      final res = scenario.telemetryResults.first;
      expect(res.success, isTrue);
      expect(res.alert, isNotNull);
      expect(res.alert?.title, contains('Exact Boundary Edge'));
    });

    test('Scenario 4: Rapid successive pings demonstrate throttling and history append', () async {
      final scenario = await simulator.simulateRapidThrottledPings();

      expect(scenario.telemetryResults.length, equals(3));
      // Ping 1
      expect(scenario.telemetryResults[0].success, isTrue);
      expect(scenario.telemetryResults[0].wasThrottled, isFalse);
      expect(scenario.telemetryResults[0].alert, isNotNull);

      // Ping 2
      expect(scenario.telemetryResults[1].success, isTrue);
      expect(scenario.telemetryResults[1].wasThrottled, isTrue);

      // Ping 3
      expect(scenario.telemetryResults[2].success, isTrue);
      expect(scenario.telemetryResults[2].wasThrottled, isTrue);

      // Verify the alert now contains all 3 location pings in its history
      final alertId = scenario.telemetryResults[0].alert!.alertId;
      final storedAlert = await repository.getAlertById(alertId);
      expect(storedAlert?.locationHistory.length, equals(3));
    });

    test('Scenario 5: Poacher camera trap generates HIGH threat alert', () async {
      final scenario = await simulator.simulatePoacherCameraTrap();

      expect(scenario.telemetryResults.length, equals(1));
      final res = scenario.telemetryResults.first;
      expect(res.success, isTrue);
      expect(res.alert, isNotNull);
      expect(res.alert?.triggerType, equals(AlertTriggerType.cameraDetection));
      expect(res.alert?.riskLevel, equals(AlertRiskLevel.high));
      expect(res.alert?.simulatedDetectionTag, contains('POACHER'));
    });

    test('Scenario 6: Distressed animal camera trap generates veterinary intervention alert', () async {
      final scenario = await simulator.simulateDistressedAnimalCameraTrap();

      expect(scenario.telemetryResults.length, equals(1));
      final res = scenario.telemetryResults.first;
      expect(res.success, isTrue);
      expect(res.alert, isNotNull);
      expect(res.alert?.triggerType, equals(AlertTriggerType.cameraDetection));
      expect(res.alert?.simulatedDetectionTag, contains('DISTRESSED'));
    });

    test('Scenario 7: Critical battery generates hardware maintenance alert', () async {
      final scenario = await simulator.simulateCriticalBattery();

      expect(scenario.telemetryResults.length, equals(1));
      final res = scenario.telemetryResults.first;
      expect(res.success, isTrue);
      expect(res.alert, isNotNull);
      expect(res.alert?.triggerType, equals(AlertTriggerType.criticalBattery));
    });
  });
}
