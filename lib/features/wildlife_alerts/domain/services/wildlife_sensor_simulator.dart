import 'dart:async';
import 'sensor_telemetry_service.dart';

class SimulationScenarioResult {
  const SimulationScenarioResult({
    required this.scenarioName,
    required this.description,
    required this.telemetryResults,
  });

  final String scenarioName;
  final String description;
  final List<TelemetryIngestionResult> telemetryResults;
}

/// Simulator to trigger mock wildlife collar GPS movements and camera trap detections.
/// Enables end-to-end testing and interactive demonstrations without live field hardware.
class WildlifeSensorSimulator {
  WildlifeSensorSimulator({required this.telemetryService});

  final SensorTelemetryService telemetryService;

  /// Scenario 1: Raja (Elephant) enters the high-risk Southern Boundary Buffer Zone.
  /// Expected: Generates a HIGH priority geofence breach alert.
  Future<SimulationScenarioResult> simulateElephantBreachingZone() async {
    final now = DateTime.now();
    final result = await telemetryService.ingestGpsTelemetry(
      collarId: 'COLLAR-001',
      latitude: 6.3650, // Inside Southern Boundary (6.35 - 6.37, 81.45 - 81.48)
      longitude: 81.4650,
      altitude: 48.0,
      batteryLevel: 85.0,
      timestamp: now,
    );

    return SimulationScenarioResult(
      scenarioName: 'Geofence Breach (Elephant in Risk Zone)',
      description:
          'Simulated Tusker Raja crossing perimeter fence into Southern agricultural buffer zone.',
      telemetryResults: [result],
    );
  }

  /// Scenario 2: Elephant moving safely inside sanctuary interior.
  /// Expected: Ingested successfully, NO alert created.
  Future<SimulationScenarioResult> simulateSafeMovement() async {
    final now = DateTime.now();
    final result = await telemetryService.ingestGpsTelemetry(
      collarId: 'COLLAR-001',
      latitude: 6.4650, // Far from risk zones in central forest reserve
      longitude: 81.4200,
      altitude: 72.0,
      batteryLevel: 84.0,
      timestamp: now,
    );

    return SimulationScenarioResult(
      scenarioName: 'Safe Range Movement',
      description:
          'Simulated elephant feeding safely within sanctuary core sector.',
      telemetryResults: [result],
    );
  }

  /// Scenario 3: Animal moving exactly on geofence boundary edge.
  /// Expected: Boundary condition evaluated and alert flagged with exact boundary notice.
  Future<SimulationScenarioResult> simulateBoundaryEdgeTest() async {
    final now = DateTime.now();
    // Exactly on polygon segment: latitude 6.3500, longitude 81.4600
    final result = await telemetryService.ingestGpsTelemetry(
      collarId: 'COLLAR-001',
      latitude: 6.3500,
      longitude: 81.4600,
      altitude: 45.0,
      batteryLevel: 83.0,
      timestamp: now,
    );

    return SimulationScenarioResult(
      scenarioName: 'Exact Geofence Boundary Test',
      description:
          'Collar positioned exactly on polygon perimeter boundary segment.',
      telemetryResults: [result],
    );
  }

  /// Scenario 4: Rapid successive GPS pings within cooldown window.
  /// Expected: 1st ping triggers alert; 2nd and 3rd pings are THROTTLED and appended to locationHistory.
  Future<SimulationScenarioResult> simulateRapidThrottledPings() async {
    final baseTime = DateTime.now();
    final results = <TelemetryIngestionResult>[];

    // Ping 1 (T=0)
    final ping1 = await telemetryService.ingestGpsTelemetry(
      collarId: 'COLLAR-001',
      latitude: 6.3630,
      longitude: 81.4620,
      altitude: 46.0,
      batteryLevel: 82.0,
      timestamp: baseTime,
    );
    results.add(ping1);

    // Ping 2 (T+1 min)
    final ping2 = await telemetryService.ingestGpsTelemetry(
      collarId: 'COLLAR-001',
      latitude: 6.3640,
      longitude: 81.4630,
      altitude: 47.0,
      batteryLevel: 81.9,
      timestamp: baseTime.add(const Duration(minutes: 1)),
    );
    results.add(ping2);

    // Ping 3 (T+3 min)
    final ping3 = await telemetryService.ingestGpsTelemetry(
      collarId: 'COLLAR-001',
      latitude: 6.3650,
      longitude: 81.4640,
      altitude: 47.5,
      batteryLevel: 81.8,
      timestamp: baseTime.add(const Duration(minutes: 3)),
    );
    results.add(ping3);

    return SimulationScenarioResult(
      scenarioName: 'Throttling & De-duplication (Rapid Pings)',
      description:
          '3 rapid pings sent 1-3 minutes apart. First creates alert, remaining 2 are throttled and appended as location history breadcrumbs.',
      telemetryResults: results,
    );
  }

  /// Scenario 5: Camera Trap flags armed poachers / human trespassers.
  /// Expected: Generates HIGH THREAT alert with captured image and detection tag.
  Future<SimulationScenarioResult> simulatePoacherCameraTrap() async {
    final now = DateTime.now();
    final result = await telemetryService.ingestCameraTrapTrigger(
      cameraTrapId: 'CAM-TRAP-101',
      batteryLevel: 79.0,
      detectionTag: 'POACHER_WEAPON_DETECTED',
      capturedImageUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=600&q=80',
      timestamp: now,
    );

    return SimulationScenarioResult(
      scenarioName: 'Camera Trap: Poaching Infiltration',
      description:
          'Camera Trap detected unauthorized armed intruder near river trail.',
      telemetryResults: [result],
    );
  }

  /// Scenario 6: Camera Trap flags distressed/injured animal.
  /// Expected: Generates HIGH priority veterinary alert.
  Future<SimulationScenarioResult> simulateDistressedAnimalCameraTrap() async {
    final now = DateTime.now();
    final result = await telemetryService.ingestCameraTrapTrigger(
      cameraTrapId: 'CAM-TRAP-102',
      batteryLevel: 87.0,
      detectionTag: 'DISTRESSED_INJURED_ANIMAL',
      targetAnimalId: 'ANIMAL-LEO-02',
      capturedImageUrl:
          'https://images.unsplash.com/photo-1564349683136-77e08dba1ef7?auto=format&fit=crop&w=600&q=80',
      timestamp: now,
    );

    return SimulationScenarioResult(
      scenarioName: 'Camera Trap: Distressed Wildlife',
      description:
          'Camera Trap tagged distressed leopard requiring field intervention.',
      telemetryResults: [result],
    );
  }

  /// Scenario 7: Collar battery drops to critical level (<= 10%).
  /// Expected: Generates critical battery alert.
  Future<SimulationScenarioResult> simulateCriticalBattery() async {
    final now = DateTime.now();
    final result = await telemetryService.ingestGpsTelemetry(
      collarId: 'COLLAR-003',
      latitude: 6.4500,
      longitude: 81.3500,
      altitude: 35.0,
      batteryLevel: 8.5, // <= 10%
      timestamp: now,
    );

    return SimulationScenarioResult(
      scenarioName: 'Critical Battery Warning',
      description:
          'Collar battery dropped to 8.5%, triggering hardware maintenance alert.',
      telemetryResults: [result],
    );
  }
}
