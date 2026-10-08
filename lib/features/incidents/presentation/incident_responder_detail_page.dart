import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/incident_evidence_picker.dart';
import '../data/incident_management_repository.dart';
import '../domain/incident_report.dart';
import '../domain/incident_timeline_event.dart';
import 'incident_detail_page.dart';

class IncidentResponderDetailPage extends StatefulWidget {
  const IncidentResponderDetailPage({
    required this.report,
    required this.responderName,
    super.key,
  });

  final IncidentReport report;
  final String responderName;

  @override
  State<IncidentResponderDetailPage> createState() =>
      _IncidentResponderDetailPageState();
}

class _IncidentResponderDetailPageState
    extends State<IncidentResponderDetailPage> {
  final _repository = IncidentManagementRepository();
  final _evidencePicker = IncidentEvidencePicker();
  final _notes = TextEditingController();
  final List<IncidentEvidence> _evidence = [];
  List<IncidentTimelineEvent> _history = const [];
  bool _saving = false;
  String? _error;
  late IncidentWorkflowStatus _workflowStatus;

  bool get _readOnly =>
      _workflowStatus == IncidentWorkflowStatus.closed ||
      _workflowStatus == IncidentWorkflowStatus.resolved;

  @override
  void initState() {
    super.initState();
    _workflowStatus = widget.report.workflowStatus;
    _loadHistory();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _repository.loadTimeline(widget.report.id);
      if (mounted) setState(() => _history = history);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not load incident history: $error');
      }
    }
  }

  Future<void> _saveUpdate(IncidentWorkflowStatus status) async {
    if (_notes.text.trim().length < 5) {
      setState(
        () => _error = 'Describe the response using at least 5 characters.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository.recordResponderUpdate(
        incidentId: widget.report.id,
        responderName: widget.responderName,
        note: _notes.text,
        status: status,
        evidence: List.unmodifiable(_evidence),
      );
      if (!mounted) return;
      _notes.clear();
      setState(() {
        _evidence.clear();
        _workflowStatus = status;
      });
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Response update saved: ${status.label}.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'Update was not saved: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addEvidence(EvidenceSource source) async {
    if (_evidence.length >= IncidentEvidencePicker.maxEvidenceCount) {
      setState(() => _error = 'You can attach up to three response photos.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final photo = await _evidencePicker.pick(source);
      if (photo != null && mounted) setState(() => _evidence.add(photo));
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Photo could not be attached: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F3),
      appBar: AppBar(title: const Text('Respond to incident')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.crisis_alert),
                  title: Text(report.title),
                  subtitle: Text(
                    '${report.type.label} · ${report.severity.label}\n'
                    'Status: ${report.workflowStatus.label}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'View report and evidence',
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => IncidentDetailPage(report: report),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Incident site'),
                  subtitle: Text(
                    report.latitude == null || report.longitude == null
                        ? 'No coordinates recorded'
                        : '${report.latitude!.toStringAsFixed(6)}, '
                              '${report.longitude!.toStringAsFixed(6)}\n'
                              '${report.parkOrBlock}',
                  ),
                  isThreeLine: true,
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Record response',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Record what you found or did. A manager reviews '
                        'resolved incidents before closing them.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notes,
                        maxLength: 1000,
                        maxLines: 5,
                        enabled: !_readOnly && !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Response notes',
                          hintText: 'Investigation findings and actions taken…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _readOnly || _saving
                                  ? null
                                  : () => _addEvidence(EvidenceSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Camera'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _readOnly || _saving
                                  ? null
                                  : () => _addEvidence(EvidenceSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Gallery'),
                            ),
                          ),
                        ],
                      ),
                      if (_evidence.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _evidence
                              .map(
                                (photo) => InputChip(
                                  avatar: Image.memory(
                                    base64Decode(photo.base64Data),
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.cover,
                                  ),
                                  label: Text(
                                    photo.fileName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onDeleted: _saving || _readOnly
                                      ? null
                                      : () => setState(
                                          () => _evidence.remove(photo),
                                        ),
                                ),
                              )
                              .toList(),
                        ),
                      if (_evidence.isEmpty)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Response photos are optional · up to 3'),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _readOnly || _saving
                            ? null
                            : () => _saveUpdate(
                                IncidentWorkflowStatus.responseInProgress,
                              ),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save progress update'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _readOnly || _saving
                            ? null
                            : () =>
                                  _saveUpdate(IncidentWorkflowStatus.resolved),
                        icon: const Icon(Icons.task_alt),
                        label: const Text(
                          'Submit resolution for manager review',
                        ),
                      ),
                      if (_readOnly)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Your response is saved. This incident is awaiting manager action.',
                          ),
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
              Text(
                'Incident history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_history.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.history),
                    title: Text('No response updates recorded yet'),
                  ),
                )
              else
                ..._history.map(
                  (event) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(event.message),
                      subtitle: Text(
                        '${event.actorName} · ${event.createdAt.toLocal()}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
