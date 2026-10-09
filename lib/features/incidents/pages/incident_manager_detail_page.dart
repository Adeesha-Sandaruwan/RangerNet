// Shows incident details and lets a manager review, assign, and close it.
import 'dart:convert';

// Lets a manager inspect an incident, assign responders, and close it later.
import 'package:flutter/material.dart';

import '../models/incident_report.dart';
import '../models/incident_timeline_event.dart';
import '../models/ranger_profile.dart';
import '../repositories/incident_management_ports.dart';
import '../widgets/incident_status_badges.dart';

/// Shows an incident's evidence, review actions, assignments, and history.
class IncidentManagerDetailPage extends StatefulWidget {
  const IncidentManagerDetailPage({
    required this.report,
    required this.manager,
    required this.repository,
    super.key,
  });

  final IncidentReport report;
  final RangerProfile manager;
  final IncidentManagerGateway repository;

  @override
  State<IncidentManagerDetailPage> createState() =>
      _IncidentManagerDetailPageState();
}

class _IncidentManagerDetailPageState extends State<IncidentManagerDetailPage> {
  final _note = TextEditingController();
  late IncidentReport _report;
  late Future<List<IncidentEvidence>> _evidenceFuture;
  List<IncidentTimelineEvent> _events = const [];
  bool _saving = false;
  String? _error;

  @override
  // Start loading the incident's photos and action history.
  void initState() {
    super.initState();
    _report = widget.report;
    _evidenceFuture = widget.repository.loadIncidentEvidence(_report.id);
    _loadTimeline();
  }

  @override
  // Release the manager note field when leaving the screen.
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  // Refresh the ordered list of actions recorded for this incident.
  Future<void> _loadTimeline() async {
    try {
      final events = await widget.repository.loadTimeline(_report.id);
      if (mounted) setState(() => _events = events);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not load history: $error');
    }
  }

  // Reload current incident data, photos, and history from Firestore.
  Future<void> _refreshIncident() async {
    try {
      final report = await widget.repository.loadIncident(_report.id);
      if (mounted) {
        setState(() {
          _report = report;
          _evidenceFuture = widget.repository.loadIncidentEvidence(_report.id);
        });
      }
      await _loadTimeline();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not refresh incident: $error');
      }
    }
  }

  // Ask for a reason, then save a status change or urgent escalation.
  Future<void> _managerAction(
    IncidentWorkflowStatus status, {
    IncidentSeverity? severity,
  }) async {
    final reason = TextEditingController();
    final isEscalation = severity == IncidentSeverity.critical;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEscalation
              ? 'Escalate to critical'
              : 'Set ${status.label.toLowerCase()}',
        ),
        content: TextField(
          controller: reason,
          autofocus: true,
          maxLength: 500,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: isEscalation
                ? 'Urgent risk and reason'
                : 'Reason / outcome',
            hintText: 'Record why this action is needed…',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reason.text.trim()),
            child: const Text('Save action'),
          ),
        ],
      ),
    );
    reason.dispose();
    if (result == null || !mounted) return;
    if (result.isEmpty) {
      setState(() => _error = 'Enter a reason before saving this action.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.managerTransition(
        incidentId: _report.id,
        status: status,
        managerName: widget.manager.displayName,
        note: result,
        severity: severity,
      );
      if (!mounted) return;
      setState(() {
        _report = _report.copyWith(workflowStatus: status, severity: severity);
      });
      await _loadTimeline();
      _showMessage(
        isEscalation ? 'Incident escalated to critical.' : 'Incident updated.',
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'Action was not saved: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Save the manager's review note and severity.
  Future<void> _saveReview() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.reviewIncident(
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

  // Let the manager choose one ranger or a response team for the incident.
  Future<void> _assignResponders() async {
    List<RangerProfile> candidates;
    try {
      candidates = await widget.repository.loadActiveRangers();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not load ranger list: $error');
      }
      return;
    }
    if (!mounted) return;
    if (candidates.isEmpty) {
      setState(
        () => _error = 'No active ranger accounts are available to assign.',
      );
      return;
    }

    var kind = _report.assignmentKind;
    final selected = <String>{..._report.assignedRangerIds};
    if (kind == IncidentAssignmentKind.ranger && selected.length > 1) {
      selected.remove(selected.last);
    }
    final result =
        await showDialog<
          ({IncidentAssignmentKind kind, List<RangerProfile> responders})
        >(
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
                    Text(
                      kind == IncidentAssignmentKind.ranger
                          ? 'Choose one ranger.'
                          : 'Choose at least two rangers for the response team.',
                    ),
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
                  onPressed:
                      selected.length <
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
      await widget.repository.assignResponders(
        incidentId: _report.id,
        kind: result.kind,
        responders: result.responders,
        managerName: widget.manager.displayName,
      );
      if (!mounted) return;
      final names = result.responders
          .map(
            (item) => item.displayName.isEmpty ? item.email : item.displayName,
          )
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
  // Build the incident review screen and show actions allowed for its status.
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F8F3),
    appBar: AppBar(
      title: const Text('Review incident'),
      actions: [
        IconButton(
          tooltip: 'Refresh incident and history',
          onPressed: _saving ? null : _refreshIncident,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _reportCard(),
            _evidenceCard(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Review and priority',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<IncidentSeverity>(
                      initialValue: _report.severity,
                      decoration: const InputDecoration(
                        labelText: 'Severity',
                        border: OutlineInputBorder(),
                      ),
                      items: IncidentSeverity.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.label),
                            ),
                          )
                          .toList(),
                      onChanged:
                          _saving ||
                              _report.workflowStatus ==
                                  IncidentWorkflowStatus.closed
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(
                                  () => _report = _report.copyWith(
                                    severity: value,
                                  ),
                                );
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
                      onPressed:
                          _saving ||
                              _report.workflowStatus ==
                                  IncidentWorkflowStatus.closed
                          ? null
                          : _saveReview,
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
                    Text(
                      'Incident actions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Record a reason for escalation, monitoring, follow-up, '
                      'rejection, or closure. Closing requires a responder to '
                      'submit a resolution first.',
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed:
                          _saving ||
                              _report.workflowStatus ==
                                  IncidentWorkflowStatus.closed ||
                              _report.severity == IncidentSeverity.critical
                          ? null
                          : () => _managerAction(
                              IncidentWorkflowStatus.underReview,
                              severity: IncidentSeverity.critical,
                            ),
                      icon: const Icon(Icons.priority_high),
                      label: const Text('Escalate to critical'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _saving ||
                              _report.workflowStatus ==
                                  IncidentWorkflowStatus.closed
                          ? null
                          : () => _managerAction(
                              IncidentWorkflowStatus.followUpRequired,
                            ),
                      icon: const Icon(Icons.event_repeat),
                      label: const Text('Require follow-up'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _saving ||
                              _report.workflowStatus ==
                                  IncidentWorkflowStatus.closed
                          ? null
                          : () => _managerAction(
                              IncidentWorkflowStatus.monitoring,
                            ),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Keep under monitoring'),
                    ),
                    if (_report.workflowStatus ==
                        IncidentWorkflowStatus.resolved)
                      FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () =>
                                  _managerAction(IncidentWorkflowStatus.closed),
                        icon: const Icon(Icons.task_alt),
                        label: const Text('Confirm resolution and close'),
                      )
                    else
                      const ListTile(
                        leading: Icon(Icons.hourglass_empty),
                        title: Text('Awaiting responder resolution'),
                        subtitle: Text(
                          'The manager can close after a responder submits a resolved update.',
                        ),
                      ),
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed:
                              _saving ||
                                  _report.workflowStatus ==
                                      IncidentWorkflowStatus.closed
                              ? null
                              : () => _managerAction(
                                  IncidentWorkflowStatus.duplicate,
                                ),
                          child: const Text('Mark duplicate'),
                        ),
                        TextButton(
                          onPressed:
                              _saving ||
                                  _report.workflowStatus ==
                                      IncidentWorkflowStatus.closed
                              ? null
                              : () => _managerAction(
                                  IncidentWorkflowStatus.rejected,
                                ),
                          child: const Text('Reject as invalid'),
                        ),
                      ],
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
                    Text(
                      'Response assignment',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _report.assignedRangerNames.isEmpty
                          ? 'No ranger or response team assigned.'
                          : '${_report.assignmentKind == IncidentAssignmentKind.ranger ? 'Ranger' : 'Response team'}: '
                                '${_report.assignedRangerNames.join(', ')}',
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed:
                          _saving ||
                              _report.workflowStatus ==
                                  IncidentWorkflowStatus.closed
                          ? null
                          : _assignResponders,
                      icon: const Icon(Icons.assignment_ind_outlined),
                      label: Text(
                        _report.assignedRangerIds.isEmpty
                            ? 'Assign ranger or response team'
                            : 'Reassign response',
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

  // Show the submitted description, reporter, place, and other report details.
  Widget _reportCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_report.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          IncidentStatusBadges(
            severity: _report.severity,
            status: _report.workflowStatus,
          ),
          const Divider(height: 24),
          _reportField('Incident type', _report.type.label),
          _reportField(
            'Reporter',
            _report.rangerEmail.isEmpty
                ? _report.rangerId
                : _report.rangerEmail,
          ),
          _reportField('Reported at', _date(_report.createdAt)),
          _reportField('Active threat', _report.activeThreat ? 'Yes' : 'No'),
          _reportField('Park / block', _report.parkOrBlock),
          _reportField(
            'Location',
            _report.latitude == null || _report.longitude == null
                ? 'No coordinates recorded'
                : '${_report.latitude!.toStringAsFixed(6)}, '
                      '${_report.longitude!.toStringAsFixed(6)}',
          ),
          _reportField(
            'Location source',
            _report.manualLocation ? 'Entered manually' : 'GPS',
          ),
          if (_report.locationAccuracyMeters != null)
            _reportField(
              'GPS accuracy',
              '±${_report.locationAccuracyMeters!.toStringAsFixed(0)} m',
            ),
          _reportField(
            'Patrol ID',
            _report.patrolId?.isNotEmpty == true ? _report.patrolId! : 'None',
          ),
          const SizedBox(height: 10),
          Text(
            'Reporter description',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          SelectableText(
            _report.description.isEmpty
                ? 'No description provided.'
                : _report.description,
          ),
        ],
      ),
    ),
  );

  // Display one labelled field in the manager's incident summary.
  Widget _reportField(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(child: SelectableText(value.isEmpty ? 'Not provided' : value)),
      ],
    ),
  );

  // Load and display the photos attached to the report.
  Widget _evidenceCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reporter evidence',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<IncidentEvidence>>(
            future: _evidenceFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_off_outlined),
                  title: const Text('Could not load evidence photos'),
                  subtitle: Text(snapshot.error.toString()),
                  trailing: IconButton(
                    tooltip: 'Retry loading photos',
                    onPressed: () => setState(() {
                      _evidenceFuture = widget.repository.loadIncidentEvidence(
                        _report.id,
                      );
                    }),
                    icon: const Icon(Icons.refresh),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final photos = snapshot.data!;
              if (photos.isEmpty) {
                return const Text('No photos were attached to this report.');
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: photos.map(_evidenceTile).toList(growable: false),
              );
            },
          ),
        ],
      ),
    ),
  );

  // Show a photo thumbnail and open it for a larger view.
  Widget _evidenceTile(IncidentEvidence photo) {
    final bytes = base64Decode(photo.base64Data);
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.memory(bytes, fit: BoxFit.contain),
                const SizedBox(height: 8),
                Text(photo.fileName),
              ],
            ),
          ),
        ),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              bytes,
              width: 112,
              height: 112,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 112,
            child: Text(
              photo.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Format the saved time using the device's local time zone.
  String _date(DateTime value) => value.toLocal().toString().substring(0, 16);

  // Show one dated manager or responder action from the history.
  Widget _eventCard(IncidentTimelineEvent event) => Card(
    child: ListTile(
      leading: const Icon(Icons.history),
      title: Text(event.message),
      subtitle: Text('${event.actorName} · ${event.createdAt.toLocal()}'),
    ),
  );

  // Show a short confirmation after an action succeeds.
  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
