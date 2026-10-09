import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/patrol.dart';
import '../domain/patrol_records.dart';
import '../domain/patrol_repository.dart';
import '../application/patrol_metrics_service.dart';
import 'patrol_route_plan_codec.dart';

/// Firestore patrol-sync repository adapter. DIP/LSP: implements PatrolSyncRepository for cloud persistence.
class FirestorePatrolSyncRepository implements PatrolSyncRepository {
  /// Creates the sync adapter with injectable Firestore and authentication clients.
  FirestorePatrolSyncRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  /// Firestore client used to persist remote patrol documents and records.
  final FirebaseFirestore _firestore;

  /// Authentication client used to verify ownership before syncing.
  final FirebaseAuth _auth;

  /// Domain metrics calculator used for the remote patrol summary.
  static const _metrics = PatrolMetricsService();

  /// Uploads a completed patrol and confirms its synced state after writing its records.
  @override
  Future<void> syncCompletedPatrol(Patrol patrol) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != patrol.rangerId) {
      throw StateError('Sign in as the assigned ranger before syncing.');
    }
    if (patrol.status != PatrolStatus.completedPendingSync &&
        patrol.status != PatrolStatus.completedSynced) {
      throw StateError('Only completed patrols can be synchronized.');
    }

    final reference = _firestore.collection('patrols').doc(patrol.patrolId);
    final existingSnapshot = await _firestore
        .collection('patrols')
        .where('patrolId', isEqualTo: patrol.patrolId)
        .where('rangerId', isEqualTo: user.uid)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (existingSnapshot.docs.isNotEmpty) {
      final data = existingSnapshot.docs.first.data();
      if (data['rangerId'] != user.uid) {
        throw StateError('This patrol ID belongs to another ranger.');
      }
      if (data['status'] == PatrolStatus.completedSynced.name) return;
      if (data['status'] != PatrolStatus.completedPendingSync.name) {
        throw StateError(
          'The remote patrol is in an unexpected state and cannot be completed.',
        );
      }
    } else {
      await reference.set({
        ..._metadata(patrol),
        'status': PatrolStatus.completedPendingSync.name,
      });
    }

    await _writeRecords(
      reference,
      'routePoints',
      patrol.routePoints.map(
        (item) => (item.id, {'id': item.id, ..._locationData(item.location)}),
      ),
    );
    await _writeRecords(
      reference,
      'manualWaypoints',
      patrol.manualWaypoints.map(
        (item) => (
          item.id,
          {
            'id': item.id,
            'description': item.description,
            ..._locationData(item.location),
          },
        ),
      ),
    );
    await _writeRecords(
      reference,
      'observations',
      patrol.observations.map(
        (item) => (
          item.id,
          {
            'id': item.id,
            'description': item.description,
            'category': item.category,
            ..._locationData(item.location),
          },
        ),
      ),
    );
    await _writeRecords(
      reference,
      'photographs',
      patrol.photographs.map(
        (item) => (
          item.id,
          {
            'id': item.id,
            'fileName': item.fileName,
            'contentType': item.contentType,
            'base64Data': item.base64Data,
            'capturedAt': Timestamp.fromDate(item.capturedAt.toUtc()),
            'observationId': item.observationId,
          },
        ),
      ),
    );
    await _writeRecords(
      reference,
      'pauseResumeEvents',
      patrol.pauseResumeEvents.map(
        (item) => (
          item.id,
          {
            'id': item.id,
            'action': item.action.name,
            'occurredAt': Timestamp.fromDate(item.occurredAt.toUtc()),
            'reason': item.reason,
          },
        ),
      ),
    );

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw StateError('Patrol synchronization record was not created.');
      }
      final data = snapshot.data()!;
      if (data['rangerId'] != user.uid) {
        throw StateError('This patrol ID belongs to another ranger.');
      }
      if (data['status'] == PatrolStatus.completedSynced.name) return;
      if (data['status'] != PatrolStatus.completedPendingSync.name) {
        throw StateError(
          'The remote patrol changed before completion could be confirmed.',
        );
      }
      transaction.update(reference, {
        ..._metadata(patrol),
        'status': PatrolStatus.completedSynced.name,
        'lastSyncedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 'Writes a named set of patrol subcollection records in bounded Firestore batches.'
  Future<void> _writeRecords(
    DocumentReference<Map<String, dynamic>> parent,
    String collection,
    Iterable<(String, Map<String, Object?>)> records,
  ) async {
    const allowedCollections = {
      'routePoints',
      'manualWaypoints',
      'observations',
      'photographs',
      'pauseResumeEvents',
    };
    if (!allowedCollections.contains(collection)) {
      throw ArgumentError.value(
        collection,
        'collection',
        'Not a patrol record collection.',
      );
    }
    var batch = _firestore.batch();
    var batchSize = 0;
    for (final record in records) {
      batch.set(
        parent.collection(collection).doc(record.$1),
        record.$2,
        SetOptions(merge: true),
      );
      batchSize++;
      // Flush below Firestore's 500-write batch limit.
      if (batchSize == 450) {
        await batch.commit();
        batch = _firestore.batch();
        batchSize = 0;
      }
    }
    if (batchSize > 0) await batch.commit();
  }

  /// Builds the patrol-level Firestore document fields.
  Map<String, Object?> _metadata(Patrol patrol) => {
    'patrolId': patrol.patrolId,
    'localId': patrol.localId,
    'rangerId': patrol.rangerId,
    'rangerName': patrol.rangerName,
    'parkId': patrol.area.parkId,
    'parkName': patrol.area.parkName,
    'zoneId': patrol.area.zoneId,
    'zoneName': patrol.area.zoneName,
    'routeId': patrol.area.routeId,
    'routeName': patrol.area.routeName,
    'plannedRoute': patrol.plannedRoute == null
        ? null
        : PatrolRoutePlanCodec.encode(patrol.plannedRoute!),
    'assignedAt': patrol.assignedAt == null
        ? null
        : Timestamp.fromDate(patrol.assignedAt!.toUtc()),
    'startedAt': Timestamp.fromDate(patrol.startedAt!.toUtc()),
    'endedAt': Timestamp.fromDate(patrol.endedAt!.toUtc()),
    'startLocation': _locationData(patrol.startLocation!),
    'endLocation': patrol.endLocation == null
        ? null
        : _locationData(patrol.endLocation!),
    'distanceTravelledMeters': _metrics.distanceTravelledMeters(patrol),
    'durationSeconds': _metrics.durationAt(patrol, patrol.endedAt!).inSeconds,
    'earlyTerminationReason': patrol.earlyTerminationReason,
    'interruptionReason': patrol.interruptionReason,
    'coverage': patrol.coverage == null
        ? null
        : {
            'totalSections': patrol.coverage!.totalSections,
            'coveredSections': patrol.coverage!.coveredSections,
            'coveredSectionIds': patrol.coverage!.coveredSectionIds,
            'uncoveredSectionIds': patrol.coverage!.uncoveredSectionIds,
            'calculatedAt': Timestamp.fromDate(
              patrol.coverage!.calculatedAt.toUtc(),
            ),
          },
  };

  /// Encodes one location as Firestore-compatible coordinate and timestamp values.
  Map<String, Object?> _locationData(PatrolLocation location) => {
    'latitude': location.latitude,
    'longitude': location.longitude,
    'recordedAt': Timestamp.fromDate(location.recordedAt.toUtc()),
    'source': location.source.name,
    'accuracyMeters': location.accuracyMeters,
  };
}
