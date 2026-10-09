import '../domain/patrol_records.dart';

/// SRP: encodes and decodes planned-route checkpoint maps.
class PatrolRoutePlanCodec {
  const PatrolRoutePlanCodec._();

  /// Encodes a route plan as a Firestore- and JSON-compatible map.
  static Map<String, Object?> encode(PatrolRoutePlan plan) => {
    'start': _encodePoint(plan.start),
    'stops': plan.stops.map(_encodePoint).toList(),
    'end': _encodePoint(plan.end),
    'coverageSections': plan.coverageSections.map(_encodePoint).toList(),
  };

  /// Decodes and validates the route-plan map.
  static PatrolRoutePlan decode(Object? value) {
    if (value is! Map) {
      throw const FormatException('Patrol route plan must be an object.');
    }
    final plan = Map<String, dynamic>.from(value);
    return PatrolRoutePlan(
      start: _decodePoint(plan['start'], 'start'),
      stops: _decodePoints(plan['stops'], 'stops'),
      end: _decodePoint(plan['end'], 'end'),
      coverageSections: _decodePoints(
        plan['coverageSections'],
        'coverageSections',
      ),
    );
  }

  static Map<String, Object?> _encodePoint(PatrolCoverageCheckpoint point) => {
    'id': point.id,
    'name': point.name,
    'latitude': point.latitude,
    'longitude': point.longitude,
  };

  static PatrolCoverageCheckpoint _decodePoint(Object? value, String field) {
    if (value is! Map) {
      throw FormatException('Patrol route field "$field" must be an object.');
    }
    final point = Map<String, dynamic>.from(value);
    final id = point['id'];
    final name = point['name'];
    final latitude = point['latitude'];
    final longitude = point['longitude'];
    if (id is! String ||
        name is! String ||
        latitude is! num ||
        longitude is! num) {
      throw FormatException('Patrol route field "$field" is incomplete.');
    }
    return PatrolCoverageCheckpoint(
      id: id,
      name: name,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  }

  static List<PatrolCoverageCheckpoint> _decodePoints(
    Object? value,
    String field,
  ) {
    if (value is! List) {
      throw FormatException('Patrol route field "$field" must be a list.');
    }
    return value
        .map((item) => _decodePoint(item, field))
        .toList(growable: false);
  }
}
