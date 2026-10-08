import 'patrol_review.dart';

abstract interface class PatrolReviewRepository {
  Future<List<PatrolReviewRecord>> loadCompletedPatrols();

  Future<PatrolReviewRecord> saveReview({
    required String patrolId,
    required String managerId,
    required String notes,
    required bool followUpRequired,
  });

  Future<PatrolReviewRecord> flagFollowUp({
    required String patrolId,
    required String managerId,
    required String notes,
  });
}
