import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/patrol_records.dart';
import '../domain/patrol_review.dart';
import '../domain/patrol_review_repository.dart';
import 'patrol_codec.dart';

/// Firestore review repository adapter. DIP/LSP: implements PatrolReviewRepository so review workflows depend on the port.
class FirestorePatrolReviewRepository implements PatrolReviewRepository {
  /// Creates the repository with injectable Firestore and authentication clients.
  FirestorePatrolReviewRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  /// Firestore client used to load patrols and save review fields.
  final FirebaseFirestore _firestore;

  /// Authentication client used to require the reviewing manager.
  final FirebaseAuth _auth;

  /// Loads server-confirmed completed patrols and their associated review records.
  @override
  Future<List<PatrolReviewRecord>> loadCompletedPatrols() async {
    _requireSignedIn();
    final snapshot = await _firestore
        .collection('patrols')
        .where('status', isEqualTo: PatrolStatus.completedSynced.name)
        .get(const GetOptions(source: Source.server));
    final reviews = await Future.wait(snapshot.docs.map(_loadReviewRecord));
    reviews.sort((first, second) {
      final firstEnd = first.patrol.endedAt;
      final secondEnd = second.patrol.endedAt;
      if (firstEnd == null) return 1;
      if (secondEnd == null) return -1;
      return secondEnd.compareTo(firstEnd);
    });
    return List.unmodifiable(reviews);
  }

  /// Loads the review record from one patrol document and its subcollections.
  Future<PatrolReviewRecord> _loadReviewRecord(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    return _decodeReviewRecord(
      id: document.id,
      reference: document.reference,
      data: document.data(),
    );
  }

  /// Reconstructs a patrol and review from the Firestore document and record subcollections.
  Future<PatrolReviewRecord> _decodeReviewRecord({
    required String id,
    required DocumentReference<Map<String, dynamic>> reference,
    required Map<String, dynamic> data,
  }) async {
    final snapshots = await Future.wait([
      reference.collection('routePoints').get(),
      reference.collection('manualWaypoints').get(),
      reference.collection('observations').get(),
      reference.collection('photographs').get(),
      reference.collection('pauseResumeEvents').get(),
    ]);
    final routePoints = snapshots[0].docs
        .map((record) => _routePoint(record.data()))
        .toList();
    final waypoints = snapshots[1].docs
        .map((record) => _waypoint(record.data()))
        .toList();
    final observations = snapshots[2].docs
        .map((record) => _observation(record.data()))
        .toList();
    final photographs = snapshots[3].docs
        .map((record) => _photograph(record.data()))
        .toList();
    final events = snapshots[4].docs
        .map((record) => _pauseResumeEvent(record.data()))
        .toList();
    final patrol = PatrolCodec.decode({
      'patrolId': data['patrolId']?.toString() ?? id,
      'localId': data['localId']?.toString() ?? 'remote-$id',
      'rangerId': data['rangerId'],
      'rangerName': data['rangerName'] ?? '',
      'area': {
        'parkId': data['parkId'],
        'parkName': data['parkName'] ?? '',
        'zoneId': data['zoneId'],
        'zoneName': data['zoneName'] ?? '',
        'routeId': data['routeId'],
        'routeName': data['routeName'] ?? '',
        'centerLatitude': data['centerLatitude'],
        'centerLongitude': data['centerLongitude'],
      },
      'plannedRoute': data['plannedRoute'],
      'status': data['status'],
      'assignedAt': _isoValue(data['assignedAt']),
      'startedAt': _isoValue(data['startedAt']),
      'endedAt': _isoValue(data['endedAt']),
      'startLocation': _normalize(data['startLocation']),
      'endLocation': _normalize(data['endLocation']),
      'routePoints': routePoints,
      'manualWaypoints': waypoints,
      'observations': observations,
      'photographs': photographs,
      'pauseResumeEvents': events,
      'earlyTerminationReason': data['earlyTerminationReason'],
      'interruptionReason': data['interruptionReason'],
      'syncInfo': {
        'status': PatrolSyncStatus.synced.name,
        'lastAttemptAt': _isoValue(data['lastSyncedAt']),
        'lastSyncedAt': _isoValue(data['lastSyncedAt']),
        'lastError': null,
      },
      'coverage': _normalize(data['coverage']),
    });
    final reviewStatus = switch (data['managerReviewStatus']) {
      'reviewed' => PatrolManagerReviewStatus.reviewed,
      'followUpRequired' => PatrolManagerReviewStatus.followUpRequired,
      null || 'pending' => PatrolManagerReviewStatus.pending,
      final value => throw FormatException(
        'Patrol field "managerReviewStatus" has an unknown value: $value.',
      ),
    };
    return PatrolReviewRecord(
      patrol: patrol,
      reviewStatus: reviewStatus,
      reviewedAt: _dateOrNull(data['reviewedAt']),
      reviewedBy: data['reviewedBy']?.toString(),
      managerNotes: data['managerNotes']?.toString(),
      followUpRequired: data['followUpRequired'] == true,
    );
  }

  Map<String, Object?> _routePoint(Map<String, dynamic> data) => {
    'id': data['id'],
    'location': _location(data),
  };

  Map<String, Object?> _waypoint(Map<String, dynamic> data) => {
    'id': data['id'],
    'description': data['description'] ?? '',
    'location': _location(data),
  };

  Map<String, Object?> _observation(Map<String, dynamic> data) => {
    'id': data['id'],
    'description': data['description'] ?? '',
    'category': data['category'],
    'location': _location(data),
  };

  Map<String, Object?> _photograph(Map<String, dynamic> data) => {
    ...data,
    'capturedAt': _isoValue(data['capturedAt']),
  };

  Map<String, Object?> _pauseResumeEvent(Map<String, dynamic> data) => {
    ...data,
    'occurredAt': _isoValue(data['occurredAt']),
  };

  Map<String, Object?> _location(Map<String, dynamic> data) => {
    'latitude': data['latitude'],
    'longitude': data['longitude'],
    'recordedAt': _isoValue(data['recordedAt']),
    'source': data['source'],
    'accuracyMeters': data['accuracyMeters'],
  };

  /// Recursively converts Firestore timestamps and map keys into values accepted by PatrolCodec.
  Object? _normalize(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _normalize(item)),
      );
    }
    if (value is List) return value.map(_normalize).toList(growable: false);
    return value;
  }

  /// Normalizes a Firestore value for the patrol JSON codec.
  Object? _isoValue(Object? value) => _normalize(value);

  /// Parses a nullable review timestamp after Firestore value normalization.
  DateTime? _dateOrNull(Object? value) {
    if (value == null) return null;
    final normalized = _isoValue(value);
    if (normalized is String) {
      final date = DateTime.tryParse(normalized);
      if (date != null) return date;
    }
    throw const FormatException('Patrol review timestamp is invalid.');
  }

  /// Saves a manager review and reloads its canonical server representation.
  @override
  Future<PatrolReviewRecord> saveReview({
    required String patrolId,
    required String managerId,
    required String notes,
    required bool followUpRequired,
  }) async {
    _requireManager(managerId);
    final reference = _firestore.collection('patrols').doc(patrolId);
    final now = DateTime.now().toUtc();
    await reference.update({
      'managerReviewStatus': 'reviewed',
      'reviewedAt': Timestamp.fromDate(now),
      'reviewedBy': managerId,
      'managerNotes': notes,
      'followUpRequired': followUpRequired,
    });
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (!snapshot.exists) {
      throw StateError('The patrol disappeared while saving its review.');
    }
    return _decodeReviewRecord(
      id: snapshot.id,
      reference: reference,
      data: snapshot.data()!,
    );
  }

  /// Marks a patrol for follow-up and reloads its canonical server representation.
  @override
  Future<PatrolReviewRecord> flagFollowUp({
    required String patrolId,
    required String managerId,
    required String notes,
  }) async {
    _requireManager(managerId);
    final reference = _firestore.collection('patrols').doc(patrolId);
    await reference.update({
      'managerReviewStatus': 'followUpRequired',
      'reviewedBy': managerId,
      'managerNotes': notes,
      'followUpRequired': true,
    });
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (!snapshot.exists) {
      throw StateError('The patrol disappeared while saving follow-up.');
    }
    return _decodeReviewRecord(
      id: snapshot.id,
      reference: reference,
      data: snapshot.data()!,
    );
  }

  /// Requires an authenticated user before loading manager review data.
  User _requireSignedIn() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in as a manager to review completed patrols.');
    }
    return user;
  }

  /// Ensures the supplied reviewer identity matches the signed-in manager.
  void _requireManager(String managerId) {
    final user = _requireSignedIn();
    if (user.uid != managerId) {
      throw StateError(
        'Only the signed-in manager can save this patrol review.',
      );
    }
  }
}
