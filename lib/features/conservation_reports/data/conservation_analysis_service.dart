import '../../incidents/models/incident_report.dart';
import '../domain/conservation_report_filter.dart';
import '../domain/conservation_report_result.dart';
import '../domain/conservation_report_type.dart';
import 'report_generators/conservation_outcome_generator.dart';
import 'report_generators/human_wildlife_conflict_generator.dart';
import 'report_generators/incident_trend_generator.dart';
import 'report_generators/patrol_coverage_generator.dart';
import 'report_generators/poaching_hotspot_generator.dart';
import 'report_generators/report_generator.dart';
import 'report_generators/wildlife_monitoring_generator.dart';

/// Orchestrates UC04 report generation by dispatching to the correct
/// [ReportGenerator] strategy and applying filters.
///
/// This is the single entry point the presentation layer calls.
class ConservationAnalysisService {
  ConservationAnalysisService();

  /// Registry of generators by report type.
  final Map<ConservationReportType, ReportGenerator> _generators = {
    ConservationReportType.poachingHotspot: PoachingHotspotGenerator(),
    ConservationReportType.patrolCoverage: PatrolCoverageGenerator(),
    ConservationReportType.humanWildlifeConflict:
        HumanWildlifeConflictGenerator(),
    ConservationReportType.incidentTrend: IncidentTrendGenerator(),
    ConservationReportType.wildlifeMonitoring: WildlifeMonitoringGenerator(),
    ConservationReportType.conservationOutcome: ConservationOutcomeGenerator(),
  };

  /// Generates a conservation report of [reportType] from [allIncidents],
  /// applying [filters] before passing data to the generator.
  ///
  /// Throws [ArgumentError] if the filter is invalid (e.g. end before start).
  /// Throws [StateError] if no generator is registered for [reportType].
  ConservationReportResult generateReport({
    required ConservationReportType reportType,
    required List<IncidentReport> allIncidents,
    required ConservationReportFilter filters,
  }) {
    // Validate filters
    filters.validate();

    // Apply filters
    final filtered = filters.apply(allIncidents);

    // Dispatch to the correct generator
    final generator = _generators[reportType];
    if (generator == null) {
      throw StateError(
        'No report generator registered for ${reportType.title}.',
      );
    }

    return generator.generate(filtered, filters);
  }

  /// Returns the generator for a given report type (useful for testing).
  ReportGenerator? generatorFor(ConservationReportType type) =>
      _generators[type];
}
