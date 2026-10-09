import 'geo_location.dart';

enum AlertRiskLevel {
  high('HIGH', 3),
  medium('MEDIUM', 2),
  low('LOW', 1);

  const AlertRiskLevel(this.label, this.priorityOrder);
  final String label;
  final int priorityOrder;
}

enum AlertStatus {
  active('ACTIVE'),
  acknowledged('ACKNOWLEDGED'),
  resolved('RESOLVED');

  const AlertStatus(this.label);
  final String label;
}

enum AlertTriggerType {
  geofenceBreach('Geofence Breach'),
  cameraDetection('Camera Detection'),
  criticalBattery('Critical Battery'),
  manual('Manual Trigger');

  const AlertTriggerType(this.label);
  final String label;
}

class WildlifeAlert {
  const WildlifeAlert({
    required this.alertId,
    required this.sensorId,
    required this.targetId,
    required this.riskLevel,
    required this.status,
    required this.triggeredAt,
    required this.triggerType,
    this.title = '',
    this.description = '',
    this.resolvedAt,
    this.responseNotes,
    this.locationHistory = const [],
    this.currentLocation,
    this.zoneId,
    this.zoneName,
    this.capturedImageUrl,
    this.simulatedDetectionTag,
    this.acknowledgedAt,
    this.acknowledgedByRangerId,
    this.resolvedByRangerId,
    this.lastUpdatedAt,
    this.targetSpecies,
    this.targetName,
  });

  final String alertId;
  final String sensorId;
  final String targetId; // Animal ID or target area
  final AlertRiskLevel riskLevel;
  final AlertStatus status;
  final AlertTriggerType triggerType;
  final String title;
  final String description;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;
  final String? responseNotes;
  final List<GeoLocation> locationHistory;
  final GeoLocation? currentLocation;
  final String? zoneId;
  final String? zoneName;
  final String? capturedImageUrl;
  final String? simulatedDetectionTag;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByRangerId;
  final String? resolvedByRangerId;
  final DateTime? lastUpdatedAt;
  final String? targetSpecies;
  final String? targetName;

  bool get isActive => status == AlertStatus.active;
  bool get isAcknowledged => status == AlertStatus.acknowledged;
  bool get isResolved => status == AlertStatus.resolved;

  WildlifeAlert copyWith({
    String? alertId,
    String? sensorId,
    String? targetId,
    AlertRiskLevel? riskLevel,
    AlertStatus? status,
    AlertTriggerType? triggerType,
    String? title,
    String? description,
    DateTime? triggeredAt,
    DateTime? resolvedAt,
    String? responseNotes,
    List<GeoLocation>? locationHistory,
    GeoLocation? currentLocation,
    String? zoneId,
    String? zoneName,
    String? capturedImageUrl,
    String? simulatedDetectionTag,
    DateTime? acknowledgedAt,
    String? acknowledgedByRangerId,
    String? resolvedByRangerId,
    DateTime? lastUpdatedAt,
    String? targetSpecies,
    String? targetName,
  }) {
    return WildlifeAlert(
      alertId: alertId ?? this.alertId,
      sensorId: sensorId ?? this.sensorId,
      targetId: targetId ?? this.targetId,
      riskLevel: riskLevel ?? this.riskLevel,
      status: status ?? this.status,
      triggerType: triggerType ?? this.triggerType,
      title: title ?? this.title,
      description: description ?? this.description,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      responseNotes: responseNotes ?? this.responseNotes,
      locationHistory: locationHistory ?? this.locationHistory,
      currentLocation: currentLocation ?? this.currentLocation,
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
      capturedImageUrl: capturedImageUrl ?? this.capturedImageUrl,
      simulatedDetectionTag:
          simulatedDetectionTag ?? this.simulatedDetectionTag,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgedByRangerId:
          acknowledgedByRangerId ?? this.acknowledgedByRangerId,
      resolvedByRangerId: resolvedByRangerId ?? this.resolvedByRangerId,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      targetSpecies: targetSpecies ?? this.targetSpecies,
      targetName: targetName ?? this.targetName,
    );
  }

  Map<String, dynamic> toJson() => {
    'alertId': alertId,
    'sensorId': sensorId,
    'targetId': targetId,
    'riskLevel': riskLevel.name,
    'status': status.name,
    'triggerType': triggerType.name,
    'title': title,
    'description': description,
    'triggeredAt': triggeredAt.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
    'responseNotes': responseNotes,
    'locationHistory': locationHistory.map((l) => l.toJson()).toList(),
    'currentLocation': currentLocation?.toJson(),
    'zoneId': zoneId,
    'zoneName': zoneName,
    'capturedImageUrl': capturedImageUrl,
    'simulatedDetectionTag': simulatedDetectionTag,
    'acknowledgedAt': acknowledgedAt?.toIso8601String(),
    'acknowledgedByRangerId': acknowledgedByRangerId,
    'resolvedByRangerId': resolvedByRangerId,
    'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
    'targetSpecies': targetSpecies,
    'targetName': targetName,
  };

  factory WildlifeAlert.fromJson(Map<String, dynamic> json) => WildlifeAlert(
    alertId: json['alertId'] as String,
    sensorId: json['sensorId'] as String,
    targetId: json['targetId'] as String,
    riskLevel: AlertRiskLevel.values.byName(
      json['riskLevel'] as String? ?? 'medium',
    ),
    status: AlertStatus.values.byName(json['status'] as String? ?? 'active'),
    triggerType: AlertTriggerType.values.byName(
      json['triggerType'] as String? ?? 'geofenceBreach',
    ),
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    triggeredAt: DateTime.parse(json['triggeredAt'] as String),
    resolvedAt: json['resolvedAt'] != null
        ? DateTime.parse(json['resolvedAt'] as String)
        : null,
    responseNotes: json['responseNotes'] as String?,
    locationHistory: (json['locationHistory'] as List<dynamic>? ?? [])
        .map((l) => GeoLocation.fromJson(l as Map<String, dynamic>))
        .toList(),
    currentLocation: json['currentLocation'] != null
        ? GeoLocation.fromJson(json['currentLocation'] as Map<String, dynamic>)
        : null,
    zoneId: json['zoneId'] as String?,
    zoneName: json['zoneName'] as String?,
    capturedImageUrl: json['capturedImageUrl'] as String?,
    simulatedDetectionTag: json['simulatedDetectionTag'] as String?,
    acknowledgedAt: json['acknowledgedAt'] != null
        ? DateTime.parse(json['acknowledgedAt'] as String)
        : null,
    acknowledgedByRangerId: json['acknowledgedByRangerId'] as String?,
    resolvedByRangerId: json['resolvedByRangerId'] as String?,
    lastUpdatedAt: json['lastUpdatedAt'] != null
        ? DateTime.parse(json['lastUpdatedAt'] as String)
        : null,
    targetSpecies: json['targetSpecies'] as String?,
    targetName: json['targetName'] as String?,
  );
}
