import 'patrol_records.dart';

/// Ranger identity details used when assigning patrol work.
class PatrolRanger {
  const PatrolRanger({
    required this.id,
    required this.name,
    required this.email,
  });

  /// Stable ranger identifier.
  final String id;
  /// Ranger display name.
  final String name;
  /// Ranger email address.
  final String email;
}

/// A ranger-specific assignment with its area, assignment time, and optional planned route.
class PatrolAssignment {
  PatrolAssignment({
    required this.id,
    required this.rangerId,
    required this.rangerName,
    required this.area,
    required this.assignedAt,
    this.plannedRoute,
  });

  /// Stable assignment identifier.
  final String id;
  /// ID of the assigned ranger.
  final String rangerId;
  /// Display name of the assigned ranger.
  final String rangerName;
  /// Park, zone, and route for the assignment.
  final PatrolArea area;
  /// Time this assignment was created.
  final DateTime assignedAt;
  /// Optional route plan attached to the assignment.
  final PatrolRoutePlan? plannedRoute;
  /// Coverage sections from the assignment route, or an empty list when absent.
  List<PatrolCoverageCheckpoint> get plannedCoverageSections =>
      plannedRoute?.coverageSections ?? const [];
}

/// Input for creating an assignment; validates ranger, area names, and generated coverage.
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

  /// Ranger selected for the assignment.
  final PatrolRanger ranger;
  /// Required park display name.
  final String parkName;
  /// Required zone display name.
  final String zoneName;
  /// Required route display name.
  final String routeName;
  /// Optional stable park ID.
  final String? parkId;
  /// Optional stable zone ID.
  final String? zoneId;
  /// Optional stable route ID.
  final String? routeId;
  /// Generated route plan, required to include coverage sections.
  final PatrolRoutePlan plannedRoute;

  /// Rejects incomplete assignments before they are created.
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
