import 'package:flutter/material.dart';

import '../data/incident_management_repository.dart';
import '../domain/incident_report.dart';
import '../domain/incident_timeline_event.dart';
import '../domain/ranger_profile.dart';
import 'incident_detail_page.dart';

class IncidentManagerDetailPage extends StatefulWidget {
  const IncidentManagerDetailPage({
    required this.report,
    required this.manager,
    super.key,
  });

  final IncidentReport report;
  final RangerProfile manager;

  @override
  State<IncidentManagerDetailPage> createState() =>
      _IncidentManagerDetailPageState();
}

class _IncidentManagerDetailPageState extends State<IncidentManagerDetailPage> {
  final _repository = IncidentManagementRepository();
  final _note = TextEditingController();
  late IncidentReport _report;
  List<IncidentTimelineEvent> _events = const [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _loadTimeline();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadTimeline() async {
    try {
      final events = await _repository.loadTimeline(_report.id);
      if (mounted) setState(() => _events = events);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not load history: $error');
    }
  }

  Future<void> _saveReview() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository.reviewIncident(
        incidentId: _report.id,
        severity: _report.severity,
        managerName: widget.manager.displayName,
        note: _note.text,
      );
      if (!mounted) return;
      setState(() {
        _report = _report.copyWith(
          workflowStatus: IncidentWorkflowStatus.underReview,
        );
        _note.clear();
      });
      await _loadTimeline();
      _showMessage('Review saved.');
    } catch (error) {
      if (mounted) setState(() => _error = 'Review was not saved: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F8F3),
    appBar: AppBar(title: const Text('Review incident')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  _report.activeThreat ||
                          _report.severity == IncidentSeverity.critical
                      ? Icons.warning_amber_rounded
                      : Icons.crisis_alert,
                  color: const Color(0xFF17613F),
                ),
                title: Text(_report.title),
                subtitle: Text(
                  '${_report.type.label} · ${_report.workflowStatus.label}\n'
                  'Reporter: ${_report.rangerEmail}',
                ),
                isThreeLine: true,
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Location'),
                subtitle: Text(
                  _report.latitude == null || _report.longitude == null
                      ? 'No coordinates recorded'
                      : '${_report.latitude!.toStringAsFixed(6)}, '
                          '${_report.longitude!.toStringAsFixed(6)} · '
                          '${_report.parkOrBlock}',
                ),
                trailing: IconButton(
                  tooltip: 'View full report and evidence',
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => IncidentDetailPage(report: _report),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new),
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Review and priority',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<IncidentSeverity>(
                      initialValue: _report.severity,
                      decoration: const InputDecoration(
                        labelText: 'Severity',
                        border: OutlineInputBorder(),
                      ),
                      items: IncidentSeverity.values
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _report =
                                    _report.copyWith(severity: value));
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _note,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Manager review note (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _saveReview,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save review'),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Card(
                color: const Color(0xFFFFE9E5),
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(_error!),
                ),
              ),
            const SizedBox(height: 8),
            Text('Incident history',
                style: Theme.of(context).textTheme.titleLarge),
            if (_events.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('No management actions recorded yet'),
                ),
              )
            else
              ..._events.map(_eventCard),
          ],
        ),
      ),
    ),
  );

  Widget _eventCard(IncidentTimelineEvent event) => Card(
    child: ListTile(
      leading: const Icon(Icons.history),
      title: Text(event.message),
      subtitle: Text('${event.actorName} · ${event.createdAt.toLocal()}'),
    ),
  );

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
