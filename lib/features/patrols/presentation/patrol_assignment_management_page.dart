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

/// Manager-facing patrol assignment list and creation entry point.
/// DIP: assignment and review work is delegated to injected services.
/// The manager view uses a green gradient header and numbered _StepHeader form sections.
class PatrolAssignmentManagementPage extends StatefulWidget {
  const PatrolAssignmentManagementPage({
    required this.service,
    required this.reviewService,
    required this.manager,
    super.key,
  });

  /// Application boundary for loading and creating patrol assignments.
  final PatrolAssignmentService service;

  /// Supplies completed patrols and manager review operations.
  final PatrolReviewService reviewService;

  /// Manager identity used by review and assignment workflows.
  final RangerProfile manager;

  @override
  State<PatrolAssignmentManagementPage> createState() =>
      _PatrolAssignmentManagementPageState();
}

/// Loads and presents assignments for the manager; refreshes through its service.
class _PatrolAssignmentManagementPageState
    extends State<PatrolAssignmentManagementPage> {
  List<PatrolAssignment> _assignments = const [];
  bool _loading = true;
  String? _error;

  /// Initializes this manager page and begins its initial data load.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads assignments through the injected service and updates the view state.
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

  /// Opens the assignment form and adds a successfully created result.
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

  /// Builds the manager assignment view with its assignment workflow styling.
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF17613F), Color(0xFF2E8B5E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.assignment_ind_outlined,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Assignments for rangers',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose an active ranger and define the park, zone, and route. '
                      'The patrol will appear in that ranger’s Patrols list.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
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
                                avatar: Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                ),
                                label: Text('Assigned'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          if (assignment.plannedRoute case final route?) ...[
                            const SizedBox(height: 12),
                            PatrolRouteMap(plannedRoute: route, height: 190),
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
                                  style: Theme.of(context).textTheme.bodyMedium,
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

/// Collects manager-entered ranger, area, and planned-route assignment details.
/// DIP: submits assignment work through the injected assignment service.
class _CreatePatrolAssignmentPage extends StatefulWidget {
  const _CreatePatrolAssignmentPage({required this.service});

  /// Application boundary for loading and creating patrol assignments.
  final PatrolAssignmentService service;

  @override
  State<_CreatePatrolAssignmentPage> createState() =>
      _CreatePatrolAssignmentPageState();
}

/// Owns assignment form controllers and validation; disposes its controllers.
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

  /// Initializes this manager page and begins its initial data load.
  @override
  void initState() {
    super.initState();
    _loadRangers();
  }

  /// Disposes form controllers owned by the assignment form.
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

  /// Loads the available active rangers for the assignment form.
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

  /// Validates the manager's form and persists the assignment via its service.
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

  /// Builds the manager assignment view with its assignment workflow styling.
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
              const _StepHeader(
                step: 1,
                title: 'Select ranger',
                subtitle: 'Choose who will receive this patrol assignment.',
              ),
              const SizedBox(height: 12),
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
              const _StepHeader(
                step: 2,
                title: 'Define patrol area',
                subtitle:
                    'Use names that help the ranger identify the place and route.',
              ),
              const SizedBox(height: 12),
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
              const _StepHeader(
                step: 3,
                title: 'Build route on map',
                subtitle:
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

  /// Opens the route builder and adopts its returned planned route.
  Future<void> _buildRoute() async {
    final route = await Navigator.of(context).push<PatrolRoutePlan>(
      MaterialPageRoute<PatrolRoutePlan>(
        builder: (_) => PatrolRouteBuilderPage(initialRoute: _plannedRoute),
      ),
    );
    if (route != null && mounted) setState(() => _plannedRoute = route);
  }
}

/// Renders a numbered section heading using the active Material theme.
/// SRP: presentation-only step indicator and copy.
class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  /// Sequential number displayed in the section marker.
  final int step;

  /// Short heading for the assignment-form section.
  final String title;

  /// Supporting instruction for the assignment-form section.
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          child: Text('$step', style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
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
