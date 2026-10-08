import 'dart:async';

import 'package:flutter/material.dart';

import '../data/incident_management_repository.dart';
import '../domain/incident_report.dart';
import 'incident_responder_detail_page.dart';

/// Assigned UC02 cases for a ranger acting as an incident responder.
class IncidentResponderInboxPage extends StatefulWidget {
  const IncidentResponderInboxPage({
    required this.rangerId,
    required this.responderName,
    super.key,
  });

  final String rangerId;
  final String responderName;

  @override
  State<IncidentResponderInboxPage> createState() =>
      _IncidentResponderInboxPageState();
}

class _IncidentResponderInboxPageState
    extends State<IncidentResponderInboxPage> {
  final _repository = IncidentManagementRepository();
  StreamSubscription<List<IncidentReport>>? _subscription;
  List<IncidentReport> _reports = const [];
  final Set<String> _knownIncidentIds = {};
  bool _receivedInitialSnapshot = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = _repository
        .watchAssignedIncidents(widget.rangerId)
        .listen(
          (reports) {
            if (mounted) {
              if (_receivedInitialSnapshot) {
                final newlyAssigned = reports.where(
                  (report) => !_knownIncidentIds.contains(report.id),
                );
                for (final report in newlyAssigned) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Incident assigned: ${report.title}'),
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
      final reports = await _repository.loadAssignedIncidents(widget.rangerId);
      if (mounted) setState(() => _reports = reports);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F8F3),
    appBar: AppBar(
      title: const Text('Assigned incidents'),
      backgroundColor: const Color(0xFFF5F8F3),
      actions: [
        IconButton(
          tooltip: 'Refresh assigned incidents',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'UC02 · Response work',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              const Text('Incidents assigned to your ranger account.'),
              const SizedBox(height: 12),
              if (_error != null)
                Card(
                  color: const Color(0xFFFFE9E5),
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('Could not load assigned incidents'),
                    subtitle: Text(_error!),
                  ),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_reports.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.assignment_outlined),
                    title: Text('No incidents assigned to you'),
                    subtitle: Text(
                      'When a manager assigns an incident, it will appear here.',
                    ),
                  ),
                )
              else
                ..._reports.map(_incidentCard),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _incidentCard(IncidentReport report) => Card(
    child: ListTile(
      onTap: () => Navigator.of(context)
          .push<void>(
            MaterialPageRoute<void>(
              builder: (_) => IncidentResponderDetailPage(
                report: report,
                responderName: widget.responderName,
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
      subtitle: Text(
        '${report.type.label} · ${report.severity.label}\n'
        '${report.workflowStatus.label} · ${report.parkOrBlock}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}
