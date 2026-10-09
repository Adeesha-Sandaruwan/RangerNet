import 'patrol.dart';

class PatrolReviewRecord {
  const PatrolReviewRecord({
    required this.patrol,
    this.reviewStatus = PatrolManagerReviewStatus.pending,
    this.reviewedAt,
    this.reviewedBy,
    this.managerNotes,
    this.followUpRequired = false,
  });

  final Patrol patrol;
  final PatrolManagerReviewStatus reviewStatus;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? managerNotes;
  final bool followUpRequired;

  bool get isReviewed => reviewStatus == PatrolManagerReviewStatus.reviewed;
}

enum PatrolManagerReviewStatus { pending, reviewed, followUpRequired }
