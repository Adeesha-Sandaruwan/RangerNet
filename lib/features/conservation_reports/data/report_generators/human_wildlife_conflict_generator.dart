import '../../../incidents/domain/incident_report.dart';
import '../../domain/conservation_report_filter.dart';
import '../../domain/conservation_report_result.dart';
import '../../domain/conservation_report_type.dart';
import 'report_generator.dart';

/// Analyses incidents that involve direct human–wildlife interaction.
///
/// Filters to conflict-related incident types (animal carcass, illegal snare,
/// suspicious activity) and breaks down by location, severity, and type.
class HumanWildlifeConflictGenerator extends ReportGenerator {
  /// Incident types considered conflict-related.
  static const conflictTypes = {
    IncidentType.animalCarcass,
    IncidentType.illegalSnare,
    IncidentType.suspiciousActivity,
  };

  @override
  ConservationReportResult generate(
    List<IncidentReport> incidents,
    ConservationReportFilter filters,
  ) {
    if (incidents.isEmpty) return _emptyResult();

    // Separate conflicts from non-conflicts
    final conflicts = incidents
        .where((i) => conflictTypes.contains(i.type))
        .toList();
    final conflictRate = incidents.isEmpty
        ? 0.0
        : (conflicts.length / incidents.length) * 100;

    // By type
    final byType = <IncidentType, int>{};
    for (final incident in conflicts) {
      byType[incident.type] = (byType[incident.type] ?? 0) + 1;
    }

    // By park
    final byPark = <String, int>{};
    for (final incident in conflicts) {
      final park = incident.parkOrBlock.isEmpty
          ? 'Unknown'
          : incident.parkOrBlock;
      byPark[park] = (byPark[park] ?? 0) + 1;
    }
    final sortedParks = byPark.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // By severity
    final bySeverity = <IncidentSeverity, int>{};
    for (final incident in conflicts) {
      bySeverity[incident.severity] = (bySeverity[incident.severity] ?? 0) + 1;
    }

    // Active threats
    final activeThreats = conflicts.where((i) => i.activeThreat).length;

    return ConservationReportResult(
      reportType: ConservationReportType.humanWildlifeConflict,
      generatedAt: DateTime.now(),
      totalIncidents: incidents.length,
      summaryMetrics: {
        'Total incidents analysed': incidents.length.toString(),
        'Conflict incidents': conflicts.length.toString(),
        'Conflict rate': '${conflictRate.toStringAsFixed(1)}%',
        'Active threats': activeThreats.toString(),
        'Areas affected': byPark.length.toString(),
      },
      chartSeries: {
        'Conflict types': byType.entries
            .map((e) => ChartDataPoint(e.key.label, e.value.toDouble()))
            .toList(),
        'Conflicts by area': sortedParks
            .take(10)
            .map((e) => ChartDataPoint(e.key, e.value.toDouble()))
            .toList(),
        'Severity of conflicts': IncidentSeverity.values
            .map(
              (s) => ChartDataPoint(s.label, (bySeverity[s] ?? 0).toDouble()),
            )
            .toList(),
      },
      tableColumns: const [
        'Area',
        'Conflicts',
        'Snares',
        'Carcasses',
        'Suspicious',
        'Active threats',
      ],
      tableRows: sortedParks.map((entry) {
        final parkConflicts = conflicts
            .where(
              (i) =>
                  (i.parkOrBlock.isEmpty ? 'Unknown' : i.parkOrBlock) ==
                  entry.key,
            )
            .toList();
        return [
          entry.key,
          parkConflicts.length.toString(),
          parkConflicts
              .where((i) => i.type == IncidentType.illegalSnare)
              .length
              .toString(),
          parkConflicts
              .where((i) => i.type == IncidentType.animalCarcass)
              .length
              .toString(),
          parkConflicts
              .where((i) => i.type == IncidentType.suspiciousActivity)
              .length
              .toString(),
          parkConflicts.where((i) => i.activeThreat).length.toString(),
        ];
      }).toList(),
    );
  }

  ConservationReportResult _emptyResult() => ConservationReportResult(
    reportType: ConservationReportType.humanWildlifeConflict,
    generatedAt: DateTime.now(),
    totalIncidents: 0,
    summaryMetrics: const {
      'Total incidents analysed': '0',
      'Conflict incidents': '0',
    },
    chartSeries: const {},
    tableColumns: const [
      'Area',
      'Conflicts',
      'Snares',
      'Carcasses',
      'Suspicious',
      'Active threats',
    ],
    tableRows: const [],
  );
}
