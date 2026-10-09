import '../models/alert_response.dart';
import '../models/animal.dart';
import '../models/high_risk_zone.dart';
import '../models/sensor.dart';
import '../models/wildlife_alert.dart';

/// Repository contract for wildlife alerts, sensor telemetry, and conservation zones.
abstract class WildlifeAlertRepository {
  /// Stream or load all alerts.
  Future<List<WildlifeAlert>> getAlerts({
    AlertStatus? filterStatus,
    AlertRiskLevel? filterRisk,
  });

  /// Loads active & acknowledged alerts sorted by priority (HIGH > MEDIUM > LOW, then newest first).
  Future<List<WildlifeAlert>> getActiveAlerts();

  /// Gets a specific alert by id.
  Future<WildlifeAlert?> getAlertById(String alertId);

  /// Saves a new alert or updates an existing alert.
  Future<void> saveAlert(WildlifeAlert alert);

  /// Updates an alert's status (e.g. ACTIVE -> ACKNOWLEDGED -> RESOLVED).
  Future<void> updateAlertStatus({
    required String alertId,
    required AlertStatus newStatus,
    required String rangerId,
    String? notes,
  });

  /// Records a formal response resolution for an alert.
  Future<void> addAlertResponse(AlertResponse response);

  /// Retrieves all response actions recorded for a given alert.
  Future<List<AlertResponse>> getResponsesForAlert(String alertId);

  /// Loads all tracked animals.
  Future<List<Animal>> getAnimals();

  /// Loads a specific animal by id or collar id.
  Future<Animal?> getAnimalById(String animalId);
  Future<Animal?> getAnimalByCollarId(String collarId);

  /// Loads active high-risk zones.
  Future<List<HighRiskZone>> getHighRiskZones();

  /// Loads registered sensors.
  Future<List<Sensor>> getSensors();

  /// Loads a sensor by id.
  Future<Sensor?> getSensorById(String sensorId);

  /// Updates sensor state (location, battery, status).
  Future<void> updateSensor(Sensor sensor);
}
