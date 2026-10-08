import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/patrols/application/patrol_assignment_service.dart';
import 'package:rangernet/features/patrols/domain/patrol_assignment.dart';
import 'package:rangernet/features/patrols/domain/patrol_assignment_repository.dart';
import 'package:rangernet/features/patrols/domain/patrol_records.dart';

void main() {
  late _FakeAssignmentRepository repository;
  late PatrolAssignmentService service;

  setUp(() {
    repository = _FakeAssignmentRepository();
    service = PatrolAssignmentService(repository);
  });

  test(
    'creates a patrol assignment after validating required details',
    () async {
      final assignment = await service.createAssignment(
        PatrolAssignmentDraft(
          ranger: const PatrolRanger(
            id: 'ranger-1',
            name: 'Ranger One',
            email: 'ranger@example.test',
          ),
          parkName: 'North Park',
          zoneName: 'North Zone',
          routeName: 'River Route',
          centerLatitude: 6.1,
          centerLongitude: 81.2,
          plannedCoverageSections: [
            PatrolCoverageCheckpoint(
              id: 'section-1',
              name: 'River bend',
              latitude: 6.11,
              longitude: 81.21,
            ),
          ],
        ),
      );

      expect(repository.createdDrafts, hasLength(1));
      expect(assignment.rangerId, 'ranger-1');
      expect(assignment.area.routeName, 'River Route');
      expect(assignment.area.centerLatitude, 6.1);
      expect(assignment.plannedCoverageSections.single.name, 'River bend');
    },
  );

  test(
    'rejects incomplete assignments before calling the repository',
    () async {
      await expectLater(
        service.createAssignment(
          PatrolAssignmentDraft(
            ranger: const PatrolRanger(
              id: 'ranger-1',
              name: 'Ranger One',
              email: 'ranger@example.test',
            ),
            parkName: 'North Park',
            zoneName: ' ',
            routeName: 'River Route',
          ),
        ),
        throwsArgumentError,
      );
      expect(repository.createdDrafts, isEmpty);
    },
  );

  test('requires coordinate pairs and validates their ranges', () async {
    final ranger = const PatrolRanger(
      id: 'ranger-1',
      name: 'Ranger One',
      email: 'ranger@example.test',
    );
    await expectLater(
      service.createAssignment(
        PatrolAssignmentDraft(
          ranger: ranger,
          parkName: 'North Park',
          zoneName: 'North Zone',
          routeName: 'River Route',
          centerLatitude: 6.1,
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      service.createAssignment(
        PatrolAssignmentDraft(
          ranger: ranger,
          parkName: 'North Park',
          zoneName: 'North Zone',
          routeName: 'River Route',
          centerLatitude: 96,
          centerLongitude: 81,
        ),
      ),
      throwsArgumentError,
    );
    expect(repository.createdDrafts, isEmpty);
  });
}

class _FakeAssignmentRepository implements PatrolAssignmentRepository {
  final createdDrafts = <PatrolAssignmentDraft>[];

  @override
  Future<PatrolAssignment> createAssignment(PatrolAssignmentDraft draft) async {
    createdDrafts.add(draft);
    return PatrolAssignment(
      id: 'assignment-1',
      rangerId: draft.ranger.id,
      rangerName: draft.ranger.name,
      area: PatrolArea(
        parkName: draft.parkName,
        zoneName: draft.zoneName,
        routeName: draft.routeName,
        centerLatitude: draft.centerLatitude,
        centerLongitude: draft.centerLongitude,
      ),
      assignedAt: DateTime.utc(2026, 10, 8),
      plannedCoverageSections: draft.plannedCoverageSections,
    );
  }

  @override
  Future<List<PatrolRanger>> loadActiveRangers() async => const [];

  @override
  Future<List<PatrolAssignment>> loadAssignments() async => const [];
}
