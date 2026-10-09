import '../../../incidents/models/incident_report.dart';
import '../../domain/conservation_report_filter.dart';
import '../../domain/conservation_report_result.dart';
import '../../domain/conservation_report_type.dart';
import 'report_generator.dart';

/// Measures conservation response effectiveness using workflow outcomes.
///
/// Calculates resolution rates, workflow status distribution, and
/// response metrics to evaluate how well the team manages incidents.
class ConservationOutcomeGenerator extends ReportGenerator {
  @override
  ConservationReportResult generate(
    List<IncidentReport> incidents,
    ConservationReportFilter filters,
  ) {
    if (incidents.isEmpty) return _emptyResult();

    // Workflow status distribution
    final byStatus = <IncidentWorkflowStatus, int>{};
    for (final incident in incidents) {
      byStatus[incident.workflowStatus] =
          (byStatus[incident.workflowStatus] ?? 0) + 1;
    }

    // Resolved + closed = successful outcomes
    final resolved =
        (byStatus[IncidentWorkflowStatus.resolved] ?? 0) +
        (byStatus[IncidentWorkflowStatus.closed] ?? 0);
    final resolutionRate = incidents.isEmpty
        ? 0.0
        : (resolved / incidents.length) * 100;

    // Open cases (not closed, rejected, or duplicate)
    final terminalStatuses = {
      IncidentWorkflowStatus.closed,
      IncidentWorkflowStatus.rejected,
      IncidentWorkflowStatus.duplicate,
    };
    final openCases = incidents
        .where((i) => !terminalStatuses.contains(i.workflowStatus))
        .length;

    // Assignment rate
    final assigned = incidents
        .where((i) => i.assignedRangerIds.isNotEmpty)
        .length;
    final assignmentRate = incidents.isEmpty
        ? 0.0
        : (assigned / incidents.length) * 100;

    // Severity of resolved vs unresolved
    final resolvedBySeverity = <IncidentSeverity, int>{};
    final unresolvedBySeverity = <IncidentSeverity, int>{};
    for (final incident in incidents) {
      if (incident.workflowStatus == IncidentWorkflowStatus.closed ||
          incident.workflowStatus == IncidentWorkflowStatus.resolved) {
        resolvedBySeverity[incident.severity] =
            (resolvedBySeverity[incident.severity] ?? 0) + 1;
      } else {
        unresolvedBySeverity[incident.severity] =
            (unresolvedBySeverity[incident.severity] ?? 0) + 1;
      }
    }

    // By park outcome
    final byPark = <String, List<IncidentReport>>{};
    for (final incident in incidents) {
      final park = incident.parkOrBlock.isEmpty
          ? 'Unknown'
          : incident.parkOrBlock;
      byPark.putIfAbsent(park, () => []).add(incident);
    }
    final sortedParks = byPark.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return ConservationReportResult(
      reportType: ConservationReportType.conservationOutcome,
      generatedAt: DateTime.now(),
      totalIncidents: incidents.length,
      summaryMetrics: {
        'Total incidents': incidents.length.toString(),
        'Resolution rate': '${resolutionRate.toStringAsFixed(1)}%',
        'Open cases': openCases.toString(),
        'Assignment rate': '${assignmentRate.toStringAsFixed(1)}%',
        'Resolved / closed': resolved.toString(),
      },
      chartSeries: {
        'Workflow status': IncidentWorkflowStatus.values
            .where((s) => (byStatus[s] ?? 0) > 0)
            .map((s) => ChartDataPoint(s.label, (byStatus[s] ?? 0).toDouble()))
            .toList(),
        'Resolved by severity': IncidentSeverity.values
            .map(
              (s) => ChartDataPoint(
                s.label,
                (resolvedBySeverity[s] ?? 0).toDouble(),
              ),
            )
            .toList(),
        'Unresolved by severity': IncidentSeverity.values
            .map(
              (s) => ChartDataPoint(
                s.label,
                (unresolvedBySeverity[s] ?? 0).toDouble(),
              ),
            )
            .toList(),
      },
      tableColumns: const [
        'Area',
        'Total',
        'Resolved',
        'Open',
        'Resolution %',
        'Assigned',
      ],
      tableRows: sortedParks.map((entry) {
        final parkIncidents = entry.value;
        final parkResolved = parkIncidents
            .where(
              (i) =>
                  i.workflowStatus == IncidentWorkflowStatus.closed ||
                  i.workflowStatus == IncidentWorkflowStatus.resolved,
            )
            .length;
        final parkOpen = parkIncidents
            .where((i) => !terminalStatuses.contains(i.workflowStatus))
            .length;
        final parkRate = parkIncidents.isEmpty
            ? '0.0'
            : ((parkResolved / parkIncidents.length) * 100).toStringAsFixed(1);
        final parkAssigned = parkIncidents
            .where((i) => i.assignedRangerIds.isNotEmpty)
            .length;
        return [
          entry.key,
          parkIncidents.length.toString(),
          parkResolved.toString(),
          parkOpen.toString(),
          '$parkRate%',
          parkAssigned.toString(),
        ];
      }).toList(),
    );
  }

  ConservationReportResult _emptyResult() => ConservationReportResult(
    reportType: ConservationReportType.conservationOutcome,
    generatedAt: DateTime.now(),
    totalIncidents: 0,
    summaryMetrics: const {'Total incidents': '0', 'Resolution rate': '0.0%'},
    chartSeries: const {},
    tableColumns: const [
      'Area',
      'Total',
      'Resolved',
      'Open',
      'Resolution %',
      'Assigned',
    ],
    tableRows: const [],
  );
}
