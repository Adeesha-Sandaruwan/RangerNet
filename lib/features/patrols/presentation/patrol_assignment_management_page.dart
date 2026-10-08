import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../application/patrol_assignment_service.dart';
import '../domain/patrol_assignment.dart';
import '../domain/patrol_records.dart';
import 'patrol_coverage_section_map_page.dart';

class PatrolAssignmentManagementPage extends StatefulWidget {
  const PatrolAssignmentManagementPage({required this.service, super.key});

  final PatrolAssignmentService service;

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
                    child: ListTile(
                      leading: const Icon(
                        Icons.route,
                        color: Color(0xFF17613F),
                      ),
                      title: Text(assignment.area.routeName),
                      subtitle: Text(
                        '${assignment.area.parkName} · ${assignment.area.zoneName}\n'
                        '${assignment.plannedCoverageSections.length} coverage sections · '
                        'Assigned to ${assignment.rangerName} · '
                        '${assignment.assignedAt.toLocal()}',
                      ),
                      isThreeLine: true,
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
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  List<PatrolCoverageCheckpoint> _coverageSections = const [];
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
    _latitude.dispose();
    _longitude.dispose();
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
    final latitudeText = _latitude.text.trim();
    final longitudeText = _longitude.text.trim();
    final latitude = latitudeText.isEmpty
        ? null
        : double.tryParse(latitudeText);
    final longitude = longitudeText.isEmpty
        ? null
        : double.tryParse(longitudeText);
    if ((latitudeText.isNotEmpty && latitude == null) ||
        (longitudeText.isNotEmpty && longitude == null)) {
      setState(() => _error = 'Map coordinates must be valid numbers.');
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
          centerLatitude: latitude,
          centerLongitude: longitude,
          plannedCoverageSections: _coverageSections,
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
                '3. Optional map start center',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Both coordinates are needed. This gives manual map selection '
                'a useful center; it does not define a route boundary.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _optionalField(
                      _latitude,
                      'Latitude',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _optionalField(
                      _longitude,
                      'Longitude',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _saving ? null : _editCoverageSections,
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  _coverageSections.isEmpty
                      ? 'Mark route coverage sections'
                      : 'Edit ${_coverageSections.length} coverage sections',
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Coverage sections are optional. Rangers will see which '
                  'marked sections were not reached during the patrol.',
                ),
              ),
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
                label: const Text('Create patrol assignment'),
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

  Future<void> _editCoverageSections() async {
    final latitudeText = _latitude.text.trim();
    final longitudeText = _longitude.text.trim();
    final latitude = latitudeText.isEmpty
        ? null
        : double.tryParse(latitudeText);
    final longitude = longitudeText.isEmpty
        ? null
        : double.tryParse(longitudeText);
    if ((latitudeText.isNotEmpty && latitude == null) ||
        (longitudeText.isNotEmpty && longitude == null)) {
      setState(() => _error = 'Map center coordinates must be valid numbers.');
      return;
    }
    if ((latitude == null) != (longitude == null)) {
      setState(() => _error = 'Enter both map center coordinates, or neither.');
      return;
    }
    if (latitude != null &&
        (!latitude.isFinite || latitude < -90 || latitude > 90)) {
      setState(
        () => _error = 'Map center latitude must be between -90 and 90.',
      );
      return;
    }
    if (longitude != null &&
        (!longitude.isFinite || longitude < -180 || longitude > 180)) {
      setState(
        () => _error = 'Map center longitude must be between -180 and 180.',
      );
      return;
    }
    final center = latitude == null || longitude == null
        ? null
        : LatLng(latitude, longitude);
    final sections = await Navigator.of(context)
        .push<List<PatrolCoverageCheckpoint>>(
          MaterialPageRoute<List<PatrolCoverageCheckpoint>>(
            builder: (_) => PatrolCoverageSectionMapPage(
              initialCenter: center,
              initialSections: _coverageSections,
            ),
          ),
        );
    if (sections != null && mounted) {
      setState(() => _coverageSections = sections);
    }
  }
}
