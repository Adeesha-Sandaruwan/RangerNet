import 'package:uuid/uuid.dart';
import '../models/alert_response.dart';
import '../models/wildlife_alert.dart';
import '../repositories/wildlife_alert_repository.dart';

class InvalidAlertTransitionException implements Exception {
  InvalidAlertTransitionException(this.message);
  final String message;

  @override
  String toString() => 'InvalidAlertTransitionException: $message';
}

/// Service governing ranger workflows and alert lifecycle transitions.
class AlertWorkflowService {
  AlertWorkflowService({required this.repository, Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final WildlifeAlertRepository repository;
  final Uuid _uuid;

  /// Retrieves all active and acknowledged alerts sorted by priority (HIGH > MEDIUM > LOW, then newest first).
  Future<List<WildlifeAlert>> getSortedActiveAlerts() async {
    final alerts = await repository.getActiveAlerts();
    return sortAlertsByPriority(alerts);
  }

  /// Sorts alerts according to conservation urgency:
  /// 1. Risk level weight (HIGH = 3, MEDIUM = 2, LOW = 1)
  /// 2. Then triggeredAt descending (most recent first)
  List<WildlifeAlert> sortAlertsByPriority(List<WildlifeAlert> alerts) {
    final sorted = List<WildlifeAlert>.from(alerts);
    sorted.sort((a, b) {
      final riskComparison = b.riskLevel.priorityOrder.compareTo(
        a.riskLevel.priorityOrder,
      );
      if (riskComparison != 0) {
        return riskComparison;
      }
      return b.triggeredAt.compareTo(a.triggeredAt);
    });
    return sorted;
  }

  /// Ranger acknowledges an active alert.
  /// Transition: ACTIVE -> ACKNOWLEDGED
  Future<WildlifeAlert> acknowledgeAlert({
    required String alertId,
    required String rangerId,
    String? notes,
  }) async {
    final alert = await repository.getAlertById(alertId);
    if (alert == null) {
      throw StateError('Alert with ID "$alertId" does not exist.');
    }

    if (alert.status == AlertStatus.resolved) {
      throw InvalidAlertTransitionException(
        'Cannot acknowledge an alert that has already been resolved.',
      );
    }

    if (alert.status == AlertStatus.acknowledged) {
      throw InvalidAlertTransitionException(
        'Alert is already in ACKNOWLEDGED status.',
      );
    }

    final updated = alert.copyWith(
      status: AlertStatus.acknowledged,
      acknowledgedAt: DateTime.now(),
      acknowledgedByRangerId: rangerId,
      responseNotes: notes ?? alert.responseNotes,
      lastUpdatedAt: DateTime.now(),
    );

    await repository.saveAlert(updated);
    return updated;
  }

  /// Ranger resolves an alert and submits response details.
  /// Transition: ACKNOWLEDGED -> RESOLVED (or ACTIVE -> RESOLVED with explicit acknowledgement)
  Future<AlertResponse> resolveAlert({
    required String alertId,
    required String rangerId,
    required String actionTaken,
    required String observations,
    String? rangerName,
    List<String> photoUrls = const [],
    bool followUpRequired = false,
  }) async {
    if (actionTaken.trim().isEmpty) {
      throw ArgumentError('Action taken is required to resolve an alert.');
    }

    final alert = await repository.getAlertById(alertId);
    if (alert == null) {
      throw StateError('Alert with ID "$alertId" does not exist.');
    }

    if (alert.status == AlertStatus.resolved) {
      throw InvalidAlertTransitionException('Alert has already been resolved.');
    }

    final now = DateTime.now();

    // 1. Create the response audit record
    final response = AlertResponse(
      responseId: _uuid.v4(),
      alertId: alertId,
      rangerId: rangerId,
      rangerName: rangerName,
      actionTaken: actionTaken.trim(),
      observations: observations.trim(),
      timestamp: now,
      photoUrls: photoUrls,
      followUpRequired: followUpRequired,
    );

    // 2. Transition alert status to RESOLVED
    final updatedAlert = alert.copyWith(
      status: AlertStatus.resolved,
      resolvedAt: now,
      resolvedByRangerId: rangerId,
      responseNotes:
          'Action: ${actionTaken.trim()}\nObservations: ${observations.trim()}',
      lastUpdatedAt: now,
    );

    await repository.saveAlert(updatedAlert);
    await repository.addAlertResponse(response);

    return response;
  }
}
