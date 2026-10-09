import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../domain/patrol_assignment.dart';
import '../domain/patrol_assignment_repository.dart';
import '../domain/patrol_records.dart';
import 'patrol_route_plan_codec.dart';

/// Firestore assignment repository adapter. DIP/LSP: implements PatrolAssignmentRepository for the manager workflow.
class FirestorePatrolAssignmentRepository
    implements PatrolAssignmentRepository {
  /// Creates the repository with injectable Firestore, authentication, and ID-generation dependencies.
  FirestorePatrolAssignmentRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Uuid? uuid,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _uuid = uuid ?? const Uuid();

  /// Firestore client used to read and write assignment records.
  final FirebaseFirestore _firestore;
  /// Authentication client used to require a signed-in manager.
  final FirebaseAuth _auth;
  /// ID generator used for new assignment document identifiers.
  final Uuid _uuid;

  /// Loads active ranger accounts available for assignment.
  @override
  Future<List<PatrolRanger>> loadActiveRangers() async {
    _requireSignedIn();
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'ranger')
        .get();
    return snapshot.docs
        .where((document) => document.data()['active'] != false)
        .map((document) {
          final data = document.data();
          return PatrolRanger(
            id: document.id,
            name: data['displayName']?.toString() ?? '',
            email: data['email']?.toString() ?? '',
          );
        })
        .toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
  }

  /// Loads assignments ordered by their assignment timestamp.
  @override
  Future<List<PatrolAssignment>> loadAssignments() async {
    _requireSignedIn();
    final snapshot = await _firestore
        .collection('patrolAssignments')
        .orderBy('assignedAt', descending: true)
        .get();
    return snapshot.docs.map(_assignmentFromDocument).toList(growable: false);
  }

  /// Validates and transactionally creates a manager-provided patrol assignment.
  @override
  Future<PatrolAssignment> createAssignment(PatrolAssignmentDraft draft) async {
    final manager = _requireSignedIn();
    draft.validate();
    final id = _uuid.v4();
    final reference = _firestore.collection('patrolAssignments').doc(id);
    final data = <String, Object?>{
      'assignedRangerId': draft.ranger.id,
      'assignedRangerName': draft.ranger.name,
      'parkName': draft.parkName.trim(),
      'zoneName': draft.zoneName.trim(),
      'routeName': draft.routeName.trim(),
      'plannedRoute': PatrolRoutePlanCodec.encode(draft.plannedRoute),
      'assignedAt': FieldValue.serverTimestamp(),
      'assignedBy': manager.uid,
    };
    _putOptional(data, 'parkId', draft.parkId);
    _putOptional(data, 'zoneId', draft.zoneId);
    _putOptional(data, 'routeId', draft.routeId);
    data['centerLatitude'] = draft.plannedRoute.start.latitude;
    data['centerLongitude'] = draft.plannedRoute.start.longitude;

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists) {
        throw StateError('A patrol assignment with this ID already exists.');
      }
      transaction.set(reference, data);
    });
    return PatrolAssignment(
      id: id,
      rangerId: draft.ranger.id,
      rangerName: draft.ranger.name,
      area: PatrolArea(
        parkId: draft.parkId,
        parkName: draft.parkName.trim(),
        zoneId: draft.zoneId,
        zoneName: draft.zoneName.trim(),
        routeId: draft.routeId,
        routeName: draft.routeName.trim(),
        centerLatitude: draft.plannedRoute.start.latitude,
        centerLongitude: draft.plannedRoute.start.longitude,
      ),
      assignedAt: DateTime.now().toUtc(),
      plannedRoute: draft.plannedRoute,
    );
  }

  /// Maps one Firestore assignment document into a domain assignment.
  PatrolAssignment _assignmentFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final assignedAtValue = data['assignedAt'];
    final assignedAt = switch (assignedAtValue) {
      Timestamp timestamp => timestamp.toDate(),
      String value => DateTime.tryParse(value),
      _ => null,
    };
    final latitude = (data['centerLatitude'] as num?)?.toDouble();
    final longitude = (data['centerLongitude'] as num?)?.toDouble();
    if ((latitude == null) != (longitude == null)) {
      throw FormatException(
        'Assignment ${document.id} has incomplete map-center coordinates.',
      );
    }
    final plannedRoute = data['plannedRoute'] == null
        ? null
        : PatrolRoutePlanCodec.decode(data['plannedRoute']);
    return PatrolAssignment(
      id: document.id,
      rangerId: data['assignedRangerId']?.toString() ?? '',
      rangerName: data['assignedRangerName']?.toString() ?? '',
      area: PatrolArea(
        parkId: data['parkId']?.toString(),
        parkName: data['parkName']?.toString() ?? '',
        zoneId: data['zoneId']?.toString(),
        zoneName: data['zoneName']?.toString() ?? '',
        routeId: data['routeId']?.toString(),
        routeName: data['routeName']?.toString() ?? '',
        centerLatitude: plannedRoute?.start.latitude ?? latitude,
        centerLongitude: plannedRoute?.start.longitude ?? longitude,
      ),
      assignedAt:
          assignedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      plannedRoute: plannedRoute,
    );
  }

  /// Requires an authenticated user before accessing manager assignment operations.
  User _requireSignedIn() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in with a manager account to manage assignments.');
    }
    return user;
  }

  /// Adds an optional assignment field only when its trimmed value is non-empty.
  void _putOptional(Map<String, Object?> data, String key, String? value) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) data[key] = normalized;
  }
}
