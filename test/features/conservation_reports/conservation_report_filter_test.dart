import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/incidents/models/incident_report.dart';
import 'package:rangernet/features/conservation_reports/domain/conservation_report_filter.dart';

void main() {
  group('ConservationReportFilter', () {
    test('isEmpty returns true when no filters are set', () {
      const filter = ConservationReportFilter();
      expect(filter.isEmpty, isTrue);
    });

    test('isEmpty returns false when any filter is set', () {
      const filter = ConservationReportFilter(parkOrBlock: 'Yala');
      expect(filter.isEmpty, isFalse);
    });

    test('validate throws when end date is before start date', () {
      final filter = ConservationReportFilter(
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 1, 1),
      );
      expect(() => filter.validate(), throwsArgumentError);
    });

    test('validate passes when dates are in correct order', () {
      final filter = ConservationReportFilter(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 1),
      );
      expect(() => filter.validate(), returnsNormally);
    });

    test('validate passes when no dates are set', () {
      const filter = ConservationReportFilter();
      expect(() => filter.validate(), returnsNormally);
    });

    test('filters by parkOrBlock case-insensitively', () {
      const filter = ConservationReportFilter(parkOrBlock: 'yala north');
      final incidents = [
        _incident(parkOrBlock: 'Yala North'),
        _incident(parkOrBlock: 'Wilpattu'),
      ];
      final result = filter.apply(incidents);
      expect(result, hasLength(1));
      expect(result.first.parkOrBlock, 'Yala North');
    });

    test('filters by date range inclusively', () {
      final filter = ConservationReportFilter(
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 31),
      );
      final incidents = [
        _incident(createdAt: DateTime(2026, 2, 28)),
        _incident(createdAt: DateTime(2026, 3, 15)),
        _incident(createdAt: DateTime(2026, 4, 2)),
      ];
      final result = filter.apply(incidents);
      expect(result, hasLength(1));
    });

    test('filters by incident types', () {
      const filter = ConservationReportFilter(
        incidentTypes: [IncidentType.illegalSnare],
      );
      final incidents = [
        _incident(type: IncidentType.illegalSnare),
        _incident(type: IncidentType.animalCarcass),
        _incident(type: IncidentType.illegalSnare),
      ];
      final result = filter.apply(incidents);
      expect(result, hasLength(2));
    });

    test('filters by severity', () {
      const filter = ConservationReportFilter(
        severities: [IncidentSeverity.critical, IncidentSeverity.high],
      );
      final incidents = [
        _incident(severity: IncidentSeverity.critical),
        _incident(severity: IncidentSeverity.low),
        _incident(severity: IncidentSeverity.high),
        _incident(severity: IncidentSeverity.medium),
      ];
      final result = filter.apply(incidents);
      expect(result, hasLength(2));
    });

    test('filters by patrol team ranger IDs', () {
      const filter = ConservationReportFilter(
        patrolTeamRangerIds: ['ranger-1'],
      );
      final incidents = [
        _incident(assignedRangerIds: ['ranger-1', 'ranger-2']),
        _incident(assignedRangerIds: ['ranger-3']),
        _incident(assignedRangerIds: []),
      ];
      final result = filter.apply(incidents);
      expect(result, hasLength(1));
    });

    test('filters by species keyword in title and description', () {
      const filter = ConservationReportFilter(species: 'elephant');
      final incidents = [
        _incident(title: 'Elephant carcass found', description: 'Near river'),
        _incident(title: 'Snare found', description: 'Possible elephant trap'),
        _incident(title: 'Campsite', description: 'Illegal camp'),
      ];
      final result = filter.apply(incidents);
      expect(result, hasLength(2));
    });

    test('returns all incidents when filter is empty', () {
      const filter = ConservationReportFilter();
      final incidents = [
        _incident(),
        _incident(),
        _incident(),
      ];
      final result = filter.apply(incidents);
      expect(result, hasLength(3));
    });

    test('combined filters narrow results correctly', () {
      final filter = ConservationReportFilter(
        parkOrBlock: 'Yala',
        incidentTypes: const [IncidentType.illegalSnare],
        severities: const [IncidentSeverity.high],
      );
      final incidents = [
        _incident(
          parkOrBlock: 'Yala',
          type: IncidentType.illegalSnare,
          severity: IncidentSeverity.high,
        ),
        _incident(
          parkOrBlock: 'Yala',
          type: IncidentType.illegalSnare,
          severity: IncidentSeverity.low,
        ),
        _incident(
          parkOrBlock: 'Wilpattu',
          type: IncidentType.illegalSnare,
          severity: IncidentSeverity.high,
        ),
      ];
      final result = filter.apply(incidents);
      expect(result, hasLength(1));
    });

    test('copyWith replaces selected fields and preserves others', () {
      final original = ConservationReportFilter(
        parkOrBlock: 'Yala',
        startDate: DateTime(2026, 1, 1),
      );
      final updated = original.copyWith(
        parkOrBlock: () => 'Wilpattu',
      );
      expect(updated.parkOrBlock, 'Wilpattu');
      expect(updated.startDate, DateTime(2026, 1, 1));
    });

    test('copyWith can clear a field by returning null', () {
      const original = ConservationReportFilter(parkOrBlock: 'Yala');
      final updated = original.copyWith(parkOrBlock: () => null);
      expect(updated.parkOrBlock, isNull);
      expect(updated.isEmpty, isTrue);
    });
  });
}

IncidentReport _incident({
  String parkOrBlock = 'Test Park',
  IncidentType type = IncidentType.other,
  IncidentSeverity severity = IncidentSeverity.medium,
  DateTime? createdAt,
  String title = 'Test incident',
  String description = 'Test description',
  List<String> assignedRangerIds = const [],
}) =>
    IncidentReport(
      id: 'INC-${DateTime.now().microsecondsSinceEpoch}',
      rangerId: 'ranger-uid',
      rangerEmail: 'ranger@test.com',
      type: type,
      title: title,
      description: description,
      severity: severity,
      activeThreat: false,
      latitude: 6.2,
      longitude: 81.3,
      locationAccuracyMeters: 10,
      parkOrBlock: parkOrBlock,
      createdAt: createdAt ?? DateTime(2026, 3, 15),
      status: IncidentStatus.reported,
      evidence: const [],
      assignedRangerIds: assignedRangerIds,
    );
