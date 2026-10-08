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
    Iterable<PatrolCoverageCheckpoint> plannedCoverageSections = const [],
  }) : plannedCoverageSections = List.unmodifiable(plannedCoverageSections);

  final String id;
  final String rangerId;
  final String rangerName;
  final PatrolArea area;
  final DateTime assignedAt;
  final List<PatrolCoverageCheckpoint> plannedCoverageSections;
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
    this.centerLatitude,
    this.centerLongitude,
    this.plannedCoverageSections = const [],
  });

  final PatrolRanger ranger;
  final String parkName;
  final String zoneName;
  final String routeName;
  final String? parkId;
  final String? zoneId;
  final String? routeId;
  final double? centerLatitude;
  final double? centerLongitude;
  final Iterable<PatrolCoverageCheckpoint> plannedCoverageSections;

  void validate() {
    if (ranger.id.trim().isEmpty) {
      throw ArgumentError('Select an active ranger.');
    }
    if (parkName.trim().isEmpty ||
        zoneName.trim().isEmpty ||
        routeName.trim().isEmpty) {
      throw ArgumentError('Park, zone, and route are required.');
    }
    if ((centerLatitude == null) != (centerLongitude == null)) {
      throw ArgumentError('Provide both map center coordinates, or neither.');
    }
    if (centerLatitude != null &&
        (!centerLatitude!.isFinite ||
            centerLatitude! < -90 ||
            centerLatitude! > 90)) {
      throw ArgumentError.value(
        centerLatitude,
        'centerLatitude',
        'Must be between -90 and 90.',
      );
    }
    if (centerLongitude != null &&
        (!centerLongitude!.isFinite ||
            centerLongitude! < -180 ||
            centerLongitude! > 180)) {
      throw ArgumentError.value(
        centerLongitude,
        'centerLongitude',
        'Must be between -180 and 180.',
      );
    }
    final sectionIds = plannedCoverageSections.map((section) => section.id);
    if (sectionIds.toSet().length != sectionIds.length) {
      throw ArgumentError('Coverage checkpoint IDs must be unique.');
    }
  }
}
