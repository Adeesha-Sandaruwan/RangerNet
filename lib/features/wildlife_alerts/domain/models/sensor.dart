import 'geo_location.dart';

enum SensorType { gpsCollar, cameraTrap }

enum SensorStatus { active, lowBattery, offline, maintenance }

/// Abstract base entity for all conservation sensors deployed in the reserve.
abstract class Sensor {
  const Sensor({
    required this.id,
    required this.sensorType,
    required this.batteryLevel,
    required this.status,
    required this.lastActiveAt,
    this.name,
  });

  final String id;
  final SensorType sensorType;
  final double batteryLevel; // 0.0 - 100.0%
  final SensorStatus status;
  final DateTime lastActiveAt;
  final String? name;

  bool get isBatteryCritical => batteryLevel <= 15.0;

  Map<String, dynamic> toJson();
}

/// GPS collar attached to a tracked animal.
class GPSCollar extends Sensor {
  const GPSCollar({
    required super.id,
    required super.batteryLevel,
    required super.status,
    required super.lastActiveAt,
    super.name,
    required this.animalId,
    required this.currentLocation,
  }) : super(sensorType: SensorType.gpsCollar);

  final String animalId;
  final GeoLocation currentLocation;

  double get latitude => currentLocation.latitude;
  double get longitude => currentLocation.longitude;
  double? get altitude => currentLocation.altitude;
  DateTime get timestamp => currentLocation.timestamp;

  GPSCollar copyWith({
    String? id,
    double? batteryLevel,
    SensorStatus? status,
    DateTime? lastActiveAt,
    String? name,
    String? animalId,
    GeoLocation? currentLocation,
  }) {
    return GPSCollar(
      id: id ?? this.id,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      status: status ?? this.status,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      name: name ?? this.name,
      animalId: animalId ?? this.animalId,
      currentLocation: currentLocation ?? this.currentLocation,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'sensorType': sensorType.name,
    'batteryLevel': batteryLevel,
    'status': status.name,
    'lastActiveAt': lastActiveAt.toIso8601String(),
    'name': name,
    'animalId': animalId,
    'currentLocation': currentLocation.toJson(),
  };

  factory GPSCollar.fromJson(Map<String, dynamic> json) => GPSCollar(
    id: json['id'] as String,
    batteryLevel: (json['batteryLevel'] as num).toDouble(),
    status: SensorStatus.values.byName(json['status'] as String),
    lastActiveAt: DateTime.parse(json['lastActiveAt'] as String),
    name: json['name'] as String?,
    animalId: json['animalId'] as String,
    currentLocation: GeoLocation.fromJson(
      json['currentLocation'] as Map<String, dynamic>,
    ),
  );
}

/// Fixed camera trap deployed along movement corridors and perimeter fences.
class CameraTrap extends Sensor {
  const CameraTrap({
    required super.id,
    required super.batteryLevel,
    required super.status,
    required super.lastActiveAt,
    super.name,
    required this.cameraLocation,
    required this.triggerTimestamp,
    this.capturedImageUrl,
    this.simulatedDetectionTag,
    this.targetAnimalId,
  }) : super(sensorType: SensorType.cameraTrap);

  final GeoLocation cameraLocation;
  final DateTime triggerTimestamp;
  final String? capturedImageUrl;
  final String? simulatedDetectionTag; // e.g. "HUMAN_TRESPASS", "POACHER_WEAPON", "DISTRESSED_ANIMAL", "NORMAL_PASSAGE"
  final String? targetAnimalId;

  CameraTrap copyWith({
    String? id,
    double? batteryLevel,
    SensorStatus? status,
    DateTime? lastActiveAt,
    String? name,
    GeoLocation? cameraLocation,
    DateTime? triggerTimestamp,
    String? capturedImageUrl,
    String? simulatedDetectionTag,
    String? targetAnimalId,
  }) {
    return CameraTrap(
      id: id ?? this.id,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      status: status ?? this.status,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      name: name ?? this.name,
      cameraLocation: cameraLocation ?? this.cameraLocation,
      triggerTimestamp: triggerTimestamp ?? this.triggerTimestamp,
      capturedImageUrl: capturedImageUrl ?? this.capturedImageUrl,
      simulatedDetectionTag:
          simulatedDetectionTag ?? this.simulatedDetectionTag,
      targetAnimalId: targetAnimalId ?? this.targetAnimalId,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'sensorType': sensorType.name,
    'batteryLevel': batteryLevel,
    'status': status.name,
    'lastActiveAt': lastActiveAt.toIso8601String(),
    'name': name,
    'cameraLocation': cameraLocation.toJson(),
    'triggerTimestamp': triggerTimestamp.toIso8601String(),
    'capturedImageUrl': capturedImageUrl,
    'simulatedDetectionTag': simulatedDetectionTag,
    'targetAnimalId': targetAnimalId,
  };

  factory CameraTrap.fromJson(Map<String, dynamic> json) => CameraTrap(
    id: json['id'] as String,
    batteryLevel: (json['batteryLevel'] as num).toDouble(),
    status: SensorStatus.values.byName(json['status'] as String),
    lastActiveAt: DateTime.parse(json['lastActiveAt'] as String),
    name: json['name'] as String?,
    cameraLocation: GeoLocation.fromJson(
      json['cameraLocation'] as Map<String, dynamic>,
    ),
    triggerTimestamp: DateTime.parse(json['triggerTimestamp'] as String),
    capturedImageUrl: json['capturedImageUrl'] as String?,
    simulatedDetectionTag: json['simulatedDetectionTag'] as String?,
    targetAnimalId: json['targetAnimalId'] as String?,
  );
}
