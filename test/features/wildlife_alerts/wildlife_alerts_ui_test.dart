import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/wildlife_alerts/data/repositories/wildlife_alert_repository_impl.dart';
import 'package:rangernet/features/wildlife_alerts/domain/models/geo_location.dart';
import 'package:rangernet/features/wildlife_alerts/domain/models/wildlife_alert.dart';
import 'package:rangernet/features/wildlife_alerts/presentation/controllers/wildlife_alert_controller.dart';
import 'package:rangernet/features/wildlife_alerts/presentation/widgets/alert_badges.dart';
import 'package:rangernet/features/wildlife_alerts/presentation/widgets/location_history_timeline.dart';

void main() {
  group('Wildlife Alerts Controller & Widgets', () {
    late WildlifeAlertRepositoryImpl repository;
    late WildlifeAlertController controller;

    setUp(() {
      repository = WildlifeAlertRepositoryImpl();
      controller = WildlifeAlertController(repository: repository);
    });

    test('Controller initializes with seed data and metric counts', () async {
      await controller.loadData();

      expect(controller.alerts.isNotEmpty, isTrue);
      expect(controller.animals.isNotEmpty, isTrue);
      expect(controller.zones.isNotEmpty, isTrue);
      expect(controller.sensors.isNotEmpty, isTrue);
      expect(controller.activeAlertsCount, greaterThan(0));
      expect(controller.acknowledgedAlertsCount, greaterThan(0));
      expect(controller.resolvedAlertsCount, greaterThan(0));
    });

    test('Controller filters alerts by status and risk level', () async {
      await controller.loadData();

      controller.setStatusFilter(AlertStatus.active);
      expect(controller.filteredAlerts.every((a) => a.status == AlertStatus.active), isTrue);

      controller.setStatusFilter(AlertStatus.resolved);
      expect(controller.filteredAlerts.every((a) => a.status == AlertStatus.resolved), isTrue);

      controller.setStatusFilter(null);
      controller.setRiskFilter(AlertRiskLevel.high);
      expect(controller.filteredAlerts.every((a) => a.riskLevel == AlertRiskLevel.high), isTrue);
    });

    test('Controller acknowledge and resolve workflow updates state and metrics', () async {
      await controller.loadData();
      final initialResolved = controller.resolvedAlertsCount;

      // Acknowledge ALERT-001
      final ackSuccess = await controller.acknowledgeAlert(
        alertId: 'ALERT-001',
        rangerId: 'RANGER-TEST',
      );
      expect(ackSuccess, isTrue);

      // Resolve ALERT-001
      final resSuccess = await controller.resolveAlert(
        alertId: 'ALERT-001',
        rangerId: 'RANGER-TEST',
        actionTaken: 'Tested field resolution successfully',
        observations: 'Animal safe and monitored',
      );
      expect(resSuccess, isTrue);
      expect(controller.resolvedAlertsCount, equals(initialResolved + 1));
    });

    test('Controller toggle online status switches state', () {
      expect(controller.isOnline, isTrue);
      controller.toggleOnlineStatus();
      expect(controller.isOnline, isFalse);
      controller.toggleOnlineStatus();
      expect(controller.isOnline, isTrue);
    });

    testWidgets('RiskLevelBadge renders corresponding labels and colors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                RiskLevelBadge(riskLevel: AlertRiskLevel.high),
                RiskLevelBadge(riskLevel: AlertRiskLevel.medium),
                RiskLevelBadge(riskLevel: AlertRiskLevel.low),
              ],
            ),
          ),
        ),
      );

      expect(find.text('HIGH RISK'), findsOneWidget);
      expect(find.text('MEDIUM RISK'), findsOneWidget);
      expect(find.text('LOW RISK'), findsOneWidget);
    });

    testWidgets('AlertStatusBadge renders ACTIVE, ACKNOWLEDGED, RESOLVED', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AlertStatusBadge(status: AlertStatus.active),
                AlertStatusBadge(status: AlertStatus.acknowledged),
                AlertStatusBadge(status: AlertStatus.resolved),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('ACKNOWLEDGED'), findsOneWidget);
      expect(find.text('RESOLVED'), findsOneWidget);
    });

    testWidgets('LocationHistoryTimeline displays breadcrumbs trail with count', (tester) async {
      final now = DateTime.now();
      final pings = [
        GeoLocation(latitude: 6.3600, longitude: 81.4600, altitude: 45.0, timestamp: now),
        GeoLocation(latitude: 6.3620, longitude: 81.4620, altitude: 46.0, timestamp: now.add(const Duration(minutes: 1))),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationHistoryTimeline(locations: pings),
          ),
        ),
      );

      expect(find.text('Telemetry Breadcrumbs (2 pings)'), findsOneWidget);
      expect(find.text('Throttled stream active'), findsOneWidget);
      expect(find.text('LATEST'), findsOneWidget);
    });
  });
}
