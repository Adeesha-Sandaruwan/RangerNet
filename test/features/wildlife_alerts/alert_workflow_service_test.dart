import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/wildlife_alerts/data/repositories/wildlife_alert_repository_impl.dart';
import 'package:rangernet/features/wildlife_alerts/domain/models/wildlife_alert.dart';
import 'package:rangernet/features/wildlife_alerts/domain/services/alert_workflow_service.dart';

void main() {
  group('AlertWorkflowService Ranger Lifecycle', () {
    late WildlifeAlertRepositoryImpl repository;
    late AlertWorkflowService service;
    final testTime = DateTime.parse('2026-10-08T10:00:00Z');

    setUp(() async {
      repository = WildlifeAlertRepositoryImpl();
      service = AlertWorkflowService(repository: repository);
    });

    test('Positive: Ranger acknowledges active alert (ACTIVE -> ACKNOWLEDGED)', () async {
      // ALERT-001 is initialized as ACTIVE in seed data
      final acknowledged = await service.acknowledgeAlert(
        alertId: 'ALERT-001',
        rangerId: 'RANGER-SARAH-09',
        notes: 'Responding with quick intervention team',
      );

      expect(acknowledged.status, equals(AlertStatus.acknowledged));
      expect(acknowledged.acknowledgedByRangerId, equals('RANGER-SARAH-09'));
      expect(acknowledged.acknowledgedAt, isNotNull);

      // Verify persisted state
      final persisted = await repository.getAlertById('ALERT-001');
      expect(persisted?.status, equals(AlertStatus.acknowledged));
    });

    test('Positive: Ranger submits response and resolves alert (ACKNOWLEDGED -> RESOLVED)', () async {
      // ALERT-002 is initialized as ACKNOWLEDGED in seed data
      final response = await service.resolveAlert(
        alertId: 'ALERT-002',
        rangerId: 'RANGER-SARAH-09',
        rangerName: 'Sarah Jenkins',
        actionTaken: 'Interception unit deployed; suspects fled north beyond buffer line.',
        observations: 'No snared animals found; retrieved abandoned cutting wire.',
        followUpRequired: true,
      );

      expect(response.responseId, isNotEmpty);
      expect(response.alertId, equals('ALERT-002'));
      expect(response.rangerId, equals('RANGER-SARAH-09'));
      expect(response.followUpRequired, isTrue);

      final updatedAlert = await repository.getAlertById('ALERT-002');
      expect(updatedAlert?.status, equals(AlertStatus.resolved));
      expect(updatedAlert?.resolvedByRangerId, equals('RANGER-SARAH-09'));
      expect(updatedAlert?.resolvedAt, isNotNull);

      final loggedResponses = await repository.getResponsesForAlert('ALERT-002');
      expect(loggedResponses.length, equals(1));
      expect(loggedResponses.first.actionTaken, contains('Interception unit'));
    });

    test('Positive: Sorting prioritizes HIGH risk alerts above MEDIUM and LOW', () {
      final alerts = [
        WildlifeAlert(
          alertId: 'A-LOW',
          sensorId: 'S1',
          targetId: 'T1',
          riskLevel: AlertRiskLevel.low,
          status: AlertStatus.active,
          triggerType: AlertTriggerType.geofenceBreach,
          triggeredAt: testTime,
        ),
        WildlifeAlert(
          alertId: 'A-HIGH-OLD',
          sensorId: 'S2',
          targetId: 'T2',
          riskLevel: AlertRiskLevel.high,
          status: AlertStatus.active,
          triggerType: AlertTriggerType.geofenceBreach,
          triggeredAt: testTime.subtract(const Duration(minutes: 10)),
        ),
        WildlifeAlert(
          alertId: 'A-HIGH-NEW',
          sensorId: 'S3',
          targetId: 'T3',
          riskLevel: AlertRiskLevel.high,
          status: AlertStatus.active,
          triggerType: AlertTriggerType.geofenceBreach,
          triggeredAt: testTime,
        ),
        WildlifeAlert(
          alertId: 'A-MED',
          sensorId: 'S4',
          targetId: 'T4',
          riskLevel: AlertRiskLevel.medium,
          status: AlertStatus.active,
          triggerType: AlertTriggerType.geofenceBreach,
          triggeredAt: testTime,
        ),
      ];

      final sorted = service.sortAlertsByPriority(alerts);

      expect(sorted[0].alertId, equals('A-HIGH-NEW'));
      expect(sorted[1].alertId, equals('A-HIGH-OLD'));
      expect(sorted[2].alertId, equals('A-MED'));
      expect(sorted[3].alertId, equals('A-LOW'));
    });

    test('Negative: Cannot acknowledge an already acknowledged alert', () async {
      // ALERT-002 is already ACKNOWLEDGED
      expect(
        () => service.acknowledgeAlert(
          alertId: 'ALERT-002',
          rangerId: 'RANGER-01',
        ),
        throwsA(isA<InvalidAlertTransitionException>()),
      );
    });

    test('Negative: Cannot acknowledge an already resolved alert', () async {
      // ALERT-003 is already RESOLVED in seed data
      expect(
        () => service.acknowledgeAlert(
          alertId: 'ALERT-003',
          rangerId: 'RANGER-01',
        ),
        throwsA(isA<InvalidAlertTransitionException>()),
      );
    });

    test('Negative: Cannot resolve an already resolved alert', () async {
      // ALERT-003 is already RESOLVED
      expect(
        () => service.resolveAlert(
          alertId: 'ALERT-003',
          rangerId: 'RANGER-01',
          actionTaken: 'Another action',
          observations: 'Another observation',
        ),
        throwsA(isA<InvalidAlertTransitionException>()),
      );
    });

    test('Negative: Resolving without action taken throws ArgumentError', () async {
      expect(
        () => service.resolveAlert(
          alertId: 'ALERT-001',
          rangerId: 'RANGER-01',
          actionTaken: '   ', // Empty
          observations: 'Observed elephant',
        ),
        throwsArgumentError,
      );
    });

    test('Negative: Acting on non-existent alert ID throws StateError', () async {
      expect(
        () => service.acknowledgeAlert(
          alertId: 'DOES-NOT-EXIST-000',
          rangerId: 'RANGER-01',
        ),
        throwsStateError,
      );
    });
  });
}
