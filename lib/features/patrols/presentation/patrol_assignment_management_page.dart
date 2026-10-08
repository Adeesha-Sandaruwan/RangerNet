import 'package:flutter/material.dart';

import '../application/patrol_assignment_service.dart';
import '../application/patrol_metrics_service.dart';
import '../application/patrol_review_service.dart';
import '../domain/patrol_assignment.dart';
import '../domain/patrol_records.dart';
import '../../incidents/domain/ranger_profile.dart';
import 'completed_patrol_reviews_page.dart';
import 'patrol_route_builder_page.dart';
import 'patrol_route_map.dart';

class PatrolAssignmentManagementPage extends StatefulWidget {
  const PatrolAssignmentManagementPage({
    required this.service,
    required this.reviewService,
    required this.manager,
    super.key,
  });

  final PatrolAssignmentService service;
  final PatrolReviewService reviewService;
  final RangerProfile manager;

  @override
  State<PatrolAssignmentManagementPage> createState() =>
      _PatrolAssignmentManagementPageState();
}

class _PatrolAssignmentManagementPageState
    extends State<PatrolAssignmentManagementPage> {
  List<PatrolAssignment> _assignments = const [];
  bool _loading = true;
  String? _error;

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
      final assignments = await widget.service.loadAssignments();
      if (mounted) setState(() => _assignments = assignments);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAssignment() async {
    final assignment = await Navigator.of(context).push<PatrolAssignment>(
      MaterialPageRoute<PatrolAssignment>(
        builder: (_) => _CreatePatrolAssignmentPage(service: widget.service),
      ),
    );
    if (assignment != null && mounted) {
      setState(() => _assignments = [assignment, ..._assignments]);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F8F3),
    appBar: AppBar(
      title: const Text('Patrol assignments'),
      backgroundColor: const Color(0xFFF5F8F3),
      actions: [
        IconButton(
          tooltip: 'Review completed patrols',
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => CompletedPatrolReviewsPage(
                service: widget.reviewService,
                manager: widget.manager,
              ),
            ),
          ),
          icon: const Icon(Icons.rate_review_outlined),
        ),
        IconButton(
          tooltip: 'Refresh assignments',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _createAssignment,
      icon: const Icon(Icons.add),
      label: const Text('Assign patrol'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(
                'Assignments for rangers',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose an active ranger and define the park, zone, and route. '
                'The patrol will appear in that ranger’s Patrols list.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => CompletedPatrolReviewsPage(
                      service: widget.reviewService,
                      manager: widget.manager,
                    ),
                  ),
                ),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Review completed patrols'),
              ),
              const SizedBox(height: 4),
              Card(
                color: const Color(0xFFEAF2EC),
                child: const ListTile(
                  leading: Icon(Icons.route_outlined),
                  title: Text('Manager-assigned route'),
                  subtitle: Text(
                    'Set the route start, optional stops, and destination on '
                    'the map. Rangers see this plan alongside their recorded '
                    'GPS track.',
                  ),
                ),
              ),
              if (_error != null)
                Card(
                  color: const Color(0xFFFFE9E5),
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('Assignments could not be loaded'),
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
              else if (_assignments.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.route_outlined),
                    title: Text('No patrol assignments yet'),
                    subtitle: Text(
                      'Create an assignment to make a patrol available to a ranger.',
                    ),
                  ),
                )
              else
                ..._assignments.map(
                  (assignment) => Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFEAF2EC),
                                child: Icon(
                                  Icons.route,
                                  color: Color(0xFF17613F),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      assignment.area.routeName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      '${assignment.area.parkName} · '
                                      '${assignment.area.zoneName}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const Chip(
                                avatar: Icon(Icons.check_circle_outline, size: 16),
                                label: Text('Assigned'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          if (assignment.plannedRoute case final route?) ...[
                            const SizedBox(height: 12),
                            PatrolRouteMap(
                              plannedRoute: route,
                              height: 190,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${route.start.name} → ${route.end.name}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              '${route.stops.length} optional stop(s) · '
                              '${route.coverageSections.length} coverage sections · '
                              '${_formatRouteDistance(_plannedRouteDistanceMeters(route))} planned',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  assignment.rangerName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                assignment.assignedAt
                                    .toLocal()
                                    .toString()
                                    .substring(0, 16),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

}

class _CreatePatrolAssignmentPage extends StatefulWidget {
  const _CreatePatrolAssignmentPage({required this.service});

  final PatrolAssignmentService service;

  @override
  State<_CreatePatrolAssignmentPage> createState() =>
      _CreatePatrolAssignmentPageState();
}

class _CreatePatrolAssignmentPageState
    extends State<_CreatePatrolAssignmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _parkName = TextEditingController();
  final _zoneName = TextEditingController();
  final _routeName = TextEditingController();
  final _parkId = TextEditingController();
  final _zoneId = TextEditingController();
  final _routeId = TextEditingController();
  PatrolRoutePlan? _plannedRoute;
  List<PatrolRanger> _rangers = const [];
  PatrolRanger? _selectedRanger;
  bool _loadingRangers = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRangers();
  }

  @override
  void dispose() {
    _parkName.dispose();
    _zoneName.dispose();
    _routeName.dispose();
    _parkId.dispose();
    _zoneId.dispose();
    _routeId.dispose();
    super.dispose();
  }

  Future<void> _loadRangers() async {
    setState(() {
      _loadingRangers = true;
      _error = null;
    });
    try {
      final rangers = await widget.service.loadActiveRangers();
      if (mounted) {
        setState(() {
          _rangers = rangers;
          _selectedRanger = rangers.isEmpty ? null : rangers.first;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not load rangers: $error');
    } finally {
      if (mounted) setState(() => _loadingRangers = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final ranger = _selectedRanger;
    if (ranger == null) {
      setState(() => _error = 'Select an active ranger before assigning.');
      return;
    }
    final plannedRoute = _plannedRoute;
    if (plannedRoute == null) {
      setState(
        () => _error = 'Select a route start and destination on the map.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final assignment = await widget.service.createAssignment(
        PatrolAssignmentDraft(
          ranger: ranger,
          parkName: _parkName.text,
          zoneName: _zoneName.text,
          routeName: _routeName.text,
          parkId: _parkId.text,
          zoneId: _zoneId.text,
          routeId: _routeId.text,
          plannedRoute: plannedRoute,
        ),
      );
      if (mounted) Navigator.of(context).pop(assignment);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Patrol assignment was not saved: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F8F3),
    appBar: AppBar(
      title: const Text('Assign a patrol'),
      backgroundColor: const Color(0xFFF5F8F3),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '1. Select ranger',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Choose who will receive this patrol assignment.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (_loadingRangers)
                const LinearProgressIndicator()
              else if (_rangers.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_search_outlined),
                    title: const Text('No active ranger accounts found'),
                    subtitle: const Text(
                      'Rangers must create an account and be active before '
                      'a patrol can be assigned.',
                    ),
                    trailing: IconButton(
                      tooltip: 'Retry loading rangers',
                      onPressed: _loadRangers,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                )
              else
                DropdownButtonFormField<PatrolRanger>(
                  initialValue: _selectedRanger,
                  decoration: const InputDecoration(
                    labelText: 'Active ranger',
                    border: OutlineInputBorder(),
                  ),
                  items: _rangers
                      .map(
                        (ranger) => DropdownMenuItem(
                          value: ranger,
                          child: Text(
                            ranger.name.isEmpty
                                ? ranger.email
                                : '${ranger.name} · ${ranger.email}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (ranger) => setState(() => _selectedRanger = ranger),
                  validator: (ranger) =>
                      ranger == null ? 'Select a ranger.' : null,
                ),
              const SizedBox(height: 24),
              Text(
                '2. Define patrol area',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Use names that help the ranger identify the place and route.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              _requiredField(_parkName, 'Park name'),
              const SizedBox(height: 12),
              _optionalField(_parkId, 'Park ID (optional)'),
              const SizedBox(height: 12),
              _requiredField(_zoneName, 'Zone name'),
              const SizedBox(height: 12),
              _optionalField(_zoneId, 'Zone ID (optional)'),
              const SizedBox(height: 12),
              _requiredField(_routeName, 'Patrol route name'),
              const SizedBox(height: 12),
              _optionalField(_routeId, 'Route ID (optional)'),
              const SizedBox(height: 24),
              Text(
                '3. Build route on map',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose the start and destination by tapping the map. Add '
                'optional stops in the order the ranger should visit them. '
                'The preview connects selected locations with straight map '
                'segments. Confirm the path follows accessible tracks; '
                'coverage sections are generated from those map selections.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _buildRoute,
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  _plannedRoute == null
                      ? 'Select route on map'
                      : 'Edit route on map',
                ),
              ),
              if (_plannedRoute case final route?) ...[
                const SizedBox(height: 12),
                PatrolRouteMap(plannedRoute: route, height: 240),
                const SizedBox(height: 6),
                Text(
                  'Route generated · ${_formatRouteDistance(_plannedRouteDistanceMeters(route))} '
                  'planned · ${route.stops.length} optional stop(s) · '
                  '${route.coverageSections.length} coverage sections. '
                  'The route is saved with the assignment.',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFFFFE9E5),
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(_error!),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving || _loadingRangers || _rangers.isEmpty
                    ? null
                    : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.assignment_turned_in_outlined),
                label: const Text('Save route and assign patrol'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _requiredField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? '$label is required.'
            : null,
      );

  Widget _optionalField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );

  Future<void> _buildRoute() async {
    final route = await Navigator.of(context).push<PatrolRoutePlan>(
      MaterialPageRoute<PatrolRoutePlan>(
        builder: (_) => PatrolRouteBuilderPage(initialRoute: _plannedRoute),
      ),
    );
    if (route != null && mounted) setState(() => _plannedRoute = route);
  }
}

double _plannedRouteDistanceMeters(PatrolRoutePlan route) {
  const metrics = PatrolMetricsService();
  final points = route.routeLocations;
  var distance = 0.0;
  for (var index = 1; index < points.length; index++) {
    distance += metrics.distanceBetween(
      PatrolLocation(
        latitude: points[index - 1].latitude,
        longitude: points[index - 1].longitude,
        recordedAt: DateTime.utc(2026),
        source: PatrolLocationSource.manual,
      ),
      PatrolLocation(
        latitude: points[index].latitude,
        longitude: points[index].longitude,
        recordedAt: DateTime.utc(2026),
        source: PatrolLocationSource.manual,
      ),
    );
  }
  return distance;
}

String _formatRouteDistance(double meters) => meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(2)} km'
    : '${meters.toStringAsFixed(0)} m';
