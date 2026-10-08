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
  const PatrolAssignment({
    required this.id,
    required this.rangerId,
    required this.rangerName,
    required this.area,
    required this.assignedAt,
  });

  final String id;
  final String rangerId;
  final String rangerName;
  final PatrolArea area;
  final DateTime assignedAt;
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
  }
}
