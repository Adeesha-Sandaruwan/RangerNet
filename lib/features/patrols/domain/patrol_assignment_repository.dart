import 'patrol_assignment.dart';

abstract interface class PatrolAssignmentRepository {
  Future<List<PatrolRanger>> loadActiveRangers();

  Future<List<PatrolAssignment>> loadAssignments();

  Future<PatrolAssignment> createAssignment(PatrolAssignmentDraft draft);
}
