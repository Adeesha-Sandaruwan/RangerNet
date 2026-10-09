import 'patrol_records.dart';

class PatrolRanger {
  const PatrolRanger({
    required this.id,
    required this.name,
    required this.email,
  });

  final String id;
  final String name;
  final String email;
}

class PatrolAssignment {
  PatrolAssignment({
    required this.id,
    required this.rangerId,
    required this.rangerName,
    required this.area,
    required this.assignedAt,
    this.plannedRoute,
  });

  final String id;
  final String rangerId;
  final String rangerName;
  final PatrolArea area;
  final DateTime assignedAt;
  final PatrolRoutePlan? plannedRoute;
  List<PatrolCoverageCheckpoint> get plannedCoverageSections =>
      plannedRoute?.coverageSections ?? const [];
}

class PatrolAssignmentDraft {
  const PatrolAssignmentDraft({
    required this.ranger,
    required this.parkName,
    required this.zoneName,
    required this.routeName,
    this.parkId,
    this.zoneId,
    this.routeId,
    required this.plannedRoute,
  });

  final PatrolRanger ranger;
  final String parkName;
  final String zoneName;
  final String routeName;
  final String? parkId;
  final String? zoneId;
  final String? routeId;
  final PatrolRoutePlan plannedRoute;

  void validate() {
    if (ranger.id.trim().isEmpty) {
      throw ArgumentError('Select an active ranger.');
    }
    if (parkName.trim().isEmpty ||
        zoneName.trim().isEmpty ||
        routeName.trim().isEmpty) {
      throw ArgumentError('Park, zone, and route are required.');
    }
    if (plannedRoute.coverageSections.isEmpty) {
      throw ArgumentError(
        'Generate route coverage before creating the patrol assignment.',
      );
    }
  }
}
