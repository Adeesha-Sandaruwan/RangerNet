import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/patrol.dart';
import '../domain/patrol_records.dart';
import '../domain/patrol_repository.dart';
import 'patrol_route_plan_codec.dart';

/// Firestore assignment-source adapter. DIP/LSP: implements PatrolAssignmentSource for ranger assignment reads.
class FirestorePatrolAssignmentSource implements PatrolAssignmentSource {
  /// Creates the source with injectable Firestore and authentication clients.
  FirestorePatrolAssignmentSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  /// Firestore client used to query assigned patrol records.
  final FirebaseFirestore _firestore;
  /// Authentication client used to enforce the ranger identity.
  final FirebaseAuth _auth;
  /// Loads the ranger assignments from the Firestore server.
  @override
  Future<List<Patrol>> loadAssignedTo(String rangerId) async {
    final snapshot = await _assignedQuery(
      rangerId,
    ).get(const GetOptions(source: Source.server));
    return snapshot.docs.map(_fromAssignment).toList(growable: false);
  }

  /// Watches live Firestore changes to the ranger assignments.
  @override
  Stream<List<Patrol>> watchAssignedTo(String rangerId) =>
      _assignedQuery(rangerId).snapshots().map(
        (snapshot) =>
            snapshot.docs.map(_fromAssignment).toList(growable: false),
      );

  /// Builds the assignment query after verifying the signed-in user matches rangerId.
  Query<Map<String, dynamic>> _assignedQuery(String rangerId) {
    final user = _auth.currentUser;
    if (user == null || user.uid != rangerId) {
      throw StateError('Sign in as the assigned ranger to load patrols.');
    }
    return _firestore
        .collection('patrolAssignments')
        .where('assignedRangerId', isEqualTo: rangerId);
  }

  /// Maps one Firestore assignment document into a domain Patrol.
  Patrol _fromAssignment(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rangerId = data['assignedRangerId']?.toString() ?? '';
    if (rangerId.isEmpty) {
      throw FormatException('Patrol assignment ${doc.id} has no ranger ID.');
    }
    final assignedAtValue = data['assignedAt'];
    final assignedAt = switch (assignedAtValue) {
      Timestamp timestamp => timestamp.toDate(),
      String value => DateTime.tryParse(value),
      _ => null,
    };
    final centerLatitude = (data['centerLatitude'] as num?)?.toDouble();
    final centerLongitude = (data['centerLongitude'] as num?)?.toDouble();
    if ((centerLatitude == null) != (centerLongitude == null)) {
      throw FormatException(
        'Patrol assignment ${doc.id} must include both map center coordinates.',
      );
    }
    final plannedRoute = data['plannedRoute'] == null
        ? null
        : PatrolRoutePlanCodec.decode(data['plannedRoute']);
    final areaCenterLatitude = plannedRoute?.start.latitude ?? centerLatitude;
    final areaCenterLongitude =
        plannedRoute?.start.longitude ?? centerLongitude;
    return Patrol(
      patrolId: doc.id,
      localId: 'assignment-${doc.id}',
      rangerId: rangerId,
      rangerName: data['assignedRangerName']?.toString() ?? '',
      area: PatrolArea(
        parkId: data['parkId']?.toString(),
        parkName: data['parkName']?.toString() ?? '',
        zoneId: data['zoneId']?.toString(),
        zoneName: data['zoneName']?.toString() ?? '',
        routeId: data['routeId']?.toString(),
        routeName: data['routeName']?.toString() ?? '',
        centerLatitude: areaCenterLatitude,
        centerLongitude: areaCenterLongitude,
      ),
      status: PatrolStatus.assigned,
      assignedAt: assignedAt,
      plannedRoute: plannedRoute,
    );
  }
}
