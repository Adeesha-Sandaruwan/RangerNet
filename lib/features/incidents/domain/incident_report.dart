enum IncidentType {
  illegalSnare(
    'Illegal snare / poaching',
    'Wire snare, trap, or poaching sign',
  ),
  animalCarcass('Animal carcass', 'Dead or injured wildlife'),
  illegalCampsite('Illegal campsite', 'Camp or human intrusion'),
  suspiciousActivity(
    'Suspicious activity',
    'Tracks, sounds, or other activity',
  ),
  other('Other wildlife incident', 'Something else requiring follow-up');

  const IncidentType(this.label, this.hint);
  final String label;
  final String hint;
}

enum IncidentSeverity {
  low('Low'),
  medium('Medium'),
  high('High'),
  critical('Critical');

  const IncidentSeverity(this.label);
  final String label;
}

enum IncidentStatus { draft, pendingSync, reported, syncFailed }

enum IncidentWorkflowStatus {
  reported('Reported'),
  underReview('Under review'),
  assigned('Assigned'),
  responseInProgress('Response in progress'),
  resolved('Resolved — manager confirmation required'),
  followUpRequired('Follow-up required'),
  monitoring('Monitoring'),
  closed('Closed'),
  duplicate('Duplicate'),
  rejected('Rejected / invalid');

  const IncidentWorkflowStatus(this.label);
  final String label;
}

enum IncidentAssignmentKind { ranger, responseTeam }

class IncidentEvidence {
  const IncidentEvidence({
    required this.id,
    required this.fileName,
    required this.base64Data,
    required this.contentType,
  });

  final String id;
  final String fileName;
  final String base64Data;
  final String contentType;

  Map<String, Object?> toJson() => {
    'id': id,
    'fileName': fileName,
    'base64Data': base64Data,
    'contentType': contentType,
  };

  factory IncidentEvidence.fromJson(Map<String, dynamic> json) =>
      IncidentEvidence(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        base64Data: json['base64Data'] as String,
        contentType: json['contentType'] as String? ?? 'image/jpeg',
      );
}

class IncidentReport {
  const IncidentReport({
    required this.id,
    required this.rangerId,
    required this.rangerEmail,
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    required this.activeThreat,
    required this.latitude,
    required this.longitude,
    required this.locationAccuracyMeters,
    required this.parkOrBlock,
    required this.createdAt,
    required this.status,
    required this.evidence,
    this.patrolId,
    this.manualLocation = false,
    this.workflowStatus = IncidentWorkflowStatus.reported,
    this.assignmentKind = IncidentAssignmentKind.ranger,
    this.assignedRangerIds = const [],
    this.assignedRangerNames = const [],
  });

  final String id;
  final String rangerId;
  final String rangerEmail;
  final IncidentType type;
  final String title;
  final String description;
  final IncidentSeverity severity;
  final bool activeThreat;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracyMeters;
  final String parkOrBlock;
  final DateTime createdAt;
  final IncidentStatus status;
  final List<IncidentEvidence> evidence;
  final String? patrolId;
  final bool manualLocation;
  final IncidentWorkflowStatus workflowStatus;
  final IncidentAssignmentKind assignmentKind;
  final List<String> assignedRangerIds;
  final List<String> assignedRangerNames;

  IncidentReport copyWith({
    IncidentStatus? status,
    IncidentSeverity? severity,
    IncidentWorkflowStatus? workflowStatus,
    IncidentAssignmentKind? assignmentKind,
    List<String>? assignedRangerIds,
    List<String>? assignedRangerNames,
  }) => IncidentReport(
    id: id,
    rangerId: rangerId,
    rangerEmail: rangerEmail,
    type: type,
    title: title,
    description: description,
    severity: severity ?? this.severity,
    activeThreat: activeThreat,
    latitude: latitude,
    longitude: longitude,
    locationAccuracyMeters: locationAccuracyMeters,
    parkOrBlock: parkOrBlock,
    createdAt: createdAt,
    status: status ?? this.status,
    evidence: evidence,
    patrolId: patrolId,
    manualLocation: manualLocation,
    workflowStatus: workflowStatus ?? this.workflowStatus,
    assignmentKind: assignmentKind ?? this.assignmentKind,
    assignedRangerIds: assignedRangerIds ?? this.assignedRangerIds,
    assignedRangerNames: assignedRangerNames ?? this.assignedRangerNames,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'rangerId': rangerId,
    'rangerEmail': rangerEmail,
    'type': type.name,
    'title': title,
    'description': description,
    'severity': severity.name,
    'activeThreat': activeThreat,
    'latitude': latitude,
    'longitude': longitude,
    'locationAccuracyMeters': locationAccuracyMeters,
    'parkOrBlock': parkOrBlock,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'evidence': evidence.map((item) => item.toJson()).toList(),
    'patrolId': patrolId,
    'manualLocation': manualLocation,
    'workflowStatus': workflowStatus.name,
    'assignmentKind': assignmentKind.name,
    'assignedRangerIds': assignedRangerIds,
    'assignedRangerNames': assignedRangerNames,
  };

  factory IncidentReport.fromJson(Map<String, dynamic> json) => IncidentReport(
    id: json['id'] as String,
    rangerId: json['rangerId'] as String,
    rangerEmail: json['rangerEmail'] as String? ?? '',
    type: IncidentType.values.byName(json['type'] as String),
    title: json['title'] as String,
    description: json['description'] as String,
    severity: IncidentSeverity.values.byName(json['severity'] as String),
    activeThreat: json['activeThreat'] as bool? ?? false,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    locationAccuracyMeters: (json['locationAccuracyMeters'] as num?)
        ?.toDouble(),
    parkOrBlock: json['parkOrBlock'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: IncidentStatus.values.byName(json['status'] as String),
    evidence: (json['evidence'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              IncidentEvidence.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false),
    patrolId: json['patrolId'] as String?,
    manualLocation: json['manualLocation'] as bool? ?? false,
    workflowStatus: IncidentWorkflowStatus.values.firstWhere(
      (value) => value.name == json['workflowStatus'],
      orElse: () => IncidentWorkflowStatus.reported,
    ),
    assignmentKind: IncidentAssignmentKind.values.firstWhere(
      (value) => value.name == json['assignmentKind'],
      orElse: () => IncidentAssignmentKind.ranger,
    ),
    assignedRangerIds: (json['assignedRangerIds'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false),
    assignedRangerNames:
        (json['assignedRangerNames'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
  );
}
