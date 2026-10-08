import '../domain/patrol_assignment.dart';
import '../domain/patrol_assignment_repository.dart';

class PatrolAssignmentService {
  const PatrolAssignmentService(this._repository);

  final PatrolAssignmentRepository _repository;

  Future<List<PatrolRanger>> loadActiveRangers() =>
      _repository.loadActiveRangers();

  Future<List<PatrolAssignment>> loadAssignments() =>
      _repository.loadAssignments();

  Future<PatrolAssignment> createAssignment(PatrolAssignmentDraft draft) async {
    draft.validate();
    return _repository.createAssignment(draft);
  }
}
