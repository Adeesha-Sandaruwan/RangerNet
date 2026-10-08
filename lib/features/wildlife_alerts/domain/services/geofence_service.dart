import 'dart:math' as math;
import '../models/geo_location.dart';
import '../models/high_risk_zone.dart';

class GeofenceBreachResult {
  const GeofenceBreachResult({
    required this.isBreached,
    this.breachedZone,
    this.distanceToCenterMeters,
    this.isExactBoundary = false,
  });

  final bool isBreached;
  final HighRiskZone? breachedZone;
  final double? distanceToCenterMeters;
  final bool isExactBoundary;

  static const safe = GeofenceBreachResult(isBreached: false);
}

/// Service that evaluates if geographic coordinates breach defined HighRiskZones.
/// Implements both Ray-Casting algorithm for 2D Polygons and Haversine formula for radial zones.
class GeofenceService {
  const GeofenceService();

  static const double earthRadiusMeters = 6371000.0;
  static const double boundaryEpsilon = 1e-7;

  /// Evaluates coordinates against a list of active high risk zones.
  /// Returns the highest severity breach if multiple zones overlap.
  GeofenceBreachResult evaluateLocation(
    GeoLocation location,
    List<HighRiskZone> zones,
  ) {
    if (!location.isValid) {
      return GeofenceBreachResult.safe;
    }

    final activeZones = zones.where((z) => z.isActive).toList();
    GeofenceBreachResult? highestBreach;

    for (final zone in activeZones) {
      final result = evaluateZone(location, zone);
      if (result.isBreached) {
        if (highestBreach == null ||
            (result.breachedZone!.severityLevel.weight >
                highestBreach.breachedZone!.severityLevel.weight)) {
          highestBreach = result;
        }
      }
    }

    return highestBreach ?? GeofenceBreachResult.safe;
  }

  /// Evaluates if a location breaches a specific zone.
  GeofenceBreachResult evaluateZone(GeoLocation location, HighRiskZone zone) {
    if (zone.geofenceType == GeofenceType.polygon) {
      return _evaluatePolygonGeofence(location, zone);
    } else {
      return _evaluateCircularGeofence(location, zone);
    }
  }

  /// Ray-casting algorithm (Even-Odd rule) for arbitrary polygon.
  /// Counts intersections of a horizontal ray from point (lat, lon) extending eastwards (lon -> +inf).
  GeofenceBreachResult _evaluatePolygonGeofence(
    GeoLocation point,
    HighRiskZone zone,
  ) {
    final polygon = zone.boundaryPolygon;
    if (polygon.length < 3) {
      return GeofenceBreachResult.safe;
    }

    // Check if the point lies exactly on an edge or vertex of the polygon
    if (isPointOnPolygonBoundary(point, polygon)) {
      return GeofenceBreachResult(
        isBreached: true,
        breachedZone: zone,
        isExactBoundary: true,
      );
    }

    bool inside = false;
    final px = point.longitude;
    final py = point.latitude;

    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      final intersect =
          ((yi > py) != (yj > py)) &&
          (px < (xj - xi) * (py - yi) / (yj - yi) + xi);

      if (intersect) {
        inside = !inside;
      }
    }

    return inside
        ? GeofenceBreachResult(
            isBreached: true,
            breachedZone: zone,
            isExactBoundary: false,
          )
        : GeofenceBreachResult.safe;
  }

  /// Circular geofence evaluation using the Haversine formula.
  GeofenceBreachResult _evaluateCircularGeofence(
    GeoLocation location,
    HighRiskZone zone,
  ) {
    if (zone.centerLocation == null || zone.radiusMeters == null) {
      return GeofenceBreachResult.safe;
    }

    final distance = calculateHaversineDistanceMeters(
      location,
      zone.centerLocation!,
    );
    final radius = zone.radiusMeters!;

    // Check if point is within or directly on the boundary (within 1m tolerance)
    final isExactBoundary = (distance - radius).abs() <= 1.0;
    final isInside = distance <= radius;

    return isInside
        ? GeofenceBreachResult(
            isBreached: true,
            breachedZone: zone,
            distanceToCenterMeters: distance,
            isExactBoundary: isExactBoundary,
          )
        : GeofenceBreachResult.safe;
  }

  /// Calculates great-circle distance between two geographic coordinates in meters.
  double calculateHaversineDistanceMeters(GeoLocation p1, GeoLocation p2) {
    final lat1Rad = p1.latitude * math.pi / 180.0;
    final lat2Rad = p2.latitude * math.pi / 180.0;
    final dLat = (p2.latitude - p1.latitude) * math.pi / 180.0;
    final dLon = (p2.longitude - p1.longitude) * math.pi / 180.0;

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Checks if point lies on a segment of the polygon boundary.
  bool isPointOnPolygonBoundary(GeoLocation point, List<GeoLocation> polygon) {
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final p1 = polygon[j];
      final p2 = polygon[i];

      if (_isPointOnSegment(point, p1, p2)) {
        return true;
      }
    }
    return false;
  }

  bool _isPointOnSegment(GeoLocation p, GeoLocation a, GeoLocation b) {
    // Cross product to check collinearity
    final crossProduct =
        (p.latitude - a.latitude) * (b.longitude - a.longitude) -
        (p.longitude - a.longitude) * (b.latitude - a.latitude);

    if (crossProduct.abs() > boundaryEpsilon) {
      return false;
    }

    // Dot product to check betweenness
    final dotProduct =
        (p.longitude - a.longitude) * (b.longitude - a.longitude) +
        (p.latitude - a.latitude) * (b.latitude - a.latitude);

    if (dotProduct < 0) {
      return false;
    }

    final squaredLength =
        (b.longitude - a.longitude) * (b.longitude - a.longitude) +
        (b.latitude - a.latitude) * (b.latitude - a.latitude);

    return dotProduct <= squaredLength;
  }
}
