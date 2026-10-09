import '../domain/patrol_assignment.dart';
import '../domain/patrol_assignment_repository.dart';

/// Validates assignment drafts and delegates ranger and assignment operations. DIP: receives [PatrolAssignmentRepository] via constructor.
class PatrolAssignmentService {
  const PatrolAssignmentService(this._repository);

  final PatrolAssignmentRepository _repository;

  /// Loads rangers eligible for patrol assignment.
  Future<List<PatrolRanger>> loadActiveRangers() =>
      _repository.loadActiveRangers();

  /// Loads available patrol assignments.
  Future<List<PatrolAssignment>> loadAssignments() =>
      _repository.loadAssignments();

  /// Validates the draft before delegating assignment creation.
  Future<PatrolAssignment> createAssignment(PatrolAssignmentDraft draft) async {
    draft.validate();
    return _repository.createAssignment(draft);
  }
}
