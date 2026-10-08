import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/wildlife_alerts/domain/models/geo_location.dart';
import 'package:rangernet/features/wildlife_alerts/domain/models/wildlife_alert.dart';
import 'package:rangernet/features/wildlife_alerts/domain/services/alert_throttling_service.dart';

void main() {
  group('AlertThrottlingService', () {
    const service = AlertThrottlingService(cooldownDuration: Duration(minutes: 15));
    final t0 = DateTime.parse('2026-10-08T10:00:00Z');

    final initialLocation = GeoLocation(
      latitude: 6.3600,
      longitude: 81.4600,
      timestamp: t0,
    );

    final activeAlert = WildlifeAlert(
      alertId: 'ALERT-001',
      sensorId: 'COLLAR-01',
      targetId: 'ANIMAL-ELE-01',
      zoneId: 'ZONE-POACH-01',
      riskLevel: AlertRiskLevel.high,
      status: AlertStatus.active,
      triggerType: AlertTriggerType.geofenceBreach,
      triggeredAt: t0,
      currentLocation: initialLocation,
      locationHistory: [initialLocation],
    );

    test('Positive: Subsequent ping within cooldown window is throttled and appends breadcrumb to locationHistory', () {
      final t1 = t0.add(const Duration(minutes: 5));
      final newLocation = GeoLocation(
        latitude: 6.3620,
        longitude: 81.4620,
        timestamp: t1,
      );

      final result = service.evaluate(
        targetId: 'ANIMAL-ELE-01',
        zoneId: 'ZONE-POACH-01',
        newLocation: newLocation,
        activeAlerts: [activeAlert],
        eventTime: t1,
      );

      expect(result.wasThrottled, isTrue);
      expect(result.updatedAlert, isNotNull);
      expect(result.updatedAlert!.locationHistory.length, equals(2));
      expect(result.updatedAlert!.locationHistory.last, equals(newLocation));
      expect(result.updatedAlert!.currentLocation, equals(newLocation));
      expect(result.updatedAlert!.lastUpdatedAt, equals(t1));
    });

    test('Negative: Telemetry after cooldown expiration is NOT throttled (allows new alert)', () {
      final tExpired = t0.add(const Duration(minutes: 20)); // > 15 min cooldown
      final newLocation = GeoLocation(
        latitude: 6.3650,
        longitude: 81.4650,
        timestamp: tExpired,
      );

      final result = service.evaluate(
        targetId: 'ANIMAL-ELE-01',
        zoneId: 'ZONE-POACH-01',
        newLocation: newLocation,
        activeAlerts: [activeAlert],
        eventTime: tExpired,
      );

      expect(result.wasThrottled, isFalse);
      expect(result.updatedAlert, isNull);
    });

    test('Negative: Ping for a different animal is NOT throttled', () {
      final t1 = t0.add(const Duration(minutes: 3));
      final newLocation = GeoLocation(
        latitude: 6.3620,
        longitude: 81.4620,
        timestamp: t1,
      );

      final result = service.evaluate(
        targetId: 'ANIMAL-LEO-02', // Different animal
        zoneId: 'ZONE-POACH-01',
        newLocation: newLocation,
        activeAlerts: [activeAlert],
        eventTime: t1,
      );

      expect(result.wasThrottled, isFalse);
    });

    test('Negative: Ping for the same animal in a different zone is NOT throttled', () {
      final t1 = t0.add(const Duration(minutes: 3));
      final newLocation = GeoLocation(
        latitude: 6.4200,
        longitude: 81.3900,
        timestamp: t1,
      );

      final result = service.evaluate(
        targetId: 'ANIMAL-ELE-01',
        zoneId: 'ZONE-RIVER-02', // Different zone
        newLocation: newLocation,
        activeAlerts: [activeAlert],
        eventTime: t1,
      );

      expect(result.wasThrottled, isFalse);
    });

    test('Negative: Already resolved alert is NOT throttled (permits re-alerting)', () {
      final resolvedAlert = activeAlert.copyWith(
        status: AlertStatus.resolved,
        resolvedAt: t0.add(const Duration(minutes: 2)),
      );

      final t1 = t0.add(const Duration(minutes: 4));
      final newLocation = GeoLocation(
        latitude: 6.3620,
        longitude: 81.4620,
        timestamp: t1,
      );

      final result = service.evaluate(
        targetId: 'ANIMAL-ELE-01',
        zoneId: 'ZONE-POACH-01',
        newLocation: newLocation,
        activeAlerts: [resolvedAlert],
        eventTime: t1,
      );

      expect(result.wasThrottled, isFalse);
    });
  });
}
