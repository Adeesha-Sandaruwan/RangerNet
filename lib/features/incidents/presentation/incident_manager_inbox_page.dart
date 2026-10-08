import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/incident_management_repository.dart';
import '../domain/incident_report.dart';
import '../domain/ranger_profile.dart';
import 'incident_manager_detail_page.dart';
import 'widgets/incident_status_badges.dart';

/// UC02-only operations inbox for the Park Manager / Duty Supervisor.
class IncidentManagerInboxPage extends StatefulWidget {
  const IncidentManagerInboxPage({required this.manager, super.key});

  final RangerProfile manager;

  @override
  State<IncidentManagerInboxPage> createState() =>
      _IncidentManagerInboxPageState();
}

class _IncidentManagerInboxPageState extends State<IncidentManagerInboxPage> {
  final _repository = IncidentManagementRepository();
  StreamSubscription<List<IncidentReport>>? _subscription;
  List<IncidentReport> _reports = const [];
  final Set<String> _knownIncidentIds = {};
  bool _receivedInitialSnapshot = false;
  IncidentWorkflowStatus? _statusFilter;
  bool _showClosed = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = _repository.watchAllIncidents().listen(
      (reports) {
        if (mounted) {
          if (_receivedInitialSnapshot) {
            final newReports = reports.where(
              (report) =>
                  !_knownIncidentIds.contains(report.id) &&
                  report.workflowStatus == IncidentWorkflowStatus.reported,
            );
            for (final report in newReports) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('New incident reported: ${report.title}'),
                ),
              );
            }
          }
          _receivedInitialSnapshot = true;
          _knownIncidentIds
            ..clear()
            ..addAll(reports.map((report) => report.id));
          setState(() {
            _reports = reports;
            _loading = false;
            _error = null;
          });
        }
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _error = error.toString();
            _loading = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await _repository.loadAllIncidents();
      if (mounted) setState(() => _reports = reports);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectionReports = _reports.where(
      (report) => _showClosed
          ? report.workflowStatus == IncidentWorkflowStatus.closed
          : report.workflowStatus != IncidentWorkflowStatus.closed,
    );
    final filtered = _statusFilter == null
        ? sectionReports.toList()
        : sectionReports
              .where((r) => r.workflowStatus == _statusFilter)
              .toList();
    final openCount = _reports
        .where(
          (report) =>
              report.workflowStatus != IncidentWorkflowStatus.closed &&
              report.workflowStatus != IncidentWorkflowStatus.duplicate &&
              report.workflowStatus != IncidentWorkflowStatus.rejected,
        )
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F3),
      appBar: AppBar(
        title: const Text('Incident management'),
        backgroundColor: const Color(0xFFF5F8F3),
        actions: [
          IconButton(
            tooltip: 'Refresh incidents',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Wildlife / poaching incidents',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Manager: ${widget.manager.displayName} · $openCount open',
                ),
                const SizedBox(height: 14),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(
                        'Open (${_reports.where((report) => report.workflowStatus != IncidentWorkflowStatus.closed).length})',
                      ),
                      icon: const Icon(Icons.pending_actions_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(
                        'Closed (${_reports.where((report) => report.workflowStatus == IncidentWorkflowStatus.closed).length})',
                      ),
                      icon: const Icon(Icons.task_alt_rounded),
                    ),
                  ],
                  selected: {_showClosed},
                  onSelectionChanged: (value) => setState(() {
                    _showClosed = value.first;
                    _statusFilter = null;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<IncidentWorkflowStatus?>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter by status',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  items: [
                    const DropdownMenuItem<IncidentWorkflowStatus?>(
                      child: Text('All statuses'),
                    ),
                    ...IncidentWorkflowStatus.values.map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    ),
                  ],
                  onChanged: (status) => setState(() => _statusFilter = status),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Card(
                    color: const Color(0xFFFFE9E5),
                    child: ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: const Text('Could not load incidents'),
                      subtitle: Text(_error!),
                      trailing: IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.inbox_outlined),
                      title: Text('No incidents match this filter'),
                      subtitle: Text('Pull down to refresh the incident list.'),
                    ),
                  )
                else
                  ...filtered.map(_incidentCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _incidentCard(IncidentReport report) => Card(
    child: ListTile(
      onTap: () => Navigator.of(context)
          .push<void>(
            MaterialPageRoute<void>(
              builder: (_) => IncidentManagerDetailPage(
                report: report,
                manager: widget.manager,
              ),
            ),
          )
          .then((_) => _load()),
      leading: Icon(
        report.activeThreat || report.severity == IncidentSeverity.critical
            ? Icons.warning_amber_rounded
            : Icons.crisis_alert,
        color:
            report.activeThreat || report.severity == IncidentSeverity.critical
            ? const Color(0xFFB54735)
            : const Color(0xFF17613F),
      ),
      title: Text(report.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${report.type.label} · ${report.rangerEmail}'),
          const SizedBox(height: 6),
          IncidentStatusBadges(
            severity: report.severity,
            status: report.workflowStatus,
          ),
          const SizedBox(height: 4),
          Text(_date(report.createdAt)),
        ],
      ),
      isThreeLine: false,
      trailing: const Icon(Icons.chevron_right),
    ),
  );

  String _date(DateTime date) => date.toLocal().toString().substring(0, 16);
}
