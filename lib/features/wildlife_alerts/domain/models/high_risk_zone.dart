import 'geo_location.dart';

enum ZoneSeverityLevel {
  high('High Risk', 3),
  medium('Medium Risk', 2),
  low('Low Risk', 1);

  const ZoneSeverityLevel(this.label, this.weight);
  final String label;
  final int weight;
}

enum GeofenceType { polygon, circular }

class HighRiskZone {
  const HighRiskZone({
    required this.zoneId,
    required this.name,
    required this.severityLevel,
    this.boundaryPolygon = const [],
    this.centerLocation,
    this.radiusMeters,
    this.description = '',
    this.isActive = true,
  });

  final String zoneId;
  final String name;
  final ZoneSeverityLevel severityLevel;
  final List<GeoLocation> boundaryPolygon;
  final GeoLocation? centerLocation;
  final double? radiusMeters;
  final String description;
  final bool isActive;

  GeofenceType get geofenceType => boundaryPolygon.length >= 3
      ? GeofenceType.polygon
      : GeofenceType.circular;

  Map<String, dynamic> toJson() => {
    'zoneId': zoneId,
    'name': name,
    'severityLevel': severityLevel.name,
    'boundaryPolygon': boundaryPolygon.map((p) => p.toJson()).toList(),
    'centerLocation': centerLocation?.toJson(),
    'radiusMeters': radiusMeters,
    'description': description,
    'isActive': isActive,
  };

  factory HighRiskZone.fromJson(Map<String, dynamic> json) => HighRiskZone(
    zoneId: json['zoneId'] as String,
    name: json['name'] as String,
    severityLevel: ZoneSeverityLevel.values.byName(
      json['severityLevel'] as String? ?? 'medium',
    ),
    boundaryPolygon: (json['boundaryPolygon'] as List<dynamic>? ?? [])
        .map((p) => GeoLocation.fromJson(p as Map<String, dynamic>))
        .toList(),
    centerLocation: json['centerLocation'] != null
        ? GeoLocation.fromJson(json['centerLocation'] as Map<String, dynamic>)
        : null,
    radiusMeters: (json['radiusMeters'] as num?)?.toDouble(),
    description: json['description'] as String? ?? '',
    isActive: json['isActive'] as bool? ?? true,
  );
}
