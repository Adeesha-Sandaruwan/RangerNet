import 'patrol_assignment.dart';

/// ISP: small repository boundary for loading rangers/assignments and creating an assignment.
abstract interface class PatrolAssignmentRepository {
  /// Loads rangers eligible to receive an assignment.
  Future<List<PatrolRanger>> loadActiveRangers();

  /// Loads patrol assignments available to the application.
  Future<List<PatrolAssignment>> loadAssignments();

  /// Persists a validated assignment draft and returns the created assignment.
  Future<PatrolAssignment> createAssignment(PatrolAssignmentDraft draft);
}
