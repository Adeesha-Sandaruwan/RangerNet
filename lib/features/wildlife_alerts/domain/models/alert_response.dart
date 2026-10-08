class AlertResponse {
  const AlertResponse({
    required this.responseId,
    required this.alertId,
    required this.rangerId,
    required this.actionTaken,
    required this.observations,
    required this.timestamp,
    this.rangerName,
    this.photoUrls = const [],
    this.followUpRequired = false,
  });

  final String responseId;
  final String alertId;
  final String rangerId;
  final String actionTaken;
  final String observations;
  final DateTime timestamp;
  final String? rangerName;
  final List<String> photoUrls;
  final bool followUpRequired;

  Map<String, dynamic> toJson() => {
    'responseId': responseId,
    'alertId': alertId,
    'rangerId': rangerId,
    'actionTaken': actionTaken,
    'observations': observations,
    'timestamp': timestamp.toIso8601String(),
    'rangerName': rangerName,
    'photoUrls': photoUrls,
    'followUpRequired': followUpRequired,
  };

  factory AlertResponse.fromJson(Map<String, dynamic> json) => AlertResponse(
    responseId: json['responseId'] as String,
    alertId: json['alertId'] as String,
    rangerId: json['rangerId'] as String,
    actionTaken: json['actionTaken'] as String,
    observations: json['observations'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    rangerName: json['rangerName'] as String?,
    photoUrls: (json['photoUrls'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList(),
    followUpRequired: json['followUpRequired'] as bool? ?? false,
  );
}
