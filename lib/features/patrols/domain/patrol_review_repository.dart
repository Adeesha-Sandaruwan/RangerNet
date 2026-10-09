import 'patrol_review.dart';

/// ISP: small persistence boundary for manager review records and follow-up flags.
abstract interface class PatrolReviewRepository {
  /// Loads completed patrols for manager review.
  Future<List<PatrolReviewRecord>> loadCompletedPatrols();

  /// Persists a manager review and its follow-up choice.
  Future<PatrolReviewRecord> saveReview({
    required String patrolId,
    required String managerId,
    required String notes,
    required bool followUpRequired,
  });

  /// Persists a follow-up flag and manager notes.
  Future<PatrolReviewRecord> flagFollowUp({
    required String patrolId,
    required String managerId,
    required String notes,
  });
}
