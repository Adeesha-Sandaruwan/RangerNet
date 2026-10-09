// Handles Firestore reads and actions used by managers and responders.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../domain/incident_report.dart';
import '../domain/incident_timeline_event.dart';
import '../domain/ranger_profile.dart';
import '../domain/incident_workflow_policy.dart';
import '../domain/incident_management_ports.dart';

/// Firestore implementation of the manager and responder gateway contracts.
/// It can replace another implementation while keeping the same operations.
/// This class has the single job of managing UC02 data in Firestore.
/// Authorization is enforced by Firestore rules, not by this UI repository.
/// Keeps incident workflow database operations out of the screen widgets.
class IncidentManagementRepository
    implements IncidentManagerGateway, IncidentResponderGateway {
  IncidentManagementRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  static const _uuid = Uuid();
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Load all incidents the signed-in manager is allowed to see.
  @override
  Future<List<IncidentReport>> loadAllIncidents() async {
    _requireSignedIn();
    final snapshot = await _firestore.collection('incidents').get();
    return _sortReports(
      snapshot.docs.map((document) => _reportFromDocument(document.data())),
    );
  }

  // Listen for manager inbox changes as they arrive from Firestore.
  @override
  Stream<List<IncidentReport>> watchAllIncidents() {
    _requireSignedIn();
    return _firestore
        .collection('incidents')
        .snapshots()
        .map(
          (snapshot) => _sortReports(
            snapshot.docs.map(
              (document) => _reportFromDocument(document.data()),
            ),
          ),
        );
  }

  // Load one incident by its ID or explain if it no longer exists.
  @override
  Future<IncidentReport> loadIncident(String incidentId) async {
    _requireSignedIn();
    final snapshot = await _firestore
        .collection('incidents')
        .doc(incidentId)
        .get();
    final data = snapshot.data();
    if (data == null) throw StateError('This incident no longer exists.');
    return _reportFromDocument(data);
  }

  // Load the incidents assigned to this signed-in ranger.
  @override
  Future<List<IncidentReport>> loadAssignedIncidents(String rangerId) async {
    final user = _requireSignedIn();
    if (user.uid != rangerId) {
      throw StateError('You can only open incidents assigned to your account.');
    }
    final snapshot = await _firestore
        .collection('incidents')
        .where('assignedRangerIds', arrayContains: rangerId)
        .get();
    return _sortReports(
      snapshot.docs.map((document) => _reportFromDocument(document.data())),
    );
  }

  // Listen for new assignments and updates for this ranger.
  @override
  Stream<List<IncidentReport>> watchAssignedIncidents(String rangerId) {
    final user = _requireSignedIn();
    if (user.uid != rangerId) {
      throw StateError('You can only open incidents assigned to your account.');
    }
    return _firestore
        .collection('incidents')
        .where('assignedRangerIds', arrayContains: rangerId)
        .snapshots()
        .map(
          (snapshot) => _sortReports(
            snapshot.docs.map(
              (document) => _reportFromDocument(document.data()),
            ),
          ),
        );
  }

  // Give the manager the active ranger accounts available for assignment.
  @override
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

  // Load the incident's history, newest action first.
  @override
  Future<List<IncidentTimelineEvent>> loadTimeline(String incidentId) async {
    _requireSignedIn();
    final snapshot = await _firestore
        .collection('incidents')
        .doc(incidentId)
        .collection('timeline')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          final stamp = data['createdAt'];
          final date = stamp is Timestamp
              ? stamp.toDate()
              : DateTime.tryParse(stamp?.toString() ?? '') ?? DateTime.now();
          return IncidentTimelineEvent.fromDocument(doc.id, data, date);
        })
        .toList(growable: false);
  }

  // Load the photos attached to the original incident report.
  @override
  Future<List<IncidentEvidence>> loadIncidentEvidence(String incidentId) async {
    _requireSignedIn();
    final snapshot = await _firestore
        .collection('incidents')
        .doc(incidentId)
        .collection('evidence')
        .get();
    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          return IncidentEvidence(
            id: doc.id,
            fileName: data['fileName']?.toString() ?? 'Evidence photo',
            base64Data: data['base64Data']?.toString() ?? '',
            contentType: data['contentType']?.toString() ?? 'image/jpeg',
          );
        })
        .where((photo) => photo.base64Data.isNotEmpty)
        .toList(growable: false);
  }

  // Save the manager's review and its history entry together.
  @override
  Future<void> reviewIncident({
    required String incidentId,
    required IncidentSeverity severity,
    required String managerName,
    String note = '',
  }) async {
    final actor = _requireSignedIn();
    final incident = _firestore.collection('incidents').doc(incidentId);
    final current = await incident.get();
    IncidentWorkflowPolicy.validateReview(
      currentStatus: _enumValue(
        IncidentWorkflowStatus.values,
        current.data()?['workflowStatus'],
        IncidentWorkflowStatus.reported,
      ),
      severity: severity,
      note: note,
    );
    final event = incident.collection('timeline').doc(_uuid.v4());
    final batch = _firestore.batch();
    batch.update(incident, {
      'severity': severity.name,
      'workflowStatus': IncidentWorkflowStatus.underReview.name,
      'managerNote': note.trim(),
      if (severity == IncidentSeverity.critical)
        'escalationReason': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      event,
      _eventData(
        actorId: actor.uid,
        actorName: managerName,
        type: severity == IncidentSeverity.critical
            ? 'criticalEscalation'
            : 'reviewed',
        message: severity == IncidentSeverity.critical
            ? 'Escalated to critical: ${note.trim()}'
            : note.trim().isEmpty
            ? 'Incident reviewed; severity set to ${severity.label}.'
            : 'Incident reviewed: ${note.trim()}',
      ),
    );
    await batch.commit();
  }

  // Assign or reassign ranger(s), and record the change in history.
  @override
  Future<void> assignResponders({
    required String incidentId,
    required IncidentAssignmentKind kind,
    required List<RangerProfile> responders,
    required String managerName,
  }) async {
    IncidentWorkflowPolicy.validateAssignmentSelection(kind, responders.length);
    final actor = _requireSignedIn();
    final incident = _firestore.collection('incidents').doc(incidentId);
    final before = await incident.get();
    final wasAssigned =
        (before.data()?['assignedRangerIds'] as List<dynamic>?)?.isNotEmpty ==
        true;
    IncidentWorkflowPolicy.ensureIncidentIsOpen(
      _enumValue(
        IncidentWorkflowStatus.values,
        before.data()?['workflowStatus'],
        IncidentWorkflowStatus.reported,
      ),
    );
    final event = incident.collection('timeline').doc(_uuid.v4());
    final names = responders.map(_displayName).toList(growable: false);
    final batch = _firestore.batch();
    batch.update(incident, {
      'assignmentType': kind.name,
      'assignedRangerIds': responders.map((item) => item.uid).toList(),
      'assignedRangerNames': names,
      'assignedBy': actor.uid,
      'assignedAt': FieldValue.serverTimestamp(),
      'workflowStatus': IncidentWorkflowStatus.assigned.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      event,
      _eventData(
        actorId: actor.uid,
        actorName: managerName,
        type: 'assigned',
        message:
            '${wasAssigned ? 'Reassigned' : 'Assigned'} '
            '${kind == IncidentAssignmentKind.ranger ? 'to ${names.first}' : 'to response team: ${names.join(', ')}'}.',
      ),
    );
    await batch.commit();
  }

  // Save a manager status change, reason, and history entry together.
  @override
  Future<void> managerTransition({
    required String incidentId,
    required IncidentWorkflowStatus status,
    required String managerName,
    required String note,
    IncidentSeverity? severity,
  }) async {
    if (!IncidentWorkflowPolicy.managerActions.contains(status)) {
      throw ArgumentError('That status change is not a manager action.');
    }
    final actor = _requireSignedIn();
    final incident = _firestore.collection('incidents').doc(incidentId);
    final current = await incident.get();
    final currentStatus = _enumValue(
      IncidentWorkflowStatus.values,
      current.data()?['workflowStatus'],
      IncidentWorkflowStatus.reported,
    );
    IncidentWorkflowPolicy.validateManagerTransition(
      currentStatus: currentStatus,
      nextStatus: status,
      note: note,
      severity: severity,
    );
    final event = incident.collection('timeline').doc(_uuid.v4());
    final update = <String, Object?>{
      'workflowStatus': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (severity != null) update['severity'] = severity.name;
    final normalizedNote = note.trim();
    if (status == IncidentWorkflowStatus.closed) {
      update['closedAt'] = FieldValue.serverTimestamp();
      update['closedBy'] = actor.uid;
    }
    if (status == IncidentWorkflowStatus.followUpRequired ||
        status == IncidentWorkflowStatus.monitoring) {
      update['followUpReason'] = normalizedNote;
    }
    if (severity == IncidentSeverity.critical) {
      update['escalationReason'] = normalizedNote;
    }
    final batch = _firestore.batch();
    batch.update(incident, update);
    batch.set(
      event,
      _eventData(
        actorId: actor.uid,
        actorName: managerName,
        type: severity == IncidentSeverity.critical
            ? 'criticalEscalation'
            : status.name,
        message: severity == IncidentSeverity.critical
            ? 'Escalated to critical: $normalizedNote'
            : normalizedNote.isEmpty
            ? 'Incident status changed to ${status.label}.'
            : '${status.label}: $normalizedNote',
      ),
    );
    await batch.commit();
  }

  // Save a responder's note, status, photos, and history as one batch.
  @override
  Future<void> recordResponderUpdate({
    required String incidentId,
    required String responderName,
    required String note,
    required IncidentWorkflowStatus status,
    required List<IncidentEvidence> evidence,
  }) async {
    IncidentWorkflowPolicy.validateResponderUpdate(note: note, status: status);
    final actor = _requireSignedIn();
    final incident = _firestore.collection('incidents').doc(incidentId);
    final response = incident.collection('responses').doc(_uuid.v4());
    final event = incident.collection('timeline').doc(_uuid.v4());
    final batch = _firestore.batch();
    batch.set(response, {
      'actorId': actor.uid,
      'actorName': responderName,
      'note': note.trim(),
      'status': status.name,
      'evidenceCount': evidence.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(incident, {
      'workflowStatus': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      event,
      _eventData(
        actorId: actor.uid,
        actorName: responderName,
        type: 'responderUpdate',
        message: '${status.label}: ${note.trim()}',
      ),
    );
    for (final photo in evidence) {
      batch.set(response.collection('evidence').doc(photo.id), {
        'fileName': photo.fileName,
        'contentType': photo.contentType,
        'base64Data': photo.base64Data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // Stop a database action if there is no signed-in account.
  User _requireSignedIn() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to continue.');
    return user;
  }

  // Keep only uploaded reports and show the newest ones first.
  List<IncidentReport> _sortReports(Iterable<IncidentReport> reports) =>
      reports
          .where((report) => report.status == IncidentStatus.reported)
          .toList(growable: true)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Convert Firestore field values into the app's incident model.
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
      locationAccuracyMeters: (data['locationAccuracyMeters'] as num?)
          ?.toDouble(),
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

  // Safely turn a Firestore list into a list of strings.
  List<String> _stringList(Object? value) => value is Iterable
      ? value.map((item) => item.toString()).toList(growable: false)
      : const [];

  // Use the matching enum value, or a safe default for older data.
  T _enumValue<T extends Enum>(List<T> values, Object? value, T fallback) =>
      values.firstWhere((item) => item.name == value, orElse: () => fallback);

  // Build the common fields saved for each history entry.
  Map<String, Object?> _eventData({
    required String actorId,
    required String actorName,
    required String type,
    required String message,
  }) => {
    'actorId': actorId,
    'actorName': actorName,
    'type': type,
    'message': message,
    'createdAt': FieldValue.serverTimestamp(),
  };

  // Prefer the person's display name, then use their email.
  String _displayName(RangerProfile ranger) =>
      ranger.displayName.isEmpty ? ranger.email : ranger.displayName;
}
