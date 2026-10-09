// Reads and writes ranger incident reports in Cloud Firestore.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/incident_report.dart';

/// Handles the reporting ranger's Firestore reads and upload process.
class IncidentCloudRepository {
  IncidentCloudRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Loads only the signed-in ranger's reports. The Firestore rules enforce
  /// the same ownership check on the server.
  // Load only reports created by the signed-in ranger.
  Future<List<IncidentReport>> loadReportsForRanger(String rangerId) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != rangerId) {
      throw StateError('Sign in as the reporting ranger to load reports.');
    }

    final snapshot = await _firestore
        .collection('incidents')
        .where('rangerId', isEqualTo: rangerId)
        .get();

    final reports =
        snapshot.docs
            .map((document) => _reportFromDocument(document.data()))
            .toList(growable: true)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports;
  }

  // Convert a Firestore document into the app's incident model.
  IncidentReport _reportFromDocument(Map<String, dynamic> data) {
    final created = data['createdAtClient'];
    final createdAt = created is Timestamp
        ? created.toDate()
        : DateTime.tryParse(created?.toString() ?? '') ?? DateTime.now();
    final rawStatus = data['status']?.toString().toLowerCase();
    final status = rawStatus == 'reported'
        ? IncidentStatus.reported
        : IncidentStatus.pendingSync;

    return IncidentReport(
      id: data['incidentId']?.toString() ?? '',
      rangerId: data['rangerId']?.toString() ?? '',
      rangerEmail: data['rangerEmail']?.toString() ?? '',
      type: IncidentType.values.byName(data['type']?.toString() ?? 'other'),
      title: data['title']?.toString() ?? 'Wildlife incident',
      description: data['description']?.toString() ?? '',
      severity: IncidentSeverity.values.byName(
        data['severity']?.toString() ?? 'medium',
      ),
      activeThreat: data['activeThreat'] == true,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      locationAccuracyMeters: (data['locationAccuracyMeters'] as num?)
          ?.toDouble(),
      parkOrBlock: data['parkOrBlock']?.toString() ?? '',
      createdAt: createdAt,
      status: status,
      evidence: const [],
      patrolId: data['patrolId']?.toString(),
      manualLocation: data['locationSource'] == 'manual',
      workflowStatus: IncidentWorkflowStatus.values.firstWhere(
        (value) => value.name == data['workflowStatus'],
        orElse: () => IncidentWorkflowStatus.reported,
      ),
      assignmentKind: IncidentAssignmentKind.values.firstWhere(
        (value) => value.name == data['assignmentType'],
        orElse: () => IncidentAssignmentKind.ranger,
      ),
      assignedRangerIds:
          (data['assignedRangerIds'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toList(growable: false),
      assignedRangerNames:
          (data['assignedRangerNames'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toList(growable: false),
    );
  }

  // Upload the report and photos, mark it reported, then write its history event.
  Future<void> publish(IncidentReport report) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != report.rangerId) {
      throw StateError('Sign in as the reporting ranger before syncing.');
    }

    final incident = _firestore.collection('incidents').doc(report.id);
    final metadata = <String, Object?>{
      'incidentId': report.id,
      'rangerId': report.rangerId,
      'rangerEmail': report.rangerEmail,
      'type': report.type.name,
      'typeLabel': report.type.label,
      'title': report.title,
      'description': report.description,
      'severity': report.severity.name,
      'activeThreat': report.activeThreat,
      'latitude': report.latitude,
      'longitude': report.longitude,
      'locationAccuracyMeters': report.locationAccuracyMeters,
      'locationSource': report.manualLocation ? 'manual' : 'gps',
      'parkOrBlock': report.parkOrBlock,
      'patrolId': report.patrolId,
      'createdAtClient': Timestamp.fromDate(report.createdAt.toUtc()),
      'evidenceCount': report.evidence.length,
      'workflowStatus': report.workflowStatus.name,
      'assignmentType': report.assignmentKind.name,
      'assignedRangerIds': report.assignedRangerIds,
      'assignedRangerNames': report.assignedRangerNames,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // A previous attempt can have uploaded the incident successfully but
    // failed while saving its final timeline event. Read the server copy first
    // so a retry never changes a Reported record back to Uploading (which the
    // rules correctly reject).
    // Do not read the document path directly here: Firestore rules deny a
    // ranger's get() when that document does not exist. This owner-filtered
    // query is authorized by the same rangerId rule as the submitted reports
    // list and safely returns no documents for a new incident.
    // This owner-filtered query can safely return no result for a new report.
    final existingSnapshot = await _firestore
        .collection('incidents')
        .where('incidentId', isEqualTo: report.id)
        .where('rangerId', isEqualTo: user.uid)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (existingSnapshot.docs.isNotEmpty) {
      final existing = existingSnapshot.docs.first.data();
      if (existing['rangerId'] != user.uid) {
        throw StateError('This incident ID belongs to another ranger.');
      }

      final status = existing['status']?.toString();
      if (status == 'Reported') {
        // The evidence is uploaded before status becomes Reported. Only make
        // sure the final timeline event exists, then let the caller clear the
        // local outbox entry.
        await _ensureSubmittedTimelineEvent(incident, report);
        return;
      }
      if (status != 'Uploading') {
        throw StateError(
          'This incident is already in the "$status" state and cannot be uploaded again.',
        );
      }
    } else {
      // Create the parent first so owner rules can authorize evidence writes.
      await incident.set({...metadata, 'status': 'Uploading'});
    }

    // Upload every photo before marking the whole report as complete.
    for (final evidence in report.evidence) {
      await incident.collection('evidence').doc(evidence.id).set({
        'fileName': evidence.fileName,
        'contentType': evidence.contentType,
        'base64Data': evidence.base64Data,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await incident.set({
      'status': 'Reported',
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _ensureSubmittedTimelineEvent(incident, report);
  }

  // Create the first history entry once; safely skip it on a retry.
  Future<void> _ensureSubmittedTimelineEvent(
    DocumentReference<Map<String, dynamic>> incident,
    IncidentReport report,
  ) async {
    final event = incident.collection('timeline').doc('reportSubmitted');
    final existing = await event.get(const GetOptions(source: Source.server));
    if (existing.exists) {
      final data = existing.data()!;
      if (data['actorId'] != report.rangerId ||
          data['type'] != 'reportSubmitted') {
        throw StateError(
          'The incident has a conflicting submission history entry.',
        );
      }
      return;
    }

    await event.set({
      'actorId': report.rangerId,
      'actorName': report.rangerEmail.isEmpty
          ? 'Reporting ranger'
          : report.rangerEmail,
      'type': 'reportSubmitted',
      'message': 'Incident report submitted by the ranger.',
      'createdAt': Timestamp.fromDate(report.createdAt.toUtc()),
    });
  }
}
