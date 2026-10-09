// Coverage: manager patrol-assignment creation; checks valid route details
// succeed and incomplete area or route data is rejected before persistence.
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
          plannedRoute: _route(),
        ),
      );

      expect(repository.createdDrafts, hasLength(1));
      expect(assignment.rangerId, 'ranger-1');
      expect(assignment.area.routeName, 'River Route');
      expect(assignment.area.centerLatitude, 6.1);
      expect(assignment.plannedRoute?.stops.single.name, 'River bend');
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
            plannedRoute: _route(),
          ),
        ),
        throwsArgumentError,
      );
      expect(repository.createdDrafts, isEmpty);
    },
  );

  test('route start, destination, and generated coverage are required', () async {
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
          plannedRoute: PatrolRoutePlan(
            start: _point('start', 'Start', 6.1, 81.2),
            end: _point('end', 'End', 6.2, 81.3),
          ),
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
        centerLatitude: draft.plannedRoute.start.latitude,
        centerLongitude: draft.plannedRoute.start.longitude,
      ),
      assignedAt: DateTime.utc(2026, 10, 8),
      plannedRoute: draft.plannedRoute,
    );
  }

  @override
  Future<List<PatrolRanger>> loadActiveRangers() async => const [];

  @override
  Future<List<PatrolAssignment>> loadAssignments() async => const [];
}

PatrolRoutePlan _route() => PatrolRoutePlan(
  start: _point('start', 'Start', 6.1, 81.2),
  stops: [_point('stop-1', 'River bend', 6.15, 81.25)],
  end: _point('end', 'Destination', 6.2, 81.3),
  coverageSections: [_point('section-1', 'Route section 1', 6.1, 81.2)],
);

PatrolCoverageCheckpoint _point(
  String id,
  String name,
  double latitude,
  double longitude,
) => PatrolCoverageCheckpoint(
  id: id,
  name: name,
  latitude: latitude,
  longitude: longitude,
);
