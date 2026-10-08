import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../application/patrol_metrics_service.dart';
import '../application/patrol_review_service.dart';
import '../domain/patrol.dart';
import '../domain/patrol_records.dart';
import '../domain/patrol_review.dart';
import '../../incidents/domain/ranger_profile.dart';
import 'patrol_route_map.dart';

enum _ReviewFilter { all, pending, reviewed, followUp }

class CompletedPatrolReviewsPage extends StatefulWidget {
  const CompletedPatrolReviewsPage({
    required this.service,
    required this.manager,
    super.key,
  });

  final PatrolReviewService service;
  final RangerProfile manager;

  @override
  State<CompletedPatrolReviewsPage> createState() =>
      _CompletedPatrolReviewsPageState();
}

class _CompletedPatrolReviewsPageState
    extends State<CompletedPatrolReviewsPage> {
  List<PatrolReviewRecord> _records = const [];
  bool _loading = true;
  String? _error;
  _ReviewFilter _filter = _ReviewFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await widget.service.loadCompletedPatrols();
      if (mounted) setState(() => _records = records);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PatrolReviewRecord> get _filteredRecords => _records
      .where((record) {
        return switch (_filter) {
          _ReviewFilter.all => true,
          _ReviewFilter.pending =>
            record.reviewStatus == PatrolManagerReviewStatus.pending,
          _ReviewFilter.reviewed => record.isReviewed,
          _ReviewFilter.followUp => record.followUpRequired,
        };
      })
      .toList(growable: false);

  Future<void> _openReview(PatrolReviewRecord record) async {
    final updated = await Navigator.of(context).push<PatrolReviewRecord>(
      MaterialPageRoute<PatrolReviewRecord>(
        builder: (_) => _CompletedPatrolReviewDetailPage(
          record: record,
          service: widget.service,
          manager: widget.manager,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _records = [
          for (final existing in _records)
            if (existing.patrol.patrolId == updated.patrol.patrolId)
              updated
            else
              existing,
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F8F3),
    appBar: AppBar(
      title: const Text('Completed patrol reviews'),
      backgroundColor: const Color(0xFFF5F8F3),
      actions: [
        IconButton(
          tooltip: 'Refresh completed patrols',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                'Review completed patrols',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Compare each assigned route with the ranger’s recorded track, '
                'check the patrol details, and record review notes or follow-up.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _filterChip('All', _ReviewFilter.all),
                  _filterChip('Needs review', _ReviewFilter.pending),
                  _filterChip('Reviewed', _ReviewFilter.reviewed),
                  _filterChip('Follow-up', _ReviewFilter.followUp),
                ],
              ),
              const SizedBox(height: 8),
              if (_error != null)
                Card(
                  color: const Color(0xFFFFE9E5),
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('Completed patrols could not be loaded'),
                    subtitle: Text(_error!),
                    trailing: IconButton(
                      tooltip: 'Retry',
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
              else if (_error == null && _filteredRecords.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.fact_check_outlined),
                    title: Text(
                      _records.isEmpty
                          ? 'No synchronized completed patrols'
                          : 'No patrols match this filter',
                    ),
                    subtitle: Text(
                      _records.isEmpty
                          ? 'Completed patrols appear here after their offline '
                                'records synchronize.'
                          : 'Choose another review filter to see more patrols.',
                    ),
                  ),
                )
              else
                ..._filteredRecords.map(
                  (record) => _CompletedPatrolReviewCard(
                    record: record,
                    onTap: () => _openReview(record),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _filterChip(String label, _ReviewFilter value) => FilterChip(
    label: Text(label),
    selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
  );
}

class _CompletedPatrolReviewCard extends StatelessWidget {
  const _CompletedPatrolReviewCard({required this.record, required this.onTap});

  final PatrolReviewRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final patrol = record.patrol;
    const metrics = PatrolMetricsService();
    final statusText = record.followUpRequired
        ? 'Follow-up required'
        : record.isReviewed
        ? 'Reviewed'
        : 'Needs review';
    final statusColor = record.followUpRequired
        ? Colors.deepOrange
        : record.isReviewed
        ? const Color(0xFF17613F)
        : Colors.blueGrey;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFEAF2EC),
                    child: Icon(Icons.route, color: Color(0xFF17613F)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patrol.area.routeName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${patrol.area.parkName} · ${patrol.area.zoneName}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(statusText),
                    labelStyle: TextStyle(color: statusColor),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _SummaryValue(
                    icon: Icons.person_outline,
                    text: patrol.rangerName,
                  ),
                  _SummaryValue(
                    icon: Icons.event_outlined,
                    text: _formatDate(patrol.endedAt),
                  ),
                  _SummaryValue(
                    icon: Icons.straighten,
                    text:
                        '${_formatDistance(metrics.distanceTravelledMeters(patrol))} actual',
                  ),
                ],
              ),
              if (record.managerNotes?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  record.managerNotes!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const Align(
                alignment: Alignment.centerRight,
                child: Text('Open review  →'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedPatrolReviewDetailPage extends StatefulWidget {
  const _CompletedPatrolReviewDetailPage({
    required this.record,
    required this.service,
    required this.manager,
  });

  final PatrolReviewRecord record;
  final PatrolReviewService service;
  final RangerProfile manager;

  @override
  State<_CompletedPatrolReviewDetailPage> createState() =>
      _CompletedPatrolReviewDetailPageState();
}

class _CompletedPatrolReviewDetailPageState
    extends State<_CompletedPatrolReviewDetailPage> {
  static const _metrics = PatrolMetricsService();
  late final TextEditingController _notesController = TextEditingController(
    text: widget.record.managerNotes ?? '',
  );
  bool _followUpRequired = false;
  bool _saving = false;
  String? _error;

  Patrol get _patrol => widget.record.patrol;

  @override
  void initState() {
    super.initState();
    _followUpRequired = widget.record.followUpRequired;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveReview({required bool flagOnly}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final record = flagOnly
          ? await widget.service.flagFollowUp(
              patrolId: _patrol.patrolId,
              managerId: widget.manager.uid,
              notes: _notesController.text,
            )
          : await widget.service.saveReview(
              patrolId: _patrol.patrolId,
              managerId: widget.manager.uid,
              notes: _notesController.text,
              followUpRequired: _followUpRequired,
            );
      if (mounted) Navigator.of(context).pop(record);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plannedDistance = _patrol.plannedRoute == null
        ? null
        : _metrics.plannedRouteDistanceMeters(_patrol.plannedRoute!);
    final actualDistance = _metrics.distanceTravelledMeters(_patrol);
    final duration = _metrics.durationAt(
      _patrol,
      _patrol.endedAt ?? DateTime.now(),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F3),
      appBar: AppBar(
        title: const Text('Patrol review'),
        backgroundColor: const Color(0xFFF5F8F3),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                _patrol.area.routeName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '${_patrol.area.parkName} · ${_patrol.area.zoneName}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              PatrolRouteMap(patrol: _patrol, height: 300),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    _LegendItem(
                      color: Color(0xFF17613F),
                      label: 'Assigned route',
                    ),
                    _LegendItem(
                      color: Color(0xFF2673B8),
                      label: 'Recorded route',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _DetailCard(
                title: 'Assigned vs actual',
                icon: Icons.compare_arrows,
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Assigned route distance',
                      value: plannedDistance == null
                          ? 'Not available'
                          : '${_formatDistance(plannedDistance)}*',
                    ),
                    _DetailRow(
                      label: 'Recorded distance',
                      value: '${_formatDistance(actualDistance)}*',
                    ),
                    _DetailRow(
                      label: 'Difference',
                      value: plannedDistance == null
                          ? 'Not available'
                          : '${_formatDistance((actualDistance - plannedDistance).abs())} '
                                '${actualDistance >= plannedDistance ? 'over' : 'under'}',
                    ),
                    _DetailRow(
                      label: 'Active duration',
                      value: _formatDuration(duration),
                    ),
                    _DetailRow(
                      label: 'Synchronization',
                      value:
                          'Synced · ${_formatDate(_patrol.syncInfo.lastSyncedAt)}',
                    ),
                    _DetailRow(label: 'Ranger', value: _patrol.rangerName),
                    _DetailRow(
                      label: 'Started',
                      value: _formatDate(_patrol.startedAt),
                    ),
                    _DetailRow(
                      label: 'Completed',
                      value: _formatDate(_patrol.endedAt),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '* Distances are straight-line estimates between recorded '
                      'points, not road or trail routing.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              _DetailCard(
                title: 'Review checklist',
                icon: Icons.fact_check_outlined,
                child: Column(
                  children: [
                    _ChecklistItem(
                      label: 'Patrol synchronized and completed',
                      complete: _patrol.status == PatrolStatus.completedSynced,
                    ),
                    _ChecklistItem(
                      label: 'Assigned route is available',
                      complete: _patrol.plannedRoute != null,
                    ),
                    _ChecklistItem(
                      label: 'Recorded route or manual waypoints available',
                      complete:
                          _patrol.startLocation != null &&
                          _metrics.actualRouteLocations(_patrol).length > 1,
                    ),
                    _ChecklistItem(
                      label: 'Patrol coverage calculated',
                      complete: _patrol.coverage != null,
                    ),
                    _ChecklistItem(
                      label: 'End location recorded',
                      complete: _patrol.endLocation != null,
                    ),
                    if (_patrol.coverage case final coverage?) ...[
                      const Divider(),
                      _DetailRow(
                        label: 'Coverage',
                        value:
                            '${coverage.coveredSections}/${coverage.totalSections} sections',
                      ),
                      if (coverage.uncoveredSectionIds.isNotEmpty)
                        _DetailRow(
                          label: 'Uncovered sections',
                          value: coverage.uncoveredSectionIds.join(', '),
                        ),
                    ],
                  ],
                ),
              ),
              _DetailCard(
                title: 'Recorded details',
                icon: Icons.list_alt,
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'GPS route points',
                      value: '${_patrol.routePoints.length}',
                    ),
                    _DetailRow(
                      label: 'Average GPS accuracy',
                      value: _averageGpsAccuracy(_patrol.routePoints),
                    ),
                    _DetailRow(
                      label: 'Assigned',
                      value: _formatDate(_patrol.assignedAt),
                    ),
                    _DetailRow(
                      label: 'Manual waypoints',
                      value: '${_patrol.manualWaypoints.length}',
                    ),
                    _DetailRow(
                      label: 'Observations',
                      value: '${_patrol.observations.length}',
                    ),
                    _DetailRow(
                      label: 'Photographs',
                      value: '${_patrol.photographs.length}',
                    ),
                    _DetailRow(
                      label: 'Pause/resume events',
                      value: '${_patrol.pauseResumeEvents.length}',
                    ),
                    _DetailRow(
                      label: 'Start location',
                      value: _formatLocation(_patrol.startLocation),
                    ),
                    _DetailRow(
                      label: 'End location',
                      value: _formatLocation(_patrol.endLocation),
                    ),
                    if (_patrol.earlyTerminationReason case final reason?)
                      _DetailRow(label: 'Termination reason', value: reason),
                  ],
                ),
              ),
              if (_patrol.manualWaypoints.isNotEmpty)
                _DetailCard(
                  title: 'Manual waypoints',
                  icon: Icons.add_location_alt_outlined,
                  child: Column(
                    children: _patrol.manualWaypoints
                        .map(
                          (waypoint) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.place_outlined),
                            title: Text(
                              waypoint.description.isEmpty
                                  ? 'Manual waypoint'
                                  : waypoint.description,
                            ),
                            subtitle: Text(_formatLocation(waypoint.location)),
                            trailing: Text(
                              _formatDate(waypoint.location.recordedAt),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              if (_patrol.observations.isNotEmpty)
                _DetailCard(
                  title: 'Observations recorded',
                  icon: Icons.visibility_outlined,
                  child: Column(
                    children: _patrol.observations
                        .map(
                          (observation) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.notes_outlined),
                            title: Text(observation.description),
                            subtitle: Text(
                              [
                                if (observation.category?.isNotEmpty == true)
                                  observation.category!,
                                _formatLocation(observation.location),
                              ].join(' · '),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              if (_patrol.photographs.isNotEmpty)
                _DetailCard(
                  title: 'Photographs',
                  icon: Icons.photo_library_outlined,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _patrol.photographs
                        .map((photo) => _PhotoCard(photo: photo))
                        .toList(growable: false),
                  ),
                ),
              if (_patrol.pauseResumeEvents.isNotEmpty)
                _DetailCard(
                  title: 'Pause and resume history',
                  icon: Icons.pause_circle_outline,
                  child: Column(
                    children: _patrol.pauseResumeEvents
                        .map(
                          (event) => _DetailRow(
                            label:
                                '${event.action.name == 'pause' ? 'Paused' : 'Resumed'}'
                                '${event.reason?.isNotEmpty == true ? ' · ${event.reason}' : ''}',
                            value: _formatDate(event.occurredAt),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              _DetailCard(
                title: 'Manager review',
                icon: Icons.rate_review_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Manager notes',
                        hintText:
                            'Record route issues, findings, or next steps',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _followUpRequired,
                      onChanged: _saving
                          ? null
                          : (value) => setState(
                              () => _followUpRequired = value ?? false,
                            ),
                      title: const Text('Flag this patrol for follow-up'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _saveReview(flagOnly: true),
                          icon: const Icon(Icons.flag_outlined),
                          label: const Text('Flag follow-up'),
                        ),
                        FilledButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _saveReview(flagOnly: false),
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _followUpRequired
                                ? 'Save review & flag'
                                : 'Mark reviewed',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.record.reviewedAt != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Last reviewed ${_formatDate(widget.record.reviewedAt)}'
                    '${widget.record.reviewedBy == null ? '' : ' by ${widget.record.reviewedBy}'}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF17613F)),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      complete ? Icons.check_circle : Icons.radio_button_unchecked,
      color: complete ? const Color(0xFF17613F) : Colors.blueGrey,
    ),
    title: Text(label),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 18, height: 4, color: color),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: Colors.black54),
      const SizedBox(width: 5),
      Text(text, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photo});

  final PatrolPhoto photo;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    String? decodeError;
    try {
      bytes = base64Decode(photo.base64Data);
    } on FormatException {
      decodeError = 'Image data unavailable';
    }
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                height: 110,
                width: 150,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => const SizedBox(
                  height: 110,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            )
          else
            const SizedBox(
              height: 110,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          const SizedBox(height: 4),
          Text(
            photo.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            decodeError ?? _formatDate(photo.capturedAt),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

String _formatDistance(double meters) => meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(2)} km'
    : '${meters.toStringAsFixed(0)} m';

String _formatDate(DateTime? date) =>
    date == null ? 'Not recorded' : date.toLocal().toString().substring(0, 16);

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
}

String _formatLocation(PatrolLocation? location) {
  if (location == null) return 'Not recorded';
  final source = location.source == PatrolLocationSource.manual
      ? 'Manual'
      : 'GPS';
  return '${location.latitude.toStringAsFixed(5)}, '
      '${location.longitude.toStringAsFixed(5)} · $source';
}

String _averageGpsAccuracy(List<PatrolRoutePoint> points) {
  final accuracies = points
      .map((point) => point.location.accuracyMeters)
      .whereType<double>()
      .toList(growable: false);
  if (accuracies.isEmpty) return 'Not recorded';
  final average =
      accuracies.reduce((total, accuracy) => total + accuracy) /
      accuracies.length;
  return '${average.toStringAsFixed(1)} m';
}
