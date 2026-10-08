import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/incidents/domain/incident_report.dart';
import 'package:rangernet/features/conservation_reports/domain/conservation_report_filter.dart';
import 'package:rangernet/features/conservation_reports/domain/conservation_report_type.dart';
import 'package:rangernet/features/conservation_reports/data/conservation_analysis_service.dart';

void main() {
  late ConservationAnalysisService service;

  setUp(() {
    service = ConservationAnalysisService();
  });

  group('ConservationAnalysisService', () {
    test('has a generator registered for every report type', () {
      for (final type in ConservationReportType.values) {
        expect(service.generatorFor(type), isNotNull,
            reason: '${type.title} should have a generator');
      }
    });

    test('generates a report for each type with sample data', () {
      final incidents = _sampleIncidents();
      for (final type in ConservationReportType.values) {
        final result = service.generateReport(
          reportType: type,
          allIncidents: incidents,
          filters: const ConservationReportFilter(),
        );
        expect(result.reportType, type);
        expect(result.totalIncidents, greaterThan(0));
        expect(result.summaryMetrics, isNotEmpty);
        expect(result.generatedAt, isNotNull);
      }
    });

    test('returns empty result when no incidents match filters', () {
      final result = service.generateReport(
        reportType: ConservationReportType.poachingHotspot,
        allIncidents: _sampleIncidents(),
        filters: const ConservationReportFilter(parkOrBlock: 'Nonexistent'),
      );
      expect(result.isEmpty, isTrue);
      expect(result.totalIncidents, 0);
    });

    test('applies filters before generating', () {
      final incidents = [
        _incident(parkOrBlock: 'Yala', type: IncidentType.illegalSnare),
        _incident(parkOrBlock: 'Yala', type: IncidentType.animalCarcass),
        _incident(parkOrBlock: 'Wilpattu', type: IncidentType.illegalSnare),
      ];
      final result = service.generateReport(
        reportType: ConservationReportType.poachingHotspot,
        allIncidents: incidents,
        filters: const ConservationReportFilter(parkOrBlock: 'Yala'),
      );
      expect(result.totalIncidents, 2);
    });

    test('throws ArgumentError for invalid date range filter', () {
      expect(
        () => service.generateReport(
          reportType: ConservationReportType.incidentTrend,
          allIncidents: _sampleIncidents(),
          filters: ConservationReportFilter(
            startDate: DateTime(2026, 12, 1),
            endDate: DateTime(2026, 1, 1),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('handles empty incident list gracefully', () {
      for (final type in ConservationReportType.values) {
        final result = service.generateReport(
          reportType: type,
          allIncidents: const [],
          filters: const ConservationReportFilter(),
        );
        expect(result.isEmpty, isTrue);
        expect(result.tableRows, isEmpty);
      }
    });
  });

  group('PoachingHotspotGenerator', () {
    test('groups incidents by parkOrBlock and counts severity', () {
      final incidents = [
        _incident(parkOrBlock: 'Yala', severity: IncidentSeverity.critical),
        _incident(parkOrBlock: 'Yala', severity: IncidentSeverity.high),
        _incident(parkOrBlock: 'Wilpattu', severity: IncidentSeverity.low),
      ];
      final result = service.generateReport(
        reportType: ConservationReportType.poachingHotspot,
        allIncidents: incidents,
        filters: const ConservationReportFilter(),
      );
      expect(result.totalIncidents, 3);
      expect(result.tableRows, hasLength(2));
      // Yala should be first (2 incidents > 1)
      expect(result.tableRows.first[0], 'Yala');
      expect(result.tableRows.first[1], '2');
    });

    test('identifies active threats', () {
      final incidents = [
        _incident(activeThreat: true),
        _incident(activeThreat: false),
      ];
      final result = service.generateReport(
        reportType: ConservationReportType.poachingHotspot,
        allIncidents: incidents,
        filters: const ConservationReportFilter(),
      );
      expect(result.summaryMetrics['Active threats'], '1');
    });
  });

  group('IncidentTrendGenerator', () {
    test('groups incidents by month', () {
      final incidents = [
        _incident(createdAt: DateTime(2026, 1, 15)),
        _incident(createdAt: DateTime(2026, 1, 20)),
        _incident(createdAt: DateTime(2026, 2, 10)),
      ];
      final result = service.generateReport(
        reportType: ConservationReportType.incidentTrend,
        allIncidents: incidents,
        filters: const ConservationReportFilter(),
      );
      expect(result.tableRows, hasLength(2)); // 2 months
      expect(result.summaryMetrics['Months covered'], '2');
    });

    test('identifies peak month', () {
      final incidents = [
        _incident(createdAt: DateTime(2026, 3, 1)),
        _incident(createdAt: DateTime(2026, 3, 15)),
        _incident(createdAt: DateTime(2026, 3, 20)),
        _incident(createdAt: DateTime(2026, 4, 1)),
      ];
      final result = service.generateReport(
        reportType: ConservationReportType.incidentTrend,
        allIncidents: incidents,
        filters: const ConservationReportFilter(),
      );
      expect(result.summaryMetrics['Peak month'], contains('3'));
    });
  });

  group('PatrolCoverageGenerator', () {
    test('counts incidents per assigned ranger', () {
      final incidents = [
        _incident(assignedRangerIds: ['r1'], assignedRangerNames: ['Ranger A']),
        _incident(assignedRangerIds: ['r1'], assignedRangerNames: ['Ranger A']),
        _incident(assignedRangerIds: ['r2'], assignedRangerNames: ['Ranger B']),
      ];
      final result = service.generateReport(
        reportType: ConservationReportType.patrolCoverage,
        allIncidents: incidents,
        filters: const ConservationReportFilter(),
      );
      expect(result.summaryMetrics['Rangers involved'], '2');
      expect(result.tableRows.first[0], 'Ranger A'); // most incidents
    });

    test('counts unassigned incidents', () {
      final incidents = [
        _incident(assignedRangerIds: []),
        _incident(assignedRangerIds: ['r1'], assignedRangerNames: ['Ranger']),
      ];
      final result = service.generateReport(
        reportType: ConservationReportType.patrolCoverage,
        allIncidents: incidents,
        filters: const ConservationReportFilter(),
      );
      expect(result.summaryMetrics['Unassigned'], '1');
    });
  });

  group('HumanWildlifeConflictGenerator', () {
    test('filters to conflict types and calculates conflict rate', () {
      final incidents = [
        _incident(type: IncidentType.illegalSnare),
        _incident(type: IncidentType.animalCarcass),
        _incident(type: IncidentType.illegalCampsite),
        _incident(type: IncidentType.other),
      ];
      final result = service.generateReport(
        reportType: ConservationReportType.humanWildlifeConflict,
        allIncidents: incidents,
        filters: const ConservationReportFilter(),
      );
      expect(result.summaryMetrics['Conflict incidents'], '2');
      expect(result.summaryMetrics['Conflict rate'], '50.0%');
    });
  });

  group('ConservationOutcomeGenerator', () {
    test('calculates resolution rate', () {
      final incidents = [
        _incident(workflowStatus: IncidentWorkflowStatus.closed),
        _incident(workflowStatus: IncidentWorkflowStatus.resolved),
        _incident(workflowStatus: IncidentWorkflowStatus.reported),
        _incident(workflowStatus: IncidentWorkflowStatus.assigned),
      ];
      final result = service.generateReport(
        reportType: ConservationReportType.conservationOutcome,
        allIncidents: incidents,
        filters: const ConservationReportFilter(),
      );
      expect(result.summaryMetrics['Resolution rate'], '50.0%');
      expect(result.summaryMetrics['Resolved / closed'], '2');
      expect(result.summaryMetrics['Open cases'], '3');
    });

    test('calculates assignment rate', () {
      final incidents = [
        _incident(assignedRangerIds: ['r1']),
        _incident(assignedRangerIds: []),
      ];
      final result = service.generateReport(
        reportType: ConservationReportType.conservationOutcome,
        allIncidents: incidents,
        filters: const ConservationReportFilter(),
      );
      expect(result.summaryMetrics['Assignment rate'], '50.0%');
    });
  });

  group('WildlifeMonitoringGenerator', () {
    test('counts wildlife-related incidents', () {
      final incidents = [
        _incident(type: IncidentType.animalCarcass),
        _incident(type: IncidentType.illegalSnare),
        _incident(type: IncidentType.illegalCampsite),
        _incident(type: IncidentType.other),
      ];
      final result = service.generateReport(
        reportType: ConservationReportType.wildlifeMonitoring,
        allIncidents: incidents,
        filters: const ConservationReportFilter(),
      );
      expect(result.summaryMetrics['Wildlife-related'], '3');
      expect(result.summaryMetrics['Animal carcasses'], '1');
    });
  });
}

List<IncidentReport> _sampleIncidents() => [
      _incident(
        parkOrBlock: 'Yala North',
        type: IncidentType.illegalSnare,
        severity: IncidentSeverity.high,
        createdAt: DateTime(2026, 1, 15),
      ),
      _incident(
        parkOrBlock: 'Yala North',
        type: IncidentType.animalCarcass,
        severity: IncidentSeverity.critical,
        createdAt: DateTime(2026, 2, 10),
        activeThreat: true,
      ),
      _incident(
        parkOrBlock: 'Wilpattu',
        type: IncidentType.suspiciousActivity,
        severity: IncidentSeverity.medium,
        createdAt: DateTime(2026, 2, 20),
      ),
      _incident(
        parkOrBlock: 'Horton Plains',
        type: IncidentType.illegalCampsite,
        severity: IncidentSeverity.low,
        createdAt: DateTime(2026, 3, 5),
        assignedRangerIds: ['ranger-1'],
        assignedRangerNames: ['Ranger One'],
        workflowStatus: IncidentWorkflowStatus.closed,
      ),
    ];

IncidentReport _incident({
  String parkOrBlock = 'Test Park',
  IncidentType type = IncidentType.other,
  IncidentSeverity severity = IncidentSeverity.medium,
  DateTime? createdAt,
  bool activeThreat = false,
  List<String> assignedRangerIds = const [],
  List<String> assignedRangerNames = const [],
  IncidentWorkflowStatus workflowStatus = IncidentWorkflowStatus.reported,
}) =>
    IncidentReport(
      id: 'INC-${DateTime.now().microsecondsSinceEpoch}',
      rangerId: 'ranger-uid',
      rangerEmail: 'ranger@test.com',
      type: type,
      title: 'Test incident',
      description: 'Test description',
      severity: severity,
      activeThreat: activeThreat,
      latitude: 6.2,
      longitude: 81.3,
      locationAccuracyMeters: 10,
      parkOrBlock: parkOrBlock,
      createdAt: createdAt ?? DateTime(2026, 3, 15),
      status: IncidentStatus.reported,
      evidence: const [],
      assignedRangerIds: assignedRangerIds,
      assignedRangerNames: assignedRangerNames,
      workflowStatus: workflowStatus,
    );
