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

  Future<void> _assignResponders() async {
    List<RangerProfile> candidates;
    try {
      candidates = await _repository.loadActiveRangers();
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not load ranger list: $error');
      return;
    }
    if (!mounted) return;
    if (candidates.isEmpty) {
      setState(() => _error = 'No active ranger accounts are available to assign.');
      return;
    }

    var kind = _report.assignmentKind;
    final selected = <String>{..._report.assignedRangerIds};
    if (kind == IncidentAssignmentKind.ranger && selected.length > 1) {
      selected.remove(selected.last);
    }
    final result = await showDialog<({
      IncidentAssignmentKind kind,
      List<RangerProfile> responders,
    })>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Assign response'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<IncidentAssignmentKind>(
                  segments: const [
                    ButtonSegment(
                      value: IncidentAssignmentKind.ranger,
                      label: Text('One ranger'),
                      icon: Icon(Icons.person_outline),
                    ),
                    ButtonSegment(
                      value: IncidentAssignmentKind.responseTeam,
                      label: Text('Response team'),
                      icon: Icon(Icons.groups_outlined),
                    ),
                  ],
                  selected: {kind},
                  onSelectionChanged: (value) => updateDialog(() {
                    kind = value.first;
                    if (kind == IncidentAssignmentKind.ranger &&
                        selected.length > 1) {
                      selected.removeAll(selected.skip(1).toList());
                    }
                  }),
                ),
                const SizedBox(height: 8),
                Text(kind == IncidentAssignmentKind.ranger
                    ? 'Choose one ranger.'
                    : 'Choose at least two rangers for the response team.'),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: candidates.map((ranger) {
                      final name = ranger.displayName.isEmpty
                          ? ranger.email
                          : ranger.displayName;
                      return CheckboxListTile(
                        value: selected.contains(ranger.uid),
                        title: Text(name),
                        subtitle: ranger.email.isEmpty
                            ? null
                            : Text(ranger.email),
                        onChanged: (checked) => updateDialog(() {
                          if (checked == true) {
                            if (kind == IncidentAssignmentKind.ranger) {
                              selected
                                ..clear()
                                ..add(ranger.uid);
                            } else {
                              selected.add(ranger.uid);
                            }
                          } else {
                            selected.remove(ranger.uid);
                          }
                        }),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.length <
                      (kind == IncidentAssignmentKind.ranger ? 1 : 2)
                  ? null
                  : () => Navigator.pop(dialogContext, (
                      kind: kind,
                      responders: candidates
                          .where((item) => selected.contains(item.uid))
                          .toList(growable: false),
                    )),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository.assignResponders(
        incidentId: _report.id,
        kind: result.kind,
        responders: result.responders,
        managerName: widget.manager.displayName,
      );
      if (!mounted) return;
      final names = result.responders
          .map((item) => item.displayName.isEmpty ? item.email : item.displayName)
          .toList(growable: false);
      setState(() {
        _report = _report.copyWith(
          workflowStatus: IncidentWorkflowStatus.assigned,
          assignmentKind: result.kind,
          assignedRangerIds: result.responders.map((item) => item.uid).toList(),
          assignedRangerNames: names,
        );
      });
      await _loadTimeline();
      _showMessage('Response assignment saved.');
    } catch (error) {
      if (mounted) setState(() => _error = 'Assignment was not saved: $error');
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Response assignment',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(_report.assignedRangerNames.isEmpty
                        ? 'No ranger or response team assigned.'
                        : '${_report.assignmentKind == IncidentAssignmentKind.ranger ? 'Ranger' : 'Response team'}: '
                            '${_report.assignedRangerNames.join(', ')}'),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _assignResponders,
                      icon: const Icon(Icons.assignment_ind_outlined),
                      label: Text(_report.assignedRangerIds.isEmpty
                          ? 'Assign ranger or response team'
                          : 'Reassign response'),
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
