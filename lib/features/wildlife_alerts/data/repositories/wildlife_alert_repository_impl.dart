import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/alert_response.dart';
import '../../domain/models/animal.dart';
import '../../domain/models/high_risk_zone.dart';
import '../../domain/models/sensor.dart';
import '../../domain/models/wildlife_alert.dart';
import '../../domain/repositories/wildlife_alert_repository.dart';
import '../seed/wildlife_seed_data.dart';

/// Implementation of WildlifeAlertRepository with in-memory caching and optional Firestore synchronization.
class WildlifeAlertRepositoryImpl implements WildlifeAlertRepository {
  WildlifeAlertRepositoryImpl({this.firestore}) {
    _initializeSeedData();
  }

  final FirebaseFirestore? firestore;

  final Map<String, WildlifeAlert> _alerts = {};
  final Map<String, List<AlertResponse>> _responses = {};
  final Map<String, Animal> _animals = {};
  final Map<String, HighRiskZone> _zones = {};
  final Map<String, Sensor> _sensors = {};

  void _initializeSeedData() {
    for (final zone in WildlifeSeedData.initialZones) {
      _zones[zone.zoneId] = zone;
    }
    for (final animal in WildlifeSeedData.initialAnimals) {
      _animals[animal.id] = animal;
    }
    for (final sensor in WildlifeSeedData.initialSensors) {
      _sensors[sensor.id] = sensor;
    }
    for (final alert in WildlifeSeedData.initialAlerts) {
      _alerts[alert.alertId] = alert;
    }
    for (final response in WildlifeSeedData.initialResponses) {
      _responses.putIfAbsent(response.alertId, () => []).add(response);
    }
  }

  @override
  Future<List<WildlifeAlert>> getAlerts({
    AlertStatus? filterStatus,
    AlertRiskLevel? filterRisk,
  }) async {
    var results = _alerts.values.toList();
    if (filterStatus != null) {
      results = results.where((a) => a.status == filterStatus).toList();
    }
    if (filterRisk != null) {
      results = results.where((a) => a.riskLevel == filterRisk).toList();
    }
    results.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
    return results;
  }

  @override
  Future<List<WildlifeAlert>> getActiveAlerts() async {
    final active = _alerts.values
        .where((a) => a.status != AlertStatus.resolved)
        .toList();
    active.sort((a, b) {
      final riskComp =
          b.riskLevel.priorityOrder.compareTo(a.riskLevel.priorityOrder);
      if (riskComp != 0) return riskComp;
      return b.triggeredAt.compareTo(a.triggeredAt);
    });
    return active;
  }

  @override
  Future<WildlifeAlert?> getAlertById(String alertId) async {
    return _alerts[alertId];
  }

  @override
  Future<void> saveAlert(WildlifeAlert alert) async {
    _alerts[alert.alertId] = alert;

    if (firestore != null) {
      try {
        await firestore!
            .collection('wildlife_alerts')
            .doc(alert.alertId)
            .set(alert.toJson(), SetOptions(merge: true));
      } catch (_) {
        // Silently fallback to local store if Firestore is unavailable
      }
    }
  }

  @override
  Future<void> updateAlertStatus({
    required String alertId,
    required AlertStatus newStatus,
    required String rangerId,
    String? notes,
  }) async {
    final existing = _alerts[alertId];
    if (existing == null) {
      throw StateError('Alert not found: $alertId');
    }

    final now = DateTime.now();
    final updated = existing.copyWith(
      status: newStatus,
      lastUpdatedAt: now,
      acknowledgedAt:
          newStatus == AlertStatus.acknowledged ? now : existing.acknowledgedAt,
      acknowledgedByRangerId: newStatus == AlertStatus.acknowledged
          ? rangerId
          : existing.acknowledgedByRangerId,
      resolvedAt:
          newStatus == AlertStatus.resolved ? now : existing.resolvedAt,
      resolvedByRangerId:
          newStatus == AlertStatus.resolved ? rangerId : existing.resolvedByRangerId,
      responseNotes: notes ?? existing.responseNotes,
    );

    await saveAlert(updated);
  }

  @override
  Future<void> addAlertResponse(AlertResponse response) async {
    _responses.putIfAbsent(response.alertId, () => []).add(response);

    if (firestore != null) {
      try {
        await firestore!
            .collection('wildlife_alert_responses')
            .doc(response.responseId)
            .set(response.toJson());
      } catch (_) {
        // Silently fallback to local store
      }
    }
  }

  @override
  Future<List<AlertResponse>> getResponsesForAlert(String alertId) async {
    return List<AlertResponse>.from(_responses[alertId] ?? []);
  }

  @override
  Future<List<Animal>> getAnimals() async {
    return _animals.values.toList();
  }

  @override
  Future<Animal?> getAnimalById(String animalId) async {
    return _animals[animalId];
  }

  @override
  Future<Animal?> getAnimalByCollarId(String collarId) async {
    return _animals.values.cast<Animal?>().firstWhere(
          (a) => a?.collarId == collarId,
          orElse: () => null,
        );
  }

  @override
  Future<List<HighRiskZone>> getHighRiskZones() async {
    return _zones.values.toList();
  }

  @override
  Future<List<Sensor>> getSensors() async {
    return _sensors.values.toList();
  }

  @override
  Future<Sensor?> getSensorById(String sensorId) async {
    return _sensors[sensorId];
  }

  @override
  Future<void> updateSensor(Sensor sensor) async {
    _sensors[sensor.id] = sensor;
  }
}
