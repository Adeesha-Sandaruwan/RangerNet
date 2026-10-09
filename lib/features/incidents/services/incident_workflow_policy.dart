// Keeps incident validation and status-change rules in one place.
import '../models/incident_report.dart';

/// UC02 validation rules only, kept separate from screens and database code.
class IncidentWorkflowPolicy {
  const IncidentWorkflowPolicy._();

  static const managerActions = {
    IncidentWorkflowStatus.underReview,
    IncidentWorkflowStatus.followUpRequired,
    IncidentWorkflowStatus.monitoring,
    IncidentWorkflowStatus.closed,
    IncidentWorkflowStatus.duplicate,
    IncidentWorkflowStatus.rejected,
  };

  static void validateAssignmentSelection(
    IncidentAssignmentKind kind,
    int rangerCount,
  ) {
    final valid = switch (kind) {
      IncidentAssignmentKind.ranger => rangerCount == 1,
      IncidentAssignmentKind.responseTeam => rangerCount >= 2,
    };
    if (!valid) {
      throw ArgumentError('Select one ranger or at least two team members.');
    }
  }

  static void ensureIncidentIsOpen(IncidentWorkflowStatus currentStatus) {
    if (currentStatus == IncidentWorkflowStatus.closed) {
      throw StateError('This incident is already closed.');
    }
  }

  static void validateReview({
    required IncidentWorkflowStatus currentStatus,
    required IncidentSeverity severity,
    required String note,
  }) {
    ensureIncidentIsOpen(currentStatus);
    if (severity == IncidentSeverity.critical && note.trim().isEmpty) {
      throw ArgumentError('Add the reason for marking this incident critical.');
    }
  }

  static void validateManagerTransition({
    required IncidentWorkflowStatus currentStatus,
    required IncidentWorkflowStatus nextStatus,
    required String note,
    IncidentSeverity? severity,
  }) {
    if (!managerActions.contains(nextStatus)) {
      throw ArgumentError('That status change is not a manager action.');
    }
    ensureIncidentIsOpen(currentStatus);
    if (nextStatus == IncidentWorkflowStatus.closed &&
        currentStatus != IncidentWorkflowStatus.resolved) {
      throw StateError(
        'A responder must submit the incident as resolved before manager closure.',
      );
    }
    final needsReason = {
      IncidentWorkflowStatus.followUpRequired,
      IncidentWorkflowStatus.monitoring,
      IncidentWorkflowStatus.duplicate,
      IncidentWorkflowStatus.rejected,
      IncidentWorkflowStatus.closed,
    }.contains(nextStatus);
    if ((needsReason || severity == IncidentSeverity.critical) &&
        note.trim().isEmpty) {
      throw ArgumentError('Add a reason for this incident action.');
    }
  }

  static void validateResponderUpdate({
    required String note,
    required IncidentWorkflowStatus status,
  }) {
    if (note.trim().length < 5) {
      throw ArgumentError(
        'Add at least five characters describing the action.',
      );
    }
    if (status != IncidentWorkflowStatus.responseInProgress &&
        status != IncidentWorkflowStatus.resolved) {
      throw ArgumentError('Choose in progress or resolved.');
    }
  }
}
