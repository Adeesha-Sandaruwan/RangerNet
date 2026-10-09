import '../domain/patrol_review.dart';
import '../domain/patrol_review_repository.dart';

class PatrolReviewService {
  const PatrolReviewService(this._repository);

  final PatrolReviewRepository _repository;

  Future<List<PatrolReviewRecord>> loadCompletedPatrols() =>
      _repository.loadCompletedPatrols();

  Future<PatrolReviewRecord> saveReview({
    required String patrolId,
    required String managerId,
    required String notes,
    required bool followUpRequired,
  }) async {
    if (patrolId.trim().isEmpty || managerId.trim().isEmpty) {
      throw ArgumentError('Patrol and manager IDs are required for review.');
    }
    return _repository.saveReview(
      patrolId: patrolId,
      managerId: managerId,
      notes: notes.trim(),
      followUpRequired: followUpRequired,
    );
  }

  Future<PatrolReviewRecord> flagFollowUp({
    required String patrolId,
    required String managerId,
    required String notes,
  }) async {
    if (patrolId.trim().isEmpty || managerId.trim().isEmpty) {
      throw ArgumentError('Patrol and manager IDs are required for follow-up.');
    }
    if (notes.trim().isEmpty) {
      throw ArgumentError(
        'Add a manager note when flagging a patrol for follow-up.',
      );
    }
    return _repository.flagFollowUp(
      patrolId: patrolId,
      managerId: managerId,
      notes: notes.trim(),
    );
  }
}
