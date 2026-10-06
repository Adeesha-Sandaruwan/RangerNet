import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/incident_report.dart';

class IncidentCloudRepository {
  IncidentCloudRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

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
  }
}
