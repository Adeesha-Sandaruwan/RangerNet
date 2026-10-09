// Small contracts that screens use instead of depending on Firebase directly.
import 'incident_report.dart';
import 'incident_timeline_event.dart';
import 'ranger_profile.dart';

/// Operations needed by manager screens only (Interface Segregation).
///
/// The screen depends on this contract (Dependency Inversion). A new
/// implementation can be added without changing the screen (Open/Closed).
/// Implementations must keep the same behavior so they can replace each other
/// safely (Liskov Substitution).
abstract interface class IncidentManagerGateway {
  Future<List<IncidentReport>> loadAllIncidents();
  Stream<List<IncidentReport>> watchAllIncidents();
  Future<IncidentReport> loadIncident(String incidentId);
  Future<List<RangerProfile>> loadActiveRangers();
  Future<List<IncidentTimelineEvent>> loadTimeline(String incidentId);
  Future<List<IncidentEvidence>> loadIncidentEvidence(String incidentId);
  Future<void> reviewIncident({
    required String incidentId,
    required IncidentSeverity severity,
    required String managerName,
    String note,
  });
  Future<void> assignResponders({
    required String incidentId,
    required IncidentAssignmentKind kind,
    required List<RangerProfile> responders,
    required String managerName,
  });
  Future<void> managerTransition({
    required String incidentId,
    required IncidentWorkflowStatus status,
    required String managerName,
    required String note,
    IncidentSeverity? severity,
  });
}

/// Operations needed by responder screens only (Interface Segregation).
///
/// Keeping this separate means responder screens do not receive manager-only
/// actions such as assigning a team or closing an incident.
abstract interface class IncidentResponderGateway {
  Future<List<IncidentReport>> loadAssignedIncidents(String rangerId);
  Stream<List<IncidentReport>> watchAssignedIncidents(String rangerId);
  Future<List<IncidentTimelineEvent>> loadTimeline(String incidentId);
  Future<List<IncidentEvidence>> loadIncidentEvidence(String incidentId);
  Future<void> recordResponderUpdate({
    required String incidentId,
    required String responderName,
    required String note,
    required IncidentWorkflowStatus status,
    required List<IncidentEvidence> evidence,
  });
}
