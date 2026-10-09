import '../domain/patrol.dart';
import '../domain/patrol_records.dart';
import 'patrol_route_plan_codec.dart';

/// SRP: serializes patrol domain records to and from JSON, separate from domain models.
class PatrolCodec {
  const PatrolCodec._();

  /// Encodes a patrol and its associated records into JSON-compatible values.
  static Map<String, Object?> encode(Patrol patrol) => {
    'patrolId': patrol.patrolId,
    'localId': patrol.localId,
    'rangerId': patrol.rangerId,
    'rangerName': patrol.rangerName,
    'area': {
      'parkId': patrol.area.parkId,
      'parkName': patrol.area.parkName,
      'zoneId': patrol.area.zoneId,
      'zoneName': patrol.area.zoneName,
      'routeId': patrol.area.routeId,
      'routeName': patrol.area.routeName,
      'centerLatitude': patrol.area.centerLatitude,
      'centerLongitude': patrol.area.centerLongitude,
    },
    'plannedRoute': patrol.plannedRoute == null
        ? null
        : PatrolRoutePlanCodec.encode(patrol.plannedRoute!),
    'status': patrol.status.name,
    'assignedAt': _date(patrol.assignedAt),
    'startedAt': _date(patrol.startedAt),
    'endedAt': _date(patrol.endedAt),
    'startLocation': _encodeLocation(patrol.startLocation),
    'endLocation': _encodeLocation(patrol.endLocation),
    'routePoints': patrol.routePoints
        .map(
          (point) => {
            'id': point.id,
            'location': _encodeLocation(point.location),
          },
        )
        .toList(),
    'manualWaypoints': patrol.manualWaypoints
        .map(
          (waypoint) => {
            'id': waypoint.id,
            'description': waypoint.description,
            'location': _encodeLocation(waypoint.location),
          },
        )
        .toList(),
    'observations': patrol.observations
        .map(
          (observation) => {
            'id': observation.id,
            'description': observation.description,
            'category': observation.category,
            'location': _encodeLocation(observation.location),
          },
        )
        .toList(),
    'photographs': patrol.photographs
        .map(
          (photo) => {
            'id': photo.id,
            'fileName': photo.fileName,
            'contentType': photo.contentType,
            'base64Data': photo.base64Data,
            'capturedAt': photo.capturedAt.toIso8601String(),
            'observationId': photo.observationId,
          },
        )
        .toList(),
    'pauseResumeEvents': patrol.pauseResumeEvents
        .map(
          (event) => {
            'id': event.id,
            'action': event.action.name,
            'occurredAt': event.occurredAt.toIso8601String(),
            'reason': event.reason,
          },
        )
        .toList(),
    'earlyTerminationReason': patrol.earlyTerminationReason,
    'interruptionReason': patrol.interruptionReason,
    'syncInfo': {
      'status': patrol.syncInfo.status.name,
      'lastAttemptAt': _date(patrol.syncInfo.lastAttemptAt),
      'lastSyncedAt': _date(patrol.syncInfo.lastSyncedAt),
      'lastError': patrol.syncInfo.lastError,
    },
    'coverage': patrol.coverage == null
        ? null
        : {
            'totalSections': patrol.coverage!.totalSections,
            'coveredSections': patrol.coverage!.coveredSections,
            'coveredSectionIds': patrol.coverage!.coveredSectionIds,
            'uncoveredSectionIds': patrol.coverage!.uncoveredSectionIds,
            'calculatedAt': patrol.coverage!.calculatedAt.toIso8601String(),
          },
  };

  /// Decodes a saved patrol map, rejecting invalid fields and enum values.
  static Patrol decode(Map<String, dynamic> json) {
    final area = _map(json['area'], 'area');
    final syncInfo = _map(json['syncInfo'], 'syncInfo');
    final rawCoverage = json['coverage'];

    return Patrol(
      patrolId: _string(json, 'patrolId'),
      localId: _string(json, 'localId'),
      rangerId: _string(json, 'rangerId'),
      rangerName: _string(json, 'rangerName'),
      area: PatrolArea(
        parkId: _nullableString(area['parkId']),
        parkName: _string(area, 'parkName'),
        zoneId: _nullableString(area['zoneId']),
        zoneName: _string(area, 'zoneName'),
        routeId: _nullableString(area['routeId']),
        routeName: _string(area, 'routeName'),
        centerLatitude: _optionalNumber(area['centerLatitude']),
        centerLongitude: _optionalNumber(area['centerLongitude']),
      ),
      plannedRoute: json['plannedRoute'] == null
          ? null
          : PatrolRoutePlanCodec.decode(json['plannedRoute']),
      status: _enumValue(PatrolStatus.values, json['status'], 'status'),
      assignedAt: _optionalDate(json['assignedAt']),
      startedAt: _optionalDate(json['startedAt']),
      endedAt: _optionalDate(json['endedAt']),
      startLocation: _decodeLocation(json['startLocation']),
      endLocation: _decodeLocation(json['endLocation']),
      routePoints: _list(json['routePoints'], 'routePoints').map((item) {
        final point = _map(item, 'route point');
        return PatrolRoutePoint(
          id: _string(point, 'id'),
          location: _decodeLocation(point['location'])!,
        );
      }),
      manualWaypoints: _list(json['manualWaypoints'], 'manualWaypoints').map((
        item,
      ) {
        final waypoint = _map(item, 'manual waypoint');
        return PatrolWaypoint(
          id: _string(waypoint, 'id'),
          description: _string(waypoint, 'description'),
          location: _decodeLocation(waypoint['location'])!,
        );
      }),
      observations: _list(json['observations'], 'observations').map((item) {
        final observation = _map(item, 'observation');
        return PatrolObservation(
          id: _string(observation, 'id'),
          description: _string(observation, 'description'),
          category: _nullableString(observation['category']),
          location: _decodeLocation(observation['location'])!,
        );
      }),
      photographs: _list(json['photographs'], 'photographs').map((item) {
        final photo = _map(item, 'photograph');
        return PatrolPhoto(
          id: _string(photo, 'id'),
          fileName: _string(photo, 'fileName'),
          contentType: _string(photo, 'contentType'),
          base64Data: _string(photo, 'base64Data'),
          capturedAt: _dateValue(photo['capturedAt'], 'capturedAt'),
          observationId: _nullableString(photo['observationId']),
        );
      }),
      pauseResumeEvents: _list(json['pauseResumeEvents'], 'pauseResumeEvents')
          .map((item) {
            final event = _map(item, 'pause/resume event');
            return PatrolPauseResumeEvent(
              id: _string(event, 'id'),
              action: _enumValue(
                PatrolPauseResumeAction.values,
                event['action'],
                'action',
              ),
              occurredAt: _dateValue(event['occurredAt'], 'occurredAt'),
              reason: _nullableString(event['reason']),
            );
          }),
      earlyTerminationReason: _nullableString(json['earlyTerminationReason']),
      interruptionReason: _nullableString(json['interruptionReason']),
      syncInfo: PatrolSyncInfo(
        status: _enumValue(
          PatrolSyncStatus.values,
          syncInfo['status'],
          'sync status',
        ),
        lastAttemptAt: _optionalDate(syncInfo['lastAttemptAt']),
        lastSyncedAt: _optionalDate(syncInfo['lastSyncedAt']),
        lastError: _nullableString(syncInfo['lastError']),
      ),
      coverage: rawCoverage == null
          ? null
          : _decodeCoverage(_map(rawCoverage, 'coverage')),
    );
  }

  static Map<String, Object?>? _encodeLocation(PatrolLocation? location) {
    if (location == null) return null;
    return {
      'latitude': location.latitude,
      'longitude': location.longitude,
      'recordedAt': location.recordedAt.toIso8601String(),
      'source': location.source.name,
      'accuracyMeters': location.accuracyMeters,
    };
  }

  static PatrolLocation? _decodeLocation(Object? value) {
    if (value == null) return null;
    final location = _map(value, 'location');
    return PatrolLocation(
      latitude: _number(location, 'latitude'),
      longitude: _number(location, 'longitude'),
      recordedAt: _dateValue(location['recordedAt'], 'recordedAt'),
      source: _enumValue(
        PatrolLocationSource.values,
        location['source'],
        'location source',
      ),
      accuracyMeters: _optionalNumber(location['accuracyMeters']),
    );
  }

  static PatrolCoverage _decodeCoverage(Map<String, dynamic> json) =>
      PatrolCoverage(
        totalSections: _integer(json, 'totalSections'),
        coveredSections: _integer(json, 'coveredSections'),
        coveredSectionIds:
            (json['coveredSectionIds'] as List?)?.map((value) {
              if (value is! String) {
                throw const FormatException(
                  'Patrol field "coveredSectionIds" must contain strings.',
                );
              }
              return value;
            }) ??
            const [],
        uncoveredSectionIds: _list(
          json['uncoveredSectionIds'],
          'uncoveredSectionIds',
        ).map((value) => value.toString()),
        calculatedAt: _dateValue(json['calculatedAt'], 'calculatedAt'),
      );

  static String? _date(DateTime? value) => value?.toIso8601String();

  static DateTime? _optionalDate(Object? value) =>
      value == null ? null : _dateValue(value, 'date');

  static DateTime _dateValue(Object? value, String field) {
    if (value is String) {
      final date = DateTime.tryParse(value);
      if (date != null) return date;
    }
    throw FormatException('Patrol field "$field" must be an ISO date/time.');
  }

  static Map<String, dynamic> _map(Object? value, String field) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw FormatException('Patrol field "$field" must be an object.');
  }

  static List<dynamic> _list(Object? value, String field) {
    if (value is List) return value;
    throw FormatException('Patrol field "$field" must be a list.');
  }

  static String _string(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value is String) return value;
    throw FormatException('Patrol field "$field" must be a string.');
  }

  static String? _nullableString(Object? value) => value?.toString();

  static int _integer(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value is int) return value;
    throw FormatException('Patrol field "$field" must be an integer.');
  }

  static double _number(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value is num) return value.toDouble();
    throw FormatException('Patrol field "$field" must be numeric.');
  }

  static double? _optionalNumber(Object? value) =>
      value is num ? value.toDouble() : null;

  static T _enumValue<T extends Enum>(
    List<T> values,
    Object? value,
    String field,
  ) {
    if (value is String) {
      for (final item in values) {
        if (item.name == value) return item;
      }
    }
    throw FormatException('Patrol field "$field" has an unknown value.');
  }
}
