import 'package:flutter/foundation.dart';
import '../../domain/models/alert_response.dart';
import '../../domain/models/animal.dart';
import '../../domain/models/high_risk_zone.dart';
import '../../domain/models/sensor.dart';
import '../../domain/models/wildlife_alert.dart';
import '../../domain/repositories/wildlife_alert_repository.dart';
import '../../domain/services/alert_workflow_service.dart';
import '../../domain/services/sensor_telemetry_service.dart';
import '../../domain/services/wildlife_sensor_simulator.dart';

class WildlifeAlertController extends ChangeNotifier {
  WildlifeAlertController({
    required WildlifeAlertRepository repository,
    AlertWorkflowService? workflowService,
    SensorTelemetryService? telemetryService,
    WildlifeSensorSimulator? simulator,
  }) : _repository = repository,
       _workflowService =
           workflowService ?? AlertWorkflowService(repository: repository),
       _telemetryService =
           telemetryService ?? SensorTelemetryService(repository: repository) {
    _simulator =
        simulator ??
        WildlifeSensorSimulator(telemetryService: _telemetryService);
    loadData();
  }

  final WildlifeAlertRepository _repository;
  final AlertWorkflowService _workflowService;
  final SensorTelemetryService _telemetryService;
  late final WildlifeSensorSimulator _simulator;

  List<WildlifeAlert> _alerts = [];
  List<Animal> _animals = [];
  List<HighRiskZone> _zones = [];
  List<Sensor> _sensors = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOnline = true;

  AlertStatus? _filterStatus;
  AlertRiskLevel? _filterRisk;

  List<WildlifeAlert> get alerts => _alerts;
  List<Animal> get animals => _animals;
  List<HighRiskZone> get zones => _zones;
  List<Sensor> get sensors => _sensors;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOnline => _isOnline;
  AlertStatus? get filterStatus => _filterStatus;
  AlertRiskLevel? get filterRisk => _filterRisk;
  WildlifeSensorSimulator get simulator => _simulator;

  int get activeAlertsCount =>
      _alerts.where((a) => a.status == AlertStatus.active).length;
  int get acknowledgedAlertsCount =>
      _alerts.where((a) => a.status == AlertStatus.acknowledged).length;
  int get resolvedAlertsCount =>
      _alerts.where((a) => a.status == AlertStatus.resolved).length;
  int get highRiskActiveCount => _alerts
      .where(
        (a) =>
            a.status == AlertStatus.active &&
            a.riskLevel == AlertRiskLevel.high,
      )
      .length;

  List<WildlifeAlert> get filteredAlerts {
    var list = _alerts;
    if (_filterStatus != null) {
      list = list.where((a) => a.status == _filterStatus).toList();
    }
    if (_filterRisk != null) {
      list = list.where((a) => a.riskLevel == _filterRisk).toList();
    }
    return _workflowService.sortAlertsByPriority(list);
  }

  void setStatusFilter(AlertStatus? status) {
    _filterStatus = status;
    notifyListeners();
  }

  void setRiskFilter(AlertRiskLevel? risk) {
    _filterRisk = risk;
    notifyListeners();
  }

  void toggleOnlineStatus() {
    _isOnline = !_isOnline;
    notifyListeners();
  }

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _alerts = await _repository.getAlerts();
      _animals = await _repository.getAnimals();
      _zones = await _repository.getHighRiskZones();
      _sensors = await _repository.getSensors();
    } catch (e) {
      _errorMessage = 'Failed to load wildlife alerts: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<WildlifeAlert?> getAlertById(String alertId) async {
    try {
      return await _repository.getAlertById(alertId);
    } catch (_) {
      return null;
    }
  }

  Future<List<AlertResponse>> getResponsesForAlert(String alertId) async {
    try {
      return await _repository.getResponsesForAlert(alertId);
    } catch (_) {
      return [];
    }
  }

  Future<bool> acknowledgeAlert({
    required String alertId,
    required String rangerId,
    String? notes,
  }) async {
    try {
      await _workflowService.acknowledgeAlert(
        alertId: alertId,
        rangerId: rangerId,
        notes: notes,
      );
      await loadData();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resolveAlert({
    required String alertId,
    required String rangerId,
    required String actionTaken,
    required String observations,
    String? rangerName,
    List<String> photoUrls = const [],
    bool followUpRequired = false,
  }) async {
    try {
      await _workflowService.resolveAlert(
        alertId: alertId,
        rangerId: rangerId,
        actionTaken: actionTaken,
        observations: observations,
        rangerName: rangerName,
        photoUrls: photoUrls,
        followUpRequired: followUpRequired,
      );
      await loadData();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<SimulationScenarioResult> runSimulationScenario(
    Future<SimulationScenarioResult> Function(WildlifeSensorSimulator) action,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await action(_simulator);
      await loadData();
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
