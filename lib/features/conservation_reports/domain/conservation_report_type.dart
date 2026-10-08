/// The six conservation report types available to managers in UC04.
enum ConservationReportType {
  poachingHotspot(
    'Poaching Hotspot Report',
    'Identify areas with the highest concentration of poaching-related incidents.',
    'Analyses incident locations and severity to reveal hotspot clusters.',
  ),
  patrolCoverage(
    'Patrol Coverage Report',
    'Evaluate how patrol teams cover the protected area.',
    'Aggregates incidents by assigned rangers and patrol identifiers.',
  ),
  humanWildlifeConflict(
    'Human–Wildlife Conflict Report',
    'Analyse incidents involving direct human–wildlife interaction.',
    'Filters conflict-type incidents and breaks them down by location and severity.',
  ),
  incidentTrend(
    'Incident Trend Report',
    'Track how incident volume changes over time.',
    'Groups incidents by date, type, and severity to reveal temporal patterns.',
  ),
  wildlifeMonitoring(
    'Wildlife Monitoring Report',
    'Monitor wildlife-related activity across the conservation area.',
    'Uses incident type and location data as a proxy for wildlife observations.',
  ),
  conservationOutcome(
    'Conservation Outcome Report',
    'Measure the effectiveness of conservation response efforts.',
    'Calculates resolution rates, response times, and workflow outcomes.',
  );

  const ConservationReportType(this.title, this.subtitle, this.methodology);

  /// Human-readable name shown in the report selector.
  final String title;

  /// Short description shown beneath the title.
  final String subtitle;

  /// Explains how the report processes the data.
  final String methodology;
}
