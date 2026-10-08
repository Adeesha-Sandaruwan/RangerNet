import '../../incidents/domain/incident_report.dart';
import '../domain/conservation_report_filter.dart';
import '../domain/conservation_report_result.dart';

/// Strategy interface for UC04 conservation report generators.
///
/// Each concrete implementation aggregates incident data into a
/// [ConservationReportResult] containing summary metrics, chart data,
/// and a detail table. The presentation layer can render any result
/// without knowing which generator produced it.
abstract class ReportGenerator {
  /// Generates a report from the filtered [incidents].
  ///
  /// The caller is responsible for applying [filters] before invoking
  /// this method. The generator may inspect the filter for display
  /// purposes (e.g. date range in the title).
  ConservationReportResult generate(
    List<IncidentReport> incidents,
    ConservationReportFilter filters,
  );
}
