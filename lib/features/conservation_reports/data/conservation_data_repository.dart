import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../incidents/domain/incident_report.dart';
import '../../incidents/domain/ranger_profile.dart';

/// Firestore data access for UC04 conservation report generation.
///
/// Provides read-only queries that load all incidents (regardless of
/// workflow status) and active ranger profiles for filter options.
class ConservationDataRepository {
  ConservationDataRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Loads every incident in Firestore, regardless of status.
  /// Only managers should call this (enforced by Firestore rules).
  Future<List<IncidentReport>> loadAllIncidents() async {
    _requireSignedIn();
    final snapshot = await _firestore.collection('incidents').get();
    return snapshot.docs
        .map((doc) => _reportFromDocument(doc.data()))
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Returns every unique `parkOrBlock` value across all incidents,
  /// sorted alphabetically, for the park filter dropdown.
  Future<List<String>> loadDistinctParks() async {
    final incidents = await loadAllIncidents();
    final parks = incidents
        .map((i) => i.parkOrBlock.trim())
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return parks;
  }

  /// Returns all active ranger profiles for the patrol-team filter.
  Future<List<RangerProfile>> loadActiveRangers() async {
    _requireSignedIn();
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: RangerRole.ranger.name)
        .get();
    return snapshot.docs
        .map((doc) => RangerProfile.fromMap(doc.id, doc.data()))
        .where((profile) => profile.active)
        .toList(growable: false);
  }

  // ──────────────────────────── Internals ────────────────────────────

  User _requireSignedIn() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to generate reports.');
    return user;
  }

  IncidentReport _reportFromDocument(Map<String, dynamic> data) {
    final created = data['createdAtClient'];
    final createdAt = created is Timestamp
        ? created.toDate()
        : DateTime.tryParse(created?.toString() ?? '') ?? DateTime.now();
    return IncidentReport(
      id: data['incidentId']?.toString() ?? '',
      rangerId: data['rangerId']?.toString() ?? '',
      rangerEmail: data['rangerEmail']?.toString() ?? '',
      type: _enumValue(IncidentType.values, data['type'], IncidentType.other),
      title: data['title']?.toString() ?? 'Wildlife incident',
      description: data['description']?.toString() ?? '',
      severity: _enumValue(
        IncidentSeverity.values,
        data['severity'],
        IncidentSeverity.medium,
      ),
      activeThreat: data['activeThreat'] == true,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      locationAccuracyMeters:
          (data['locationAccuracyMeters'] as num?)?.toDouble(),
      parkOrBlock: data['parkOrBlock']?.toString() ?? '',
      createdAt: createdAt,
      status: data['status']?.toString().toLowerCase() == 'reported'
          ? IncidentStatus.reported
          : IncidentStatus.pendingSync,
      evidence: const [],
      patrolId: data['patrolId']?.toString(),
      manualLocation: data['locationSource'] == 'manual',
      workflowStatus: _enumValue(
        IncidentWorkflowStatus.values,
        data['workflowStatus'],
        IncidentWorkflowStatus.reported,
      ),
      assignmentKind: _enumValue(
        IncidentAssignmentKind.values,
        data['assignmentType'],
        IncidentAssignmentKind.ranger,
      ),
      assignedRangerIds: _stringList(data['assignedRangerIds']),
      assignedRangerNames: _stringList(data['assignedRangerNames']),
    );
  }

  List<String> _stringList(Object? value) => value is Iterable
      ? value.map((item) => item.toString()).toList(growable: false)
      : const [];

  T _enumValue<T extends Enum>(List<T> values, Object? value, T fallback) =>
      values.firstWhere((item) => item.name == value, orElse: () => fallback);
}
