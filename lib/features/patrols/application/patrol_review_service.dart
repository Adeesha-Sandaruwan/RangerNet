import '../domain/patrol_review.dart';
import '../domain/patrol_review_repository.dart';

/// Validates manager review input and delegates review persistence. SRP: keeps review use-case validation outside the repository. DIP: receives [PatrolReviewRepository] via constructor.
class PatrolReviewService {
  const PatrolReviewService(this._repository);

  final PatrolReviewRepository _repository;

  /// Loads completed patrols available for review.
  Future<List<PatrolReviewRecord>> loadCompletedPatrols() =>
      _repository.loadCompletedPatrols();

  /// Validates IDs, trims notes, and saves a manager review.
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

  /// Requires non-empty notes before saving a follow-up flag.
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
