import '../../incidents/models/incident_report.dart';

/// Immutable filter criteria for UC04 conservation report generation.
///
/// All fields are optional. When a field is `null`, no filtering is applied
/// for that dimension, meaning all values are included.
class ConservationReportFilter {
  const ConservationReportFilter({
    this.parkOrBlock,
    this.zone,
    this.startDate,
    this.endDate,
    this.incidentTypes,
    this.severities,
    this.patrolTeamRangerIds,
    this.species,
  });

  /// Park / block name to filter by (exact match on `IncidentReport.parkOrBlock`).
  final String? parkOrBlock;

  /// Optional zone within the park (currently derived from `parkOrBlock`).
  final String? zone;

  /// Inclusive start of the date range.
  final DateTime? startDate;

  /// Inclusive end of the date range.
  final DateTime? endDate;

  /// Limit to these incident types only.
  final List<IncidentType>? incidentTypes;

  /// Limit to these severity levels only.
  final List<IncidentSeverity>? severities;

  /// Limit to incidents assigned to any of these ranger UIDs.
  final List<String>? patrolTeamRangerIds;

  /// Optional species keyword filter (matched against incident description).
  final String? species;

  /// Returns `true` when no filter criterion is set.
  bool get isEmpty =>
      parkOrBlock == null &&
      zone == null &&
      startDate == null &&
      endDate == null &&
      incidentTypes == null &&
      severities == null &&
      patrolTeamRangerIds == null &&
      species == null;

  /// Validates that the date range is logically correct.
  /// Throws [ArgumentError] when end is before start.
  void validate() {
    if (startDate != null && endDate != null && endDate!.isBefore(startDate!)) {
      throw ArgumentError('End date cannot be before start date.');
    }
  }

  /// Applies every set filter to [incidents] and returns matching entries.
  List<IncidentReport> apply(List<IncidentReport> incidents) {
    validate();
    return incidents.where(_matches).toList();
  }

  bool _matches(IncidentReport report) {
    if (parkOrBlock != null &&
        report.parkOrBlock.toLowerCase() != parkOrBlock!.toLowerCase()) {
      return false;
    }
    if (zone != null &&
        !report.parkOrBlock.toLowerCase().contains(zone!.toLowerCase())) {
      return false;
    }
    if (startDate != null && report.createdAt.isBefore(startDate!)) {
      return false;
    }
    if (endDate != null &&
        report.createdAt.isAfter(endDate!.add(const Duration(days: 1)))) {
      return false;
    }
    if (incidentTypes != null && !incidentTypes!.contains(report.type)) {
      return false;
    }
    if (severities != null && !severities!.contains(report.severity)) {
      return false;
    }
    if (patrolTeamRangerIds != null &&
        !report.assignedRangerIds
            .any((id) => patrolTeamRangerIds!.contains(id))) {
      return false;
    }
    if (species != null &&
        species!.isNotEmpty &&
        !report.description.toLowerCase().contains(species!.toLowerCase()) &&
        !report.title.toLowerCase().contains(species!.toLowerCase())) {
      return false;
    }
    return true;
  }

  ConservationReportFilter copyWith({
    String? Function()? parkOrBlock,
    String? Function()? zone,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
    List<IncidentType>? Function()? incidentTypes,
    List<IncidentSeverity>? Function()? severities,
    List<String>? Function()? patrolTeamRangerIds,
    String? Function()? species,
  }) =>
      ConservationReportFilter(
        parkOrBlock: parkOrBlock != null ? parkOrBlock() : this.parkOrBlock,
        zone: zone != null ? zone() : this.zone,
        startDate: startDate != null ? startDate() : this.startDate,
        endDate: endDate != null ? endDate() : this.endDate,
        incidentTypes:
            incidentTypes != null ? incidentTypes() : this.incidentTypes,
        severities: severities != null ? severities() : this.severities,
        patrolTeamRangerIds: patrolTeamRangerIds != null
            ? patrolTeamRangerIds()
            : this.patrolTeamRangerIds,
        species: species != null ? species() : this.species,
      );
}
