// Represents one dated action in an incident's history.
class IncidentTimelineEvent {
  const IncidentTimelineEvent({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorName,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String actorId;
  final String actorName;
  final String message;
  final DateTime createdAt;

  // Read the saved action fields and fill defaults for older history records.
  factory IncidentTimelineEvent.fromDocument(
    String id,
    Map<String, dynamic> data,
    DateTime createdAt,
  ) {
    return IncidentTimelineEvent(
      id: id,
      type: data['type']?.toString() ?? 'update',
      actorId: data['actorId']?.toString() ?? '',
      actorName: data['actorName']?.toString() ?? 'RangerNet user',
      message: data['message']?.toString() ?? '',
      createdAt: createdAt,
    );
  }
}
