import 'patrol.dart';

/// Manager review state and notes associated with a completed patrol.
class PatrolReviewRecord {
  const PatrolReviewRecord({
    required this.patrol,
    this.reviewStatus = PatrolManagerReviewStatus.pending,
    this.reviewedAt,
    this.reviewedBy,
    this.managerNotes,
    this.followUpRequired = false,
  });

  /// Completed patrol under manager review.
  final Patrol patrol;
  /// Current review or follow-up state.
  final PatrolManagerReviewStatus reviewStatus;
  /// Time the manager recorded the review.
  final DateTime? reviewedAt;
  /// Manager ID that recorded the review.
  final String? reviewedBy;
  /// Notes supplied by the reviewing manager.
  final String? managerNotes;
  /// Whether follow-up work is required.
  final bool followUpRequired;

  /// Whether a manager has completed the review.
  bool get isReviewed => reviewStatus == PatrolManagerReviewStatus.reviewed;
}

/// Review states for a completed patrol awaiting manager review or follow-up.
enum PatrolManagerReviewStatus { pending, reviewed, followUpRequired }
