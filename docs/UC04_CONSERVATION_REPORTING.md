# UC04 – Analyse Conservation Data and Generate Reports

> **Branch:** `feature/uc04-conservation-reporting`
> **Status:** Implemented

## Overview

UC04 adds conservation analytics to the RangerNet Manager dashboard. Managers
can select from six report types, apply filters, analyse incident data, view
interactive charts and detail tables, and export results as PDF or CSV.

## Report Types

| # | Report | Description |
|---|--------|-------------|
| 1 | Poaching Hotspot | Clusters incidents by location and severity to reveal high-risk areas |
| 2 | Patrol Coverage | Evaluates ranger and patrol team deployment across the conservation area |
| 3 | Human–Wildlife Conflict | Analyses conflict-type incidents (snares, carcasses, suspicious activity) |
| 4 | Incident Trend | Time-series view of incident volume grouped by month, type, and severity |
| 5 | Wildlife Monitoring | Monitors wildlife-related activity using incident data as a proxy |
| 6 | Conservation Outcome | Measures resolution rates, assignment rates, and workflow outcomes |

## Filters

All reports support these filters (all optional):

- **Park / Block** – exact match on `IncidentReport.parkOrBlock`
- **Date range** – start and end date pickers
- **Incident type** – multi-select from `IncidentType` enum values
- **Severity** – multi-select from `IncidentSeverity` enum values
- **Assigned ranger** – dropdown of active ranger profiles
- **Species keyword** – text match in title/description (best-effort)

## Architecture

```
ConservationReportPage (presentation)
  ├── ReportTypeSelector        → select one of 6 types
  ├── ReportFilterPanel          → configure filters
  ├── ConservationAnalysisService (data/service layer)
  │     ├── ConservationReportFilter.apply()  → filter incidents
  │     └── ReportGenerator.generate()        → strategy dispatch
  │           ├── PoachingHotspotGenerator
  │           ├── PatrolCoverageGenerator
  │           ├── HumanWildlifeConflictGenerator
  │           ├── IncidentTrendGenerator
  │           ├── WildlifeMonitoringGenerator
  │           └── ConservationOutcomeGenerator
  ├── ReportSummaryCards         → KPI metrics
  ├── ReportCharts               → fl_chart bar/pie charts
  ├── ReportDataTable            → scrollable DataTable
  └── ReportExportBar            → PDF/CSV via printing package
        └── ConservationExportService
```

## File Structure

```
lib/features/conservation_reports/
├── domain/
│   ├── conservation_report_type.dart     # Enum: 6 report types
│   ├── conservation_report_filter.dart   # Filter criteria model
│   └── conservation_report_result.dart   # Report output model
├── data/
│   ├── conservation_data_repository.dart # Firestore reads
│   ├── conservation_analysis_service.dart# Orchestrator
│   ├── conservation_export_service.dart  # PDF/CSV export
│   └── report_generators/
│       ├── report_generator.dart                    # Abstract strategy
│       ├── poaching_hotspot_generator.dart
│       ├── patrol_coverage_generator.dart
│       ├── human_wildlife_conflict_generator.dart
│       ├── incident_trend_generator.dart
│       ├── wildlife_monitoring_generator.dart
│       └── conservation_outcome_generator.dart
└── presentation/
    ├── conservation_report_page.dart     # Main page
    └── widgets/
        ├── report_type_selector.dart
        ├── report_filter_panel.dart
        ├── report_summary_cards.dart
        ├── report_charts.dart
        ├── report_data_table.dart
        └── report_export_bar.dart

test/features/conservation_reports/
├── conservation_report_filter_test.dart
├── conservation_analysis_service_test.dart
└── conservation_export_service_test.dart
```

## Dependencies Added

- `fl_chart` – bar and pie chart visualisation
- `pdf` – PDF document generation
- `printing` – cross-platform PDF sharing/download
- `csv` – CSV file generation
- `intl` – date formatting

## Error Handling

- **Data retrieval failure:** Firestore errors show a retry-able error card
- **No data matches filters:** Informational card with suggestion to broaden filters
- **Report generation failure:** Error card with details
- **Export failure:** Inline error message with retry option

## Access Control

- Only managers can access conservation reports (Firestore security rules)
- Entry point is on the Manager Dashboard ("Go to conservation reports")
- No changes to ranger or responder UI
