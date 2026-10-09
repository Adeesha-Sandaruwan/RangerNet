// Coverage: manager patrol-review service; checks note trimming, required
// patrol/manager identity, and follow-up note validation before repository calls.
import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/patrols/application/patrol_review_service.dart';
import 'package:rangernet/features/patrols/domain/patrol.dart';
import 'package:rangernet/features/patrols/domain/patrol_records.dart';
import 'package:rangernet/features/patrols/domain/patrol_review.dart';
import 'package:rangernet/features/patrols/domain/patrol_review_repository.dart';

void main() {
  late _FakePatrolReviewRepository repository;
  late PatrolReviewService service;

  setUp(() {
    repository = _FakePatrolReviewRepository();
    service = PatrolReviewService(repository);
  });

  test('trims manager notes before persisting review', () async {
    await service.saveReview(
      patrolId: 'patrol-1',
      managerId: 'manager-1',
      notes: '  Route checked  ',
      followUpRequired: false,
    );

    expect(repository.savedNotes, 'Route checked');
    expect(repository.savedFollowUpRequired, isFalse);
  });

  test('requires identity before attempting to save a review', () async {
    await expectLater(
      service.saveReview(
        patrolId: ' ',
        managerId: 'manager-1',
        notes: '',
        followUpRequired: false,
      ),
      throwsArgumentError,
    );
    expect(repository.saveCalls, 0);
  });

  test('requires a note when flagging follow-up', () async {
    await expectLater(
      service.flagFollowUp(
        patrolId: 'patrol-1',
        managerId: 'manager-1',
        notes: ' ',
      ),
      throwsArgumentError,
    );
    expect(repository.followUpCalls, 0);
  });
}

class _FakePatrolReviewRepository implements PatrolReviewRepository {
  int saveCalls = 0;
  int followUpCalls = 0;
  String? savedNotes;
  bool? savedFollowUpRequired;

  @override
  Future<List<PatrolReviewRecord>> loadCompletedPatrols() async => const [];

  @override
  Future<PatrolReviewRecord> saveReview({
    required String patrolId,
    required String managerId,
    required String notes,
    required bool followUpRequired,
  }) async {
    saveCalls++;
    savedNotes = notes;
    savedFollowUpRequired = followUpRequired;
    return _record();
  }

  @override
  Future<PatrolReviewRecord> flagFollowUp({
    required String patrolId,
    required String managerId,
    required String notes,
  }) async {
    followUpCalls++;
    return _record();
  }

  PatrolReviewRecord _record() => PatrolReviewRecord(
    patrol: Patrol(
      patrolId: 'patrol-1',
      localId: 'local-1',
      rangerId: 'ranger-1',
      rangerName: 'Ranger',
      area: const PatrolArea(
        parkName: 'Park',
        zoneName: 'Zone',
        routeName: 'Route',
      ),
    ),
  );
}
