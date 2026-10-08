import 'conservation_report_type.dart';

/// The output of a UC04 conservation report generator.
///
/// Every report type populates the same structure so the presentation layer
/// can render summary cards, charts, and a data table without coupling to
/// individual generator implementations.
class ConservationReportResult {
  const ConservationReportResult({
    required this.reportType,
    required this.generatedAt,
    required this.totalIncidents,
    required this.summaryMetrics,
    required this.chartSeries,
    required this.tableColumns,
    required this.tableRows,
    this.title,
  });

  /// Which report type produced this result.
  final ConservationReportType reportType;

  /// Timestamp of generation.
  final DateTime generatedAt;

  /// Total incidents used in the analysis after filtering.
  final int totalIncidents;

  /// Optional title override (defaults to `reportType.title`).
  final String? title;

  /// Key-value pairs shown as KPI summary cards.
  /// Example: `{'High-severity incidents': '12', 'Top hotspot': 'Yala North'}`
  final Map<String, String> summaryMetrics;

  /// Named data series for chart rendering.
  /// Each entry maps a series name to ordered (label, value) pairs.
  /// Example: `{'By type': [('Snare', 5), ('Carcass', 3)]}`
  final Map<String, List<ChartDataPoint>> chartSeries;

  /// Column headers for the detail table.
  final List<String> tableColumns;

  /// Row data for the detail table; each row has one value per column.
  final List<List<String>> tableRows;

  /// Display title for the report header.
  String get displayTitle => title ?? reportType.title;

  /// `true` when the report contains no data.
  bool get isEmpty => totalIncidents == 0;
}

/// A single data point used to build bar, line and pie charts.
class ChartDataPoint {
  const ChartDataPoint(this.label, this.value);

  /// X-axis label or category name.
  final String label;

  /// Numeric value for this label.
  final double value;
}
