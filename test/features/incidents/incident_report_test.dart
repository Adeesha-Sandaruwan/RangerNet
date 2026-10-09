// Checks that incident and user models save and restore their fields correctly.
import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/incidents/domain/incident_report.dart';
import 'package:rangernet/features/incidents/domain/incident_timeline_event.dart';
import 'package:rangernet/features/incidents/domain/ranger_profile.dart';

void main() {
  // These tests protect the JSON format used by saved drafts and offline reports.
  group('IncidentReport', () {
    test('round-trips every report field and its evidence', () {
      final restored = IncidentReport.fromJson(_report().toJson());
      expect(restored.id, 'INC-1');
      expect(restored.rangerId, 'ranger-uid');
      expect(restored.rangerEmail, 'ranger@example.com');
      expect(restored.type, IncidentType.illegalSnare);
      expect(restored.title, 'Snare beside trail');
      expect(restored.description, 'Wire snare found near tracks.');
      expect(restored.severity, IncidentSeverity.high);
      expect(restored.activeThreat, isTrue);
      expect(restored.latitude, 6.2);
      expect(restored.longitude, 81.3);
      expect(restored.locationAccuracyMeters, 8.0);
      expect(restored.parkOrBlock, 'Yala North');
      expect(restored.createdAt, DateTime.utc(2026, 1, 2, 3, 4));
      expect(restored.status, IncidentStatus.reported);
      expect(restored.patrolId, 'PAT-7');
      expect(restored.manualLocation, isFalse);
      expect(restored.workflowStatus, IncidentWorkflowStatus.assigned);
      expect(restored.assignmentKind, IncidentAssignmentKind.responseTeam);
      expect(restored.assignedRangerIds, ['ranger-uid', 'second-uid']);
      expect(restored.assignedRangerNames, ['Ranger One', 'Ranger Two']);
      expect(restored.evidence, hasLength(1));
      expect(restored.evidence.single.fileName, 'snare.jpg');
      expect(restored.evidence.single.base64Data, 'cGhvdG8=');
      expect(restored.evidence.single.contentType, 'image/jpeg');
    });

    test('uses safe defaults for optional legacy fields', () {
      final json = _report().toJson()
        ..remove('rangerEmail')
        ..remove('activeThreat')
        ..remove('latitude')
        ..remove('longitude')
        ..remove('locationAccuracyMeters')
        ..remove('parkOrBlock')
        ..remove('evidence')
        ..remove('manualLocation')
        ..remove('workflowStatus')
        ..remove('assignmentKind')
        ..remove('assignedRangerIds')
        ..remove('assignedRangerNames');
      final restored = IncidentReport.fromJson(json);
      expect(restored.rangerEmail, isEmpty);
      expect(restored.activeThreat, isFalse);
      expect(restored.latitude, isNull);
      expect(restored.longitude, isNull);
      expect(restored.locationAccuracyMeters, isNull);
      expect(restored.parkOrBlock, isEmpty);
      expect(restored.evidence, isEmpty);
      expect(restored.manualLocation, isFalse);
      expect(restored.workflowStatus, IncidentWorkflowStatus.reported);
      expect(restored.assignmentKind, IncidentAssignmentKind.ranger);
      expect(restored.assignedRangerIds, isEmpty);
      expect(restored.assignedRangerNames, isEmpty);
    });

    test('falls back for unknown workflow and assignment values', () {
      final json = _report().toJson()
        ..['workflowStatus'] = 'newStatusFromFutureVersion'
        ..['assignmentKind'] = 'unknownTeamType';
      final restored = IncidentReport.fromJson(json);
      expect(restored.workflowStatus, IncidentWorkflowStatus.reported);
      expect(restored.assignmentKind, IncidentAssignmentKind.ranger);
    });

    test('rejects an unknown required incident type', () {
      final json = _report().toJson()..['type'] = 'notAnIncidentType';
      expect(() => IncidentReport.fromJson(json), throwsArgumentError);
    });

    test('copyWith changes selected values and preserves the rest', () {
      final changed = _report().copyWith(
        severity: IncidentSeverity.critical,
        workflowStatus: IncidentWorkflowStatus.resolved,
        status: IncidentStatus.syncFailed,
        assignedRangerIds: ['replacement'],
      );
      expect(changed.severity, IncidentSeverity.critical);
      expect(changed.workflowStatus, IncidentWorkflowStatus.resolved);
      expect(changed.status, IncidentStatus.syncFailed);
      expect(changed.assignedRangerIds, ['replacement']);
      expect(changed.id, 'INC-1');
      expect(changed.description, _report().description);
      expect(changed.evidence, hasLength(1));
    });

    test('evidence defaults its content type for old drafts', () {
      final evidence = IncidentEvidence.fromJson({
        'id': 'photo-1',
        'fileName': 'track.jpg',
        'base64Data': 'eA==',
      });
      expect(evidence.contentType, 'image/jpeg');
    });
  });

  // Check profile parsing, including manager and older account data.
  group('RangerProfile', () {
    test('reads an active manager profile', () {
      final profile = RangerProfile.fromMap('manager-uid', {
        'role': 'manager',
        'email': 'manager@example.com',
        'displayName': 'Park Manager',
        'active': true,
      });
      expect(profile.uid, 'manager-uid');
      expect(profile.role, RangerRole.manager);
      expect(profile.active, isTrue);
      expect(profile.displayName, 'Park Manager');
    });

    test('defaults an unknown role and recognizes inactive users', () {
      final profile = RangerProfile.fromMap('uid', {
        'role': 'unknown',
        'active': false,
      });
      expect(profile.role, RangerRole.ranger);
      expect(profile.active, isFalse);
      expect(profile.email, isEmpty);
      expect(profile.displayName, isEmpty);
    });
  });

  // Check that incident history rows can be read from saved data.
  group('IncidentTimelineEvent', () {
    test('parses an event with all values', () {
      final time = DateTime.utc(2026, 2, 3);
      final event = IncidentTimelineEvent.fromDocument('event-1', {
        'type': 'assigned',
        'actorId': 'manager-uid',
        'actorName': 'Manager',
        'message': 'Assigned to Ranger One.',
      }, time);
      expect(event.id, 'event-1');
      expect(event.type, 'assigned');
      expect(event.actorId, 'manager-uid');
      expect(event.actorName, 'Manager');
      expect(event.message, 'Assigned to Ranger One.');
      expect(event.createdAt, time);
    });

    test('defaults missing values in older history records', () {
      final event = IncidentTimelineEvent.fromDocument(
        'event-2',
        const {},
        DateTime.utc(2026),
      );
      expect(event.type, 'update');
      expect(event.actorId, isEmpty);
      expect(event.actorName, 'RangerNet user');
      expect(event.message, isEmpty);
    });
  });
}

// Make a reusable sample report so each test focuses on what it changes.
IncidentReport _report() => IncidentReport(
  id: 'INC-1',
  rangerId: 'ranger-uid',
  rangerEmail: 'ranger@example.com',
  type: IncidentType.illegalSnare,
  title: 'Snare beside trail',
  description: 'Wire snare found near tracks.',
  severity: IncidentSeverity.high,
  activeThreat: true,
  latitude: 6.2,
  longitude: 81.3,
  locationAccuracyMeters: 8,
  parkOrBlock: 'Yala North',
  createdAt: DateTime.utc(2026, 1, 2, 3, 4),
  status: IncidentStatus.reported,
  evidence: const [
    IncidentEvidence(
      id: 'photo-1',
      fileName: 'snare.jpg',
      base64Data: 'cGhvdG8=',
      contentType: 'image/jpeg',
    ),
  ],
  patrolId: 'PAT-7',
  workflowStatus: IncidentWorkflowStatus.assigned,
  assignmentKind: IncidentAssignmentKind.responseTeam,
  assignedRangerIds: const ['ranger-uid', 'second-uid'],
  assignedRangerNames: const ['Ranger One', 'Ranger Two'],
);
