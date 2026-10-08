import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/incident_report.dart';

class IncidentCloudRepository {
  IncidentCloudRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Loads only the signed-in ranger's reports. The Firestore rules enforce
  /// the same ownership check on the server.
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

    // Create the parent first so authenticated-owner rules can authorize its
    // evidence subcollection. Repeating this method is safe: document IDs are
    // stable and every write is an idempotent set.
    await incident.set({
      ...metadata,
      'status': 'Uploading',
    }, SetOptions(merge: true));
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
    await incident.collection('timeline').doc('reportSubmitted').set({
      'actorId': report.rangerId,
      'actorName': report.rangerEmail.isEmpty
          ? 'Reporting ranger'
          : report.rangerEmail,
      'type': 'reportSubmitted',
      'message': 'Incident report submitted by the ranger.',
      // Keep the initial event's payload stable so retries are idempotent.
      'createdAt': Timestamp.fromDate(report.createdAt.toUtc()),
    }, SetOptions(merge: true));
  }
}
