import 'package:flutter/material.dart';

import '../../incidents/domain/incident_report.dart';
import '../../incidents/domain/ranger_profile.dart';
import '../data/conservation_analysis_service.dart';
import '../data/conservation_data_repository.dart';
import '../domain/conservation_report_filter.dart';
import '../domain/conservation_report_result.dart';
import '../domain/conservation_report_type.dart';
import 'widgets/report_charts.dart';
import 'widgets/report_data_table.dart';
import 'widgets/report_export_bar.dart';
import 'widgets/report_filter_panel.dart';
import 'widgets/report_summary_cards.dart';
import 'widgets/report_type_selector.dart';

/// UC04 – Analyse conservation data and generate reports.
///
/// This page assembles the full report workflow:
/// 1. Select a report type
/// 2. Configure filters (park, date range, type, severity, patrol team)
/// 3. Generate the report
/// 4. View results (KPI cards, charts, detail table)
/// 5. Export to PDF or CSV
class ConservationReportPage extends StatefulWidget {
  const ConservationReportPage({required this.manager, super.key});

  final RangerProfile manager;

  @override
  State<ConservationReportPage> createState() => _ConservationReportPageState();
}

class _ConservationReportPageState extends State<ConservationReportPage> {
  final _repository = ConservationDataRepository();
  final _analysisService = ConservationAnalysisService();

  // Data loaded from Firestore
  List<IncidentReport> _allIncidents = const [];
  List<String> _parks = const [];
  List<RangerProfile> _rangers = const [];
  bool _dataLoading = true;
  String? _dataError;

  // Report state
  ConservationReportType? _selectedType;
  ConservationReportFilter _filter = const ConservationReportFilter();
  ConservationReportResult? _result;
  bool _generating = false;
  String? _reportError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _dataLoading = true;
      _dataError = null;
    });
    try {
      final incidents = await _repository.loadAllIncidents();
      final parks = await _repository.loadDistinctParks();
      List<RangerProfile> rangers = const [];
      try {
        rangers = await _repository.loadActiveRangers();
      } catch (_) {
        // Ranger list is optional for filters; don't block the page.
      }
      if (mounted) {
        setState(() {
          _allIncidents = incidents;
          _parks = parks;
          _rangers = rangers;
          _dataLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _dataError = 'Could not load conservation data: $error';
          _dataLoading = false;
        });
      }
    }
  }

  void _generateReport() {
    if (_selectedType == null) {
      setState(() => _reportError = 'Select a report type first.');
      return;
    }
    setState(() {
      _generating = true;
      _reportError = null;
      _result = null;
    });
    try {
      final result = _analysisService.generateReport(
        reportType: _selectedType!,
        allIncidents: _allIncidents,
        filters: _filter,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _generating = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _reportError = 'Report generation failed: $error';
          _generating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F3),
      appBar: AppBar(
        title: const Text('Conservation Reports'),
        backgroundColor: const Color(0xFFF5F8F3),
        actions: [
          IconButton(
            tooltip: 'Reload data from Firestore',
            onPressed: _dataLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: _dataLoading
              ? const Center(child: CircularProgressIndicator())
              : _dataError != null
                  ? _errorView()
                  : _reportFlow(),
        ),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                _dataError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _reportFlow() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Text(
            'Conservation data analysis',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Manager: ${widget.manager.displayName} · '
            '${_allIncidents.length} incidents available',
          ),
          const SizedBox(height: 16),

          // Step 1: Report type selection
          Text(
            'Select report type',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ReportTypeSelector(
            selected: _selectedType,
            onSelected: (type) {
              setState(() {
                _selectedType = type;
                _result = null;
                _reportError = null;
              });
            },
          ),
          const SizedBox(height: 16),

          // Step 2: Filters
          ReportFilterPanel(
            filter: _filter,
            onFilterChanged: (newFilter) {
              setState(() {
                _filter = newFilter;
                _result = null;
                _reportError = null;
              });
            },
            parks: _parks,
            rangers: _rangers,
          ),
          const SizedBox(height: 16),

          // Generate button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF17613F),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _generating || _selectedType == null
                ? null
                : _generateReport,
            icon: _generating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.analytics_outlined),
            label: Text(
              _selectedType == null
                  ? 'Select a report type above'
                  : 'Generate ${_selectedType!.title}',
            ),
          ),

          // Error
          if (_reportError != null) ...[
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFFFE9E5),
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Report generation error'),
                subtitle: Text(_reportError!),
              ),
            ),
          ],

          // Results
          if (_result != null) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Report title
            Text(
              _result!.displayTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (_result!.isEmpty) ...[
              const SizedBox(height: 12),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('No data matches the current filters'),
                  subtitle: Text(
                    'Try broadening the date range or removing filters to include more incidents.',
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),

              // Summary KPIs
              ReportSummaryCards(result: _result!),
              const SizedBox(height: 12),

              // Charts
              ReportCharts(result: _result!),
              const SizedBox(height: 12),

              // Detail table
              ReportDataTable(result: _result!),
              const SizedBox(height: 12),

              // Export
              ReportExportBar(result: _result!),
            ],
          ],

          const SizedBox(height: 32),
        ],
      );
}
