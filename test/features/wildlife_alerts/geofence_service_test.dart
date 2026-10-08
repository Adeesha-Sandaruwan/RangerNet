import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/wildlife_alerts/domain/models/geo_location.dart';
import 'package:rangernet/features/wildlife_alerts/domain/models/high_risk_zone.dart';
import 'package:rangernet/features/wildlife_alerts/domain/services/geofence_service.dart';

void main() {
  group('GeofenceService', () {
    const service = GeofenceService();
    final baseTime = DateTime.parse('2026-10-08T10:00:00Z');

    final polygonZone = HighRiskZone(
      zoneId: 'ZONE-POLY-01',
      name: 'Southern Buffer Zone',
      severityLevel: ZoneSeverityLevel.high,
      boundaryPolygon: [
        GeoLocation(latitude: 6.3500, longitude: 81.4500, timestamp: baseTime),
        GeoLocation(latitude: 6.3700, longitude: 81.4500, timestamp: baseTime),
        GeoLocation(latitude: 6.3700, longitude: 81.4800, timestamp: baseTime),
        GeoLocation(latitude: 6.3500, longitude: 81.4800, timestamp: baseTime),
      ],
    );

    final circularZone = HighRiskZone(
      zoneId: 'ZONE-CIRC-02',
      name: 'River Sanctuary Zone',
      severityLevel: ZoneSeverityLevel.medium,
      centerLocation: GeoLocation(
        latitude: 6.4000,
        longitude: 81.4000,
        timestamp: baseTime,
      ),
      radiusMeters: 1000.0,
    );

    test('Positive: Point clearly inside polygon geofence reports breach', () {
      final pointInside = GeoLocation(
        latitude: 6.3600,
        longitude: 81.4650,
        timestamp: baseTime,
      );

      final result = service.evaluateZone(pointInside, polygonZone);

      expect(result.isBreached, isTrue);
      expect(result.breachedZone?.zoneId, equals('ZONE-POLY-01'));
      expect(result.isExactBoundary, isFalse);
    });

    test('Negative: Point outside polygon geofence reports safe', () {
      final pointOutside = GeoLocation(
        latitude: 6.3800,
        longitude: 81.4900,
        timestamp: baseTime,
      );

      final result = service.evaluateZone(pointOutside, polygonZone);

      expect(result.isBreached, isFalse);
      expect(result.breachedZone, isNull);
    });

    test('Edge/Boundary: Point lying directly on polygon boundary edge reports breach with exact boundary flag', () {
      final pointOnBoundary = GeoLocation(
        latitude: 6.3500, // On the southern boundary segment
        longitude: 81.4600,
        timestamp: baseTime,
      );

      final result = service.evaluateZone(pointOnBoundary, polygonZone);

      expect(result.isBreached, isTrue);
      expect(result.breachedZone?.zoneId, equals('ZONE-POLY-01'));
      expect(result.isExactBoundary, isTrue);
    });

    test('Positive: Point inside circular geofence reports breach with distance', () {
      // 6.4020 is ~222 meters north of 6.4000, well inside 1000m radius
      final pointInside = GeoLocation(
        latitude: 6.4020,
        longitude: 81.4000,
        timestamp: baseTime,
      );

      final result = service.evaluateZone(pointInside, circularZone);

      expect(result.isBreached, isTrue);
      expect(result.breachedZone?.zoneId, equals('ZONE-CIRC-02'));
      expect(result.distanceToCenterMeters, isNotNull);
      expect(result.distanceToCenterMeters!, lessThan(1000.0));
    });

    test('Negative: Point outside circular geofence reports safe', () {
      // 6.4200 is ~2220 meters north, outside 1000m radius
      final pointOutside = GeoLocation(
        latitude: 6.4200,
        longitude: 81.4000,
        timestamp: baseTime,
      );

      final result = service.evaluateZone(pointOutside, circularZone);

      expect(result.isBreached, isFalse);
    });

    test('Negative: Invalid coordinates return safe without crashing', () {
      final invalidPoint = GeoLocation(
        latitude: 105.0, // Invalid latitude > 90
        longitude: 81.4000,
        timestamp: baseTime,
      );

      final result = service.evaluateLocation(invalidPoint, [polygonZone, circularZone]);

      expect(result.isBreached, isFalse);
    });

    test('Multi-zone evaluation: Selects highest severity zone when overlapping', () {
      final pointInBoth = GeoLocation(
        latitude: 6.3600,
        longitude: 81.4600,
        timestamp: baseTime,
      );

      final overlappingLowZone = HighRiskZone(
        zoneId: 'ZONE-LOW-99',
        name: 'Overlapping Low Severity Area',
        severityLevel: ZoneSeverityLevel.low,
        boundaryPolygon: polygonZone.boundaryPolygon,
      );

      final result = service.evaluateLocation(pointInBoth, [overlappingLowZone, polygonZone]);

      expect(result.isBreached, isTrue);
      expect(result.breachedZone?.zoneId, equals('ZONE-POLY-01')); // HIGH > LOW
    });
  });
}
