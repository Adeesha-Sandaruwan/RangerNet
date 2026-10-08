import '../../../incidents/domain/incident_report.dart';
import '../../domain/conservation_report_filter.dart';
import '../../domain/conservation_report_result.dart';
import '../../domain/conservation_report_type.dart';
import 'report_generator.dart';

/// Evaluates ranger and patrol team deployment across the conservation area.
///
/// Uses `assignedRangerIds`, `assignedRangerNames`, and `patrolId` to
/// aggregate coverage per ranger, per patrol, and per park.
class PatrolCoverageGenerator extends ReportGenerator {
  @override
  ConservationReportResult generate(
    List<IncidentReport> incidents,
    ConservationReportFilter filters,
  ) {
    if (incidents.isEmpty) return _emptyResult();

    // Count incidents per assigned ranger
    final byRanger = <String, int>{};
    final rangerIdToName = <String, String>{};
    for (final incident in incidents) {
      for (var i = 0; i < incident.assignedRangerIds.length; i++) {
        final id = incident.assignedRangerIds[i];
        byRanger[id] = (byRanger[id] ?? 0) + 1;
        if (i < incident.assignedRangerNames.length) {
          rangerIdToName[id] = incident.assignedRangerNames[i];
        }
      }
    }

    // Count incidents per patrol ID
    final byPatrol = <String, int>{};
    for (final incident in incidents) {
      final patrol = incident.patrolId?.isNotEmpty == true
          ? incident.patrolId!
          : 'Unassigned';
      byPatrol[patrol] = (byPatrol[patrol] ?? 0) + 1;
    }
    final sortedPatrols = byPatrol.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Coverage per park
    final byPark = <String, int>{};
    for (final incident in incidents) {
      final park = incident.parkOrBlock.isEmpty ? 'Unknown' : incident.parkOrBlock;
      byPark[park] = (byPark[park] ?? 0) + 1;
    }

    // Unassigned incidents (no rangers assigned)
    final unassigned =
        incidents.where((i) => i.assignedRangerIds.isEmpty).length;
    final assigned = incidents.length - unassigned;

    // Sort rangers by incident count descending
    final sortedRangers = byRanger.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ConservationReportResult(
      reportType: ConservationReportType.patrolCoverage,
      generatedAt: DateTime.now(),
      totalIncidents: incidents.length,
      summaryMetrics: {
        'Total incidents': incidents.length.toString(),
        'Assigned responses': assigned.toString(),
        'Unassigned': unassigned.toString(),
        'Rangers involved': byRanger.length.toString(),
        'Patrol IDs used': byPatrol.length.toString(),
        'Areas covered': byPark.length.toString(),
      },
      chartSeries: {
        'Responses per ranger': sortedRangers
            .take(10)
            .map((e) => ChartDataPoint(
                  rangerIdToName[e.key] ?? e.key.substring(0, 8),
                  e.value.toDouble(),
                ))
            .toList(),
        'Incidents per patrol': sortedPatrols
            .take(10)
            .map((e) => ChartDataPoint(e.key, e.value.toDouble()))
            .toList(),
        'Coverage by area': byPark.entries
            .map((e) => ChartDataPoint(e.key, e.value.toDouble()))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value)),
      },
      tableColumns: const [
        'Ranger',
        'Incidents handled',
        'Patrol IDs',
        'Areas covered',
      ],
      tableRows: sortedRangers.map((ranger) {
        final rangerId = ranger.key;
        final rangerIncidents = incidents
            .where((i) => i.assignedRangerIds.contains(rangerId))
            .toList();
        final patrols = rangerIncidents
            .map((i) => i.patrolId ?? '')
            .where((p) => p.isNotEmpty)
            .toSet();
        final areas = rangerIncidents
            .map((i) => i.parkOrBlock)
            .where((p) => p.isNotEmpty)
            .toSet();
        return [
          rangerIdToName[rangerId] ?? rangerId.substring(0, 8),
          ranger.value.toString(),
          patrols.isEmpty ? 'None' : patrols.join(', '),
          areas.isEmpty ? 'Unknown' : areas.join(', '),
        ];
      }).toList(),
    );
  }

  ConservationReportResult _emptyResult() => ConservationReportResult(
        reportType: ConservationReportType.patrolCoverage,
        generatedAt: DateTime.now(),
        totalIncidents: 0,
        summaryMetrics: const {'Total incidents': '0'},
        chartSeries: const {},
        tableColumns: const ['Ranger', 'Incidents handled', 'Patrol IDs', 'Areas covered'],
        tableRows: const [],
      );
}
