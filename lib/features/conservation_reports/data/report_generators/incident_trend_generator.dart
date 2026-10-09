import 'package:intl/intl.dart';

import '../../../incidents/models/incident_report.dart';
import '../../domain/conservation_report_filter.dart';
import '../../domain/conservation_report_result.dart';
import '../../domain/conservation_report_type.dart';
import 'report_generator.dart';

/// Analyses how incidents are distributed across time periods.
///
/// Groups incidents by month and by type to reveal temporal patterns,
/// seasonal spikes, and long-term trends.
class IncidentTrendGenerator extends ReportGenerator {
  static final _monthFormat = DateFormat('yyyy-MM');
  static final _displayFormat = DateFormat('MMM yyyy');

  @override
  ConservationReportResult generate(
    List<IncidentReport> incidents,
    ConservationReportFilter filters,
  ) {
    if (incidents.isEmpty) return _emptyResult();

    // Group by month
    final byMonth = <String, List<IncidentReport>>{};
    for (final incident in incidents) {
      final key = _monthFormat.format(incident.createdAt);
      byMonth.putIfAbsent(key, () => []).add(incident);
    }

    // Sort months chronologically
    final sortedMonths = byMonth.keys.toList()..sort();

    // Group by type
    final byType = <IncidentType, int>{};
    for (final incident in incidents) {
      byType[incident.type] = (byType[incident.type] ?? 0) + 1;
    }

    // Group by severity
    final bySeverity = <IncidentSeverity, int>{};
    for (final incident in incidents) {
      bySeverity[incident.severity] = (bySeverity[incident.severity] ?? 0) + 1;
    }

    // Calculate averages
    final avgPerMonth = incidents.length / (sortedMonths.length.clamp(1, 999));

    // Find peak month
    final peakEntry = byMonth.entries.reduce(
      (a, b) => a.value.length >= b.value.length ? a : b,
    );
    final peakMonth = _displayFormat.format(
      DateTime.parse('${peakEntry.key}-01'),
    );

    return ConservationReportResult(
      reportType: ConservationReportType.incidentTrend,
      generatedAt: DateTime.now(),
      totalIncidents: incidents.length,
      summaryMetrics: {
        'Total incidents': incidents.length.toString(),
        'Date range': '${sortedMonths.first} to ${sortedMonths.last}',
        'Peak month': '$peakMonth (${peakEntry.value.length})',
        'Average per month': avgPerMonth.toStringAsFixed(1),
        'Months covered': sortedMonths.length.toString(),
      },
      chartSeries: {
        'Monthly trend': sortedMonths
            .map(
              (m) => ChartDataPoint(
                _displayFormat.format(DateTime.parse('$m-01')),
                byMonth[m]!.length.toDouble(),
              ),
            )
            .toList(),
        'By incident type': byType.entries
            .map((e) => ChartDataPoint(e.key.label, e.value.toDouble()))
            .toList(),
        'By severity': IncidentSeverity.values
            .map(
              (s) => ChartDataPoint(s.label, (bySeverity[s] ?? 0).toDouble()),
            )
            .toList(),
      },
      tableColumns: const [
        'Month',
        'Total',
        'Critical',
        'High',
        'Medium',
        'Low',
      ],
      tableRows: sortedMonths.map((month) {
        final monthIncidents = byMonth[month]!;
        return [
          _displayFormat.format(DateTime.parse('$month-01')),
          monthIncidents.length.toString(),
          monthIncidents
              .where((i) => i.severity == IncidentSeverity.critical)
              .length
              .toString(),
          monthIncidents
              .where((i) => i.severity == IncidentSeverity.high)
              .length
              .toString(),
          monthIncidents
              .where((i) => i.severity == IncidentSeverity.medium)
              .length
              .toString(),
          monthIncidents
              .where((i) => i.severity == IncidentSeverity.low)
              .length
              .toString(),
        ];
      }).toList(),
    );
  }

  ConservationReportResult _emptyResult() => ConservationReportResult(
    reportType: ConservationReportType.incidentTrend,
    generatedAt: DateTime.now(),
    totalIncidents: 0,
    summaryMetrics: const {'Total incidents': '0'},
    chartSeries: const {},
    tableColumns: const ['Month', 'Total', 'Critical', 'High', 'Medium', 'Low'],
    tableRows: const [],
  );
}
