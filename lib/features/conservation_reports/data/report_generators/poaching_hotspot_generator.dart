import 'package:intl/intl.dart';

import '../../../incidents/models/incident_report.dart';
import '../../domain/conservation_report_filter.dart';
import '../../domain/conservation_report_result.dart';
import '../../domain/conservation_report_type.dart';
import 'report_generator.dart';

/// Identifies geographic clusters with the highest poaching activity.
///
/// Groups incidents by `parkOrBlock`, counts per severity, and sorts
/// locations from most to least incidents.
class PoachingHotspotGenerator extends ReportGenerator {
  @override
  ConservationReportResult generate(
    List<IncidentReport> incidents,
    ConservationReportFilter filters,
  ) {
    if (incidents.isEmpty) return _emptyResult();

    // Group by park/block
    final byPark = <String, List<IncidentReport>>{};
    for (final incident in incidents) {
      final key = incident.parkOrBlock.isEmpty ? 'Unknown' : incident.parkOrBlock;
      byPark.putIfAbsent(key, () => []).add(incident);
    }

    // Sort parks by incident count descending
    final sortedParks = byPark.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    // Severity breakdown across all incidents
    final bySeverity = <IncidentSeverity, int>{};
    for (final incident in incidents) {
      bySeverity[incident.severity] = (bySeverity[incident.severity] ?? 0) + 1;
    }

    // Type breakdown
    final byType = <IncidentType, int>{};
    for (final incident in incidents) {
      byType[incident.type] = (byType[incident.type] ?? 0) + 1;
    }

    // Active threats count
    final activeThreats = incidents.where((i) => i.activeThreat).length;

    // Critical/high severity count
    final highRisk = incidents
        .where((i) =>
            i.severity == IncidentSeverity.critical ||
            i.severity == IncidentSeverity.high)
        .length;

    final topHotspot = sortedParks.isNotEmpty ? sortedParks.first.key : 'N/A';

    return ConservationReportResult(
      reportType: ConservationReportType.poachingHotspot,
      generatedAt: DateTime.now(),
      totalIncidents: incidents.length,
      summaryMetrics: {
        'Total incidents': incidents.length.toString(),
        'Top hotspot': topHotspot,
        'Active threats': activeThreats.toString(),
        'High/critical risk': highRisk.toString(),
        'Areas covered': byPark.length.toString(),
      },
      chartSeries: {
        'Incidents by area': sortedParks
            .take(10)
            .map((e) => ChartDataPoint(e.key, e.value.length.toDouble()))
            .toList(),
        'Severity distribution': IncidentSeverity.values
            .map((s) => ChartDataPoint(s.label, (bySeverity[s] ?? 0).toDouble()))
            .toList(),
        'By incident type': byType.entries
            .map((e) => ChartDataPoint(e.key.label, e.value.toDouble()))
            .toList(),
      },
      tableColumns: const [
        'Area',
        'Total',
        'Critical',
        'High',
        'Medium',
        'Low',
        'Active threats',
      ],
      tableRows: sortedParks.map((entry) {
        final parkIncidents = entry.value;
        return [
          entry.key,
          parkIncidents.length.toString(),
          parkIncidents.where((i) => i.severity == IncidentSeverity.critical).length.toString(),
          parkIncidents.where((i) => i.severity == IncidentSeverity.high).length.toString(),
          parkIncidents.where((i) => i.severity == IncidentSeverity.medium).length.toString(),
          parkIncidents.where((i) => i.severity == IncidentSeverity.low).length.toString(),
          parkIncidents.where((i) => i.activeThreat).length.toString(),
        ];
      }).toList(),
    );
  }

  ConservationReportResult _emptyResult() => ConservationReportResult(
        reportType: ConservationReportType.poachingHotspot,
        generatedAt: DateTime.now(),
        totalIncidents: 0,
        summaryMetrics: const {'Total incidents': '0'},
        chartSeries: const {},
        tableColumns: const ['Area', 'Total', 'Critical', 'High', 'Medium', 'Low', 'Active threats'],
        tableRows: const [],
      );
}
