import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/patrol.dart';
import '../domain/patrol_records.dart';

/// Lets a ranger select and describe a manual patrol location on a map.
/// SRP: gathers one location record; its caller controls patrol persistence.
class ManualWaypointMapPage extends StatefulWidget {
  const ManualWaypointMapPage({
    required this.patrol,
    this.initialLocation,
    this.showTileLayer = true,
    super.key,
  });

  /// Patrol whose current route is shown while selecting a waypoint.
  final Patrol patrol;

  /// Optional coordinate to center the map on initially.
  final PatrolLocation? initialLocation;

  /// Whether to display map tiles beneath the patrol overlays.
  final bool showTileLayer;

  @override
  State<ManualWaypointMapPage> createState() => _ManualWaypointMapPageState();
}

/// Manages map selection and form state for a manual waypoint.
class _ManualWaypointMapPageState extends State<ManualWaypointMapPage> {
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  LatLng? _center;
  LatLng? _selected;
  bool _tilesUnavailable = false;
  bool _allowPop = false;

  bool get _hasUnsavedChanges =>
      _selected != null ||
      _latitude.text.trim().isNotEmpty ||
      _longitude.text.trim().isNotEmpty;

  /// Initializes map selection and editable coordinate fields.
  @override
  void initState() {
    super.initState();
    final area = widget.patrol.area;
    final plannedStart = widget.patrol.plannedRoute?.start;
    final location = widget.initialLocation ?? widget.patrol.startLocation;
    final centerLat =
        area.centerLatitude ?? plannedStart?.latitude ?? location?.latitude;
    final centerLng =
        area.centerLongitude ?? plannedStart?.longitude ?? location?.longitude;
    if (centerLat != null && centerLng != null) {
      _center = LatLng(centerLat, centerLng);
    }
  }

  /// Releases the coordinate controllers owned by this page.
  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;
    return PopScope<Object?>(
      canPop: !_hasUnsavedChanges || _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _hasUnsavedChanges) {
          unawaited(_confirmDiscard());
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Mark exact location on map')),
        body: center == null ? _buildChooseCenter() : _buildMap(center),
      ),
    );
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved location?'),
        content: const Text(
          'The selected manual waypoint has not been added to the patrol.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep selecting'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  Widget _buildChooseCenter() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: ListView(
        padding: const EdgeInsets.all(20),
        shrinkWrap: true,
        children: [
          const Icon(Icons.map_outlined, size: 46),
          const SizedBox(height: 12),
          const Text(
            'No patrol map center is configured. Enter an approximate center '
            'coordinate for this assigned zone to open the map.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _latitude,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Map center latitude',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _longitude,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Map center longitude',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _openMapAtEnteredCenter,
            child: const Text('Open map'),
          ),
        ],
      ),
    ),
  );

  Widget _buildMap(LatLng center) {
    final actualRoute = <LatLng>[
      if (widget.patrol.startLocation != null)
        LatLng(
          widget.patrol.startLocation!.latitude,
          widget.patrol.startLocation!.longitude,
        ),
      ...widget.patrol.routePoints.map(
        (point) => LatLng(point.location.latitude, point.location.longitude),
      ),
      if (widget.patrol.routePoints.isNotEmpty &&
          widget.patrol.endLocation?.source == PatrolLocationSource.gps &&
          widget.patrol.endLocation!.recordedAt.isAfter(
            widget.patrol.routePoints.last.location.recordedAt,
          ))
        LatLng(
          widget.patrol.endLocation!.latitude,
          widget.patrol.endLocation!.longitude,
        ),
    ];
    return Column(
      children: [
        if (_tilesUnavailable)
          const MaterialBanner(
            content: Text(
              'Map tiles are unavailable. The marker still records the location '
              'you select, but verify it against the assigned area.',
            ),
            leading: Icon(Icons.map_outlined),
            actions: [SizedBox.shrink()],
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Text(
                'Tap the map to mark the exact location. This records a manual '
                'point and does not change the manager-assigned route.',
              ),
              SizedBox(height: 4),
              Text(
                'Map tiles need internet access; selected coordinates are saved '
                'to the patrol on this device.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              SizedBox(height: 6),
              Wrap(
                spacing: 14,
                children: [
                  _MapLegend(color: Color(0xFF17613F), label: 'Assigned route'),
                  _MapLegend(color: Color(0xFF2673B8), label: 'GPS track'),
                  _MapLegend(color: Color(0xFFB54735), label: 'Saved point'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCameraFit: _cameraFit(center),
              onTap: (_, point) => setState(() => _selected = point),
            ),
            children: [
              if (widget.showTileLayer)
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
              if (actualRoute.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: actualRoute,
                      strokeWidth: 4,
                      color: const Color(0xFF2673B8),
                    ),
                  ],
                ),
              if (widget.patrol.plannedRoute case final route?)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route.routeLocations
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
                  if (widget.patrol.plannedRoute case final route?) ...[
                    Marker(
                      point: LatLng(
                        route.start.latitude,
                        route.start.longitude,
                      ),
                      child: const Icon(
                        Icons.trip_origin,
                        color: Color(0xFF17613F),
                        size: 34,
                      ),
                    ),
                    ...route.stops.indexed.map(
                      (entry) => Marker(
                        point: LatLng(entry.$2.latitude, entry.$2.longitude),
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFF4677A8),
                          child: Text(
                            '${entry.$1 + 1}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    Marker(
                      point: LatLng(route.end.latitude, route.end.longitude),
                      child: const Icon(
                        Icons.flag,
                        color: Colors.deepOrange,
                        size: 34,
                      ),
                    ),
                  ],
                  ...widget.patrol.manualWaypoints.map(
                    (waypoint) => Marker(
                      point: LatLng(
                        waypoint.location.latitude,
                        waypoint.location.longitude,
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFFB54735),
                        size: 38,
                      ),
                    ),
                  ),
                  if (_selected != null)
                    Marker(
                      point: _selected!,
                      child: const Icon(
                        Icons.add_location_alt,
                        color: Color(0xFF17613F),
                        size: 42,
                      ),
                    ),
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
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selected == null
                        ? 'No location selected'
                        : '${_selected!.latitude.toStringAsFixed(6)}, '
                              '${_selected!.longitude.toStringAsFixed(6)} · Manual',
                  ),
                ),
                FilledButton(
                  onPressed: _selected == null ? null : _confirmSelection,
                  child: const Text('Use location'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  CameraFit _cameraFit(LatLng center) {
    final planned =
        widget.patrol.plannedRoute?.routeLocations
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList() ??
        const <LatLng>[];
    final actual = widget.patrol.routePoints
        .map(
          (point) => LatLng(point.location.latitude, point.location.longitude),
        )
        .toList();
    final manual = widget.patrol.manualWaypoints
        .map(
          (waypoint) =>
              LatLng(waypoint.location.latitude, waypoint.location.longitude),
        )
        .toList();
    final points = [
      ...planned,
      if (widget.patrol.startLocation case final start?)
        LatLng(start.latitude, start.longitude),
      ...actual,
      ...manual,
    ];
    if (points.isEmpty) {
      return CameraFit.coordinates(coordinates: [center], maxZoom: 15);
    }
    return CameraFit.coordinates(
      coordinates: points,
      maxZoom: 15,
      padding: const EdgeInsets.all(48),
    );
  }

  /// Recenters the map using validated latitude and longitude form values.
  void _openMapAtEnteredCenter() {
    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid map center coordinates.')),
      );
      return;
    }

    setState(() => _center = LatLng(latitude, longitude));
  }

  /// Returns the validated manual location to the calling patrol screen.
  void _confirmSelection() {
    final point = _selected;
    if (point == null) return;
    setState(() => _allowPop = true);
    final location = PatrolLocation(
      latitude: point.latitude,
      longitude: point.longitude,
      recordedAt: DateTime.now().toUtc(),
      source: PatrolLocationSource.manual,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(location);
    });
  }
}

/// Explains the map's planned, recorded, and manually marked locations.
class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.color, required this.label});

  final Color color;

  /// Human-readable description of the map marker.
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
