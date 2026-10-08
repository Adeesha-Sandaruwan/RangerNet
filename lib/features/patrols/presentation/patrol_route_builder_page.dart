import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../application/patrol_route_coverage_generator.dart';
import '../domain/patrol_records.dart';

enum _RoutePickMode { start, stop, end }

class PatrolRouteBuilderPage extends StatefulWidget {
  const PatrolRouteBuilderPage({this.initialRoute, super.key});

  final PatrolRoutePlan? initialRoute;

  @override
  State<PatrolRouteBuilderPage> createState() => _PatrolRouteBuilderPageState();
}

class _PatrolRouteBuilderPageState extends State<PatrolRouteBuilderPage> {
  static const _uuid = Uuid();
  static const _coverageGenerator = PatrolRouteCoverageGenerator();
  static const _defaultMapCenter = LatLng(7.8731, 80.7718);

  PatrolCoverageCheckpoint? _start;
  PatrolCoverageCheckpoint? _end;
  final List<PatrolCoverageCheckpoint> _stops = [];
  _RoutePickMode _mode = _RoutePickMode.start;
  late LatLng _mapCenter = _defaultMapCenter;
  bool _tilesUnavailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final route = widget.initialRoute;
    if (route != null) {
      _start = route.start;
      _end = route.end;
      _stops.addAll(route.stops);
      _mode = _RoutePickMode.stop;
      _mapCenter = LatLng(route.start.latitude, route.start.longitude);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Build assigned patrol route')),
    body: Column(
      children: [
        if (_tilesUnavailable)
          const MaterialBanner(
            content: Text(
              'Map tiles are unavailable. Route points can still be selected, '
              'but check them against the map before saving.',
            ),
            leading: Icon(Icons.map_outlined),
            actions: [SizedBox.shrink()],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            'Select a start and destination on the map, then add optional '
            'stops in visit order. The preview connects your selected points '
            'with straight lines; verify that it follows accessible patrol '
            'tracks. Coverage sections are generated along that line.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              _modeButton(
                mode: _RoutePickMode.start,
                icon: Icons.trip_origin,
                label: _start == null ? 'Select start' : 'Change start',
              ),
              _modeButton(
                mode: _RoutePickMode.stop,
                icon: Icons.add_location_alt_outlined,
                label: 'Add optional stop',
              ),
              _modeButton(
                mode: _RoutePickMode.end,
                icon: Icons.flag_outlined,
                label: _end == null ? 'Select destination' : 'Change end',
              ),
            ],
          ),
        ),
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 8,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'lk.rangernet.rangernet',
                errorTileCallback: (_, _, _) {
                  if (_tilesUnavailable || !mounted) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _tilesUnavailable = true);
                  });
                },
              ),
              if (_start != null && _end != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routeLocations
                          .map(
                            (point) => LatLng(point.latitude, point.longitude),
                          )
                          .toList(),
                      strokeWidth: 5,
                      color: const Color(0xFF17613F),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_start case final start?)
                    _marker(start, 'S', const Color(0xFF17613F)),
                  ..._stops.indexed.map(
                    (entry) => _marker(
                      entry.$2,
                      '${entry.$1 + 1}',
                      const Color(0xFF4677A8),
                    ),
                  ),
                  if (_end case final end?)
                    _marker(end, 'E', Colors.deepOrange),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
        if (_stops.isNotEmpty)
          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _stops
                  .map(
                    (stop) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        avatar: const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                        ),
                        label: Text(stop.name),
                        onDeleted: () => setState(() => _stops.remove(stop)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFB42318)),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _start == null || _end == null
                        ? 'Select start and destination'
                        : '${_stops.length} optional stop(s)',
                  ),
                ),
                FilledButton.icon(
                  onPressed: _start == null || _end == null
                      ? null
                      : _generateAndSave,
                  icon: const Icon(Icons.route),
                  label: const Text('Generate route coverage'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  List<PatrolCoverageCheckpoint> get _routeLocations => [
    ?_start,
    ..._stops,
    ?_end,
  ];

  Widget _modeButton({
    required _RoutePickMode mode,
    required IconData icon,
    required String label,
  }) => ChoiceChip(
    selected: _mode == mode,
    avatar: Icon(icon, size: 18),
    label: Text(label),
    onSelected: (_) => setState(() {
      _mode = mode;
      _error = null;
    }),
  );

  Marker _marker(
    PatrolCoverageCheckpoint checkpoint,
    String label,
    Color color,
  ) => Marker(
    point: LatLng(checkpoint.latitude, checkpoint.longitude),
    width: 44,
    height: 50,
    child: Column(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Icon(Icons.arrow_drop_down, size: 16),
      ],
    ),
  );

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _error = null;
      final checkpoint = PatrolCoverageCheckpoint(
        id: _uuid.v4(),
        name: switch (_mode) {
          _RoutePickMode.start => 'Start',
          _RoutePickMode.stop => 'Stop ${_stops.length + 1}',
          _RoutePickMode.end => 'Destination',
        },
        latitude: point.latitude,
        longitude: point.longitude,
      );
      switch (_mode) {
        case _RoutePickMode.start:
          _start = checkpoint;
        case _RoutePickMode.stop:
          _stops.add(checkpoint);
        case _RoutePickMode.end:
          _end = checkpoint;
      }
      if (_mode == _RoutePickMode.start) _mode = _RoutePickMode.stop;
    });
  }

  void _generateAndSave() {
    final start = _start;
    final end = _end;
    if (start == null || end == null) return;
    try {
      final route = _coverageGenerator.generate(
        start: start,
        stops: _stops,
        end: end,
      );
      Navigator.of(context).pop(route);
    } catch (error) {
      setState(() => _error = 'Could not generate route coverage: $error');
    }
  }
}
