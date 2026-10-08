import 'patrol.dart';
import 'patrol_records.dart';

class PatrolWorkflowPolicy {
  const PatrolWorkflowPolicy._();

  static void validateTransition({
    required PatrolStatus current,
    required PatrolStatus next,
    String? reason,
  }) {
    final allowed = switch (current) {
      PatrolStatus.assigned => {PatrolStatus.inProgress, PatrolStatus.aborted},
      PatrolStatus.inProgress => {
        PatrolStatus.paused,
        PatrolStatus.completedPendingSync,
        PatrolStatus.incomplete,
        PatrolStatus.aborted,
        PatrolStatus.interrupted,
      },
      PatrolStatus.paused => {
        PatrolStatus.inProgress,
        PatrolStatus.completedPendingSync,
        PatrolStatus.incomplete,
        PatrolStatus.aborted,
        PatrolStatus.interrupted,
      },
      PatrolStatus.interrupted => {
        PatrolStatus.inProgress,
        PatrolStatus.paused,
        PatrolStatus.incomplete,
        PatrolStatus.aborted,
      },
      PatrolStatus.completedPendingSync => {PatrolStatus.completedSynced},
      PatrolStatus.completedSynced ||
      PatrolStatus.incomplete ||
      PatrolStatus.aborted => const <PatrolStatus>{},
    };

    if (!allowed.contains(next)) {
      throw StateError('Cannot change patrol status from $current to $next.');
    }
    if (_requiresReason(next) && (reason == null || reason.trim().isEmpty)) {
      throw ArgumentError('A reason is required when moving to $next.');
    }
  }

  static void ensureCanRecord(Patrol patrol, {required String recordType}) {
    if (patrol.status != PatrolStatus.inProgress &&
        patrol.status != PatrolStatus.paused) {
      throw StateError(
        'Cannot add $recordType while patrol is ${patrol.status}.',
      );
    }
  }

  static void validateAssignment(Patrol patrol) {
    if (patrol.status != PatrolStatus.assigned ||
        patrol.startedAt != null ||
        patrol.endedAt != null) {
      throw StateError('Only an unstarted assigned patrol can be saved.');
    }
  }

  static void validateCompletionSync(Patrol patrol) {
    if (patrol.status != PatrolStatus.completedPendingSync) {
      throw StateError(
        'Only a completed patrol pending synchronization can be marked synced.',
      );
    }
  }

  static bool _requiresReason(PatrolStatus status) =>
      status == PatrolStatus.incomplete ||
      status == PatrolStatus.aborted ||
      status == PatrolStatus.interrupted;
}
