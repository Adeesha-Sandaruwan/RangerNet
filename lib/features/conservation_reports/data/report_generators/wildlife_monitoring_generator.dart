import '../../../incidents/models/incident_report.dart';
import '../../domain/conservation_report_filter.dart';
import '../../domain/conservation_report_result.dart';
import '../../domain/conservation_report_type.dart';
import 'report_generator.dart';

/// Monitors wildlife-related activity using incident data as a proxy.
///
/// Since the current data model has no dedicated species or observation
/// entities, this generator uses incident type and location data to
/// approximate wildlife monitoring patterns.
class WildlifeMonitoringGenerator extends ReportGenerator {
  /// Types most closely related to wildlife observations.
  static const wildlifeTypes = {
    IncidentType.animalCarcass,
    IncidentType.illegalSnare,
    IncidentType.other,
  };

  @override
  ConservationReportResult generate(
    List<IncidentReport> incidents,
    ConservationReportFilter filters,
  ) {
    if (incidents.isEmpty) return _emptyResult();

    // Wildlife-relevant incidents
    final wildlifeIncidents =
        incidents.where((i) => wildlifeTypes.contains(i.type)).toList();

    // By type
    final byType = <IncidentType, int>{};
    for (final incident in incidents) {
      byType[incident.type] = (byType[incident.type] ?? 0) + 1;
    }

    // By park
    final byPark = <String, int>{};
    for (final incident in wildlifeIncidents) {
      final park = incident.parkOrBlock.isEmpty ? 'Unknown' : incident.parkOrBlock;
      byPark[park] = (byPark[park] ?? 0) + 1;
    }
    final sortedParks = byPark.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Geo-tagged percentage
    final geoTagged =
        wildlifeIncidents.where((i) => i.latitude != null && i.longitude != null).length;
    final geoRate = wildlifeIncidents.isEmpty
        ? 0.0
        : (geoTagged / wildlifeIncidents.length) * 100;

    // Carcasses specifically (important wildlife indicator)
    final carcasses =
        incidents.where((i) => i.type == IncidentType.animalCarcass).length;

    return ConservationReportResult(
      reportType: ConservationReportType.wildlifeMonitoring,
      generatedAt: DateTime.now(),
      totalIncidents: incidents.length,
      summaryMetrics: {
        'Total incidents': incidents.length.toString(),
        'Wildlife-related': wildlifeIncidents.length.toString(),
        'Animal carcasses': carcasses.toString(),
        'Geo-tagged': '${geoRate.toStringAsFixed(1)}%',
        'Areas with activity': byPark.length.toString(),
      },
      chartSeries: {
        'All incident types': byType.entries
            .map((e) => ChartDataPoint(e.key.label, e.value.toDouble()))
            .toList(),
        'Wildlife activity by area': sortedParks
            .take(10)
            .map((e) => ChartDataPoint(e.key, e.value.toDouble()))
            .toList(),
      },
      tableColumns: const [
        'Area',
        'Wildlife incidents',
        'Carcasses',
        'Snare related',
        'Other',
        'GPS-tagged',
      ],
      tableRows: sortedParks.map((entry) {
        final parkIncidents = wildlifeIncidents
            .where((i) => (i.parkOrBlock.isEmpty ? 'Unknown' : i.parkOrBlock) == entry.key)
            .toList();
        return [
          entry.key,
          parkIncidents.length.toString(),
          parkIncidents.where((i) => i.type == IncidentType.animalCarcass).length.toString(),
          parkIncidents.where((i) => i.type == IncidentType.illegalSnare).length.toString(),
          parkIncidents.where((i) => i.type == IncidentType.other).length.toString(),
          parkIncidents.where((i) => i.latitude != null).length.toString(),
        ];
      }).toList(),
    );
  }

  ConservationReportResult _emptyResult() => ConservationReportResult(
        reportType: ConservationReportType.wildlifeMonitoring,
        generatedAt: DateTime.now(),
        totalIncidents: 0,
        summaryMetrics: const {'Total incidents': '0'},
        chartSeries: const {},
        tableColumns: const ['Area', 'Wildlife incidents', 'Carcasses', 'Snare related', 'Other', 'GPS-tagged'],
        tableRows: const [],
      );
}
