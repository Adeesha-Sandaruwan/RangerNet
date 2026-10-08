import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../domain/patrol_assignment.dart';
import '../domain/patrol_assignment_repository.dart';
import '../domain/patrol_records.dart';

class FirestorePatrolAssignmentRepository
    implements PatrolAssignmentRepository {
  FirestorePatrolAssignmentRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Uuid? uuid,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Uuid _uuid;

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

  @override
  Future<List<PatrolAssignment>> loadAssignments() async {
    _requireSignedIn();
    final snapshot = await _firestore
        .collection('patrolAssignments')
        .orderBy('assignedAt', descending: true)
        .get();
    return snapshot.docs.map(_assignmentFromDocument).toList(growable: false);
  }

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
      'plannedCoverageSections': draft.plannedCoverageSections
          .map(_coverageSectionData)
          .toList(),
      'assignedAt': FieldValue.serverTimestamp(),
      'assignedBy': manager.uid,
    };
    _putOptional(data, 'parkId', draft.parkId);
    _putOptional(data, 'zoneId', draft.zoneId);
    _putOptional(data, 'routeId', draft.routeId);
    if (draft.centerLatitude != null) {
      data['centerLatitude'] = draft.centerLatitude;
      data['centerLongitude'] = draft.centerLongitude;
    }

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
        centerLatitude: draft.centerLatitude,
        centerLongitude: draft.centerLongitude,
      ),
      assignedAt: DateTime.now().toUtc(),
      plannedCoverageSections: draft.plannedCoverageSections,
    );
  }

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
    final rawSections = data['plannedCoverageSections'];
    if (rawSections != null && rawSections is! List) {
      throw FormatException(
        'Assignment ${document.id} has invalid coverage sections.',
      );
    }
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
        centerLatitude: latitude,
        centerLongitude: longitude,
      ),
      assignedAt:
          assignedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      plannedCoverageSections: (rawSections as List? ?? []).map((value) {
        if (value is! Map) {
          throw FormatException(
            'Assignment ${document.id} has an invalid coverage section.',
          );
        }
        final section = Map<String, dynamic>.from(value);
        final sectionLatitude = section['latitude'];
        final sectionLongitude = section['longitude'];
        if (section['id'] is! String ||
            section['name'] is! String ||
            sectionLatitude is! num ||
            sectionLongitude is! num) {
          throw FormatException(
            'Assignment ${document.id} has an incomplete coverage section.',
          );
        }
        return PatrolCoverageCheckpoint(
          id: section['id'] as String,
          name: section['name'] as String,
          latitude: sectionLatitude.toDouble(),
          longitude: sectionLongitude.toDouble(),
        );
      }),
    );
  }

  Map<String, Object?> _coverageSectionData(
    PatrolCoverageCheckpoint section,
  ) => {
    'id': section.id,
    'name': section.name,
    'latitude': section.latitude,
    'longitude': section.longitude,
  };

  User _requireSignedIn() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in with a manager account to manage assignments.');
    }
    return user;
  }

  void _putOptional(Map<String, Object?> data, String key, String? value) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) data[key] = normalized;
  }
}
