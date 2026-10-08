import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/patrol.dart';
import '../domain/patrol_records.dart';

class ManualWaypointMapPage extends StatefulWidget {
  const ManualWaypointMapPage({
    required this.patrol,
    this.initialLocation,
    super.key,
  });

  final Patrol patrol;
  final PatrolLocation? initialLocation;

  @override
  State<ManualWaypointMapPage> createState() => _ManualWaypointMapPageState();
}

class _ManualWaypointMapPageState extends State<ManualWaypointMapPage> {
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  LatLng? _center;
  LatLng? _selected;
  bool _tilesUnavailable = false;

  @override
  void initState() {
    super.initState();
    final area = widget.patrol.area;
    final location = widget.initialLocation ?? widget.patrol.startLocation;
    final centerLat = area.centerLatitude ?? location?.latitude;
    final centerLng = area.centerLongitude ?? location?.longitude;
    if (centerLat != null && centerLng != null) {
      _center = LatLng(centerLat, centerLng);
    }
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;
    return Scaffold(
      appBar: AppBar(title: const Text('Place a manual waypoint')),
      body: center == null ? _buildChooseCenter() : _buildMap(center),
    );
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

  Widget _buildMap(LatLng center) => Column(
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
        child: Text(
          'Tap the map to place a waypoint. OpenStreetMap tiles need a network '
          'connection; your selected coordinate is saved locally.',
        ),
      ),
      Expanded(
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
            onTap: (_, point) => setState(() => _selected = point),
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
            if (widget.patrol.routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.patrol.routePoints
                        .map(
                          (point) => LatLng(
                            point.location.latitude,
                            point.location.longitude,
                          ),
                        )
                        .toList(),
                    strokeWidth: 4,
                    color: const Color(0xFF17613F),
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
                      point: LatLng(
                        entry.$2.latitude,
                        entry.$2.longitude,
                      ),
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

  void _confirmSelection() {
    final point = _selected;
    if (point == null) return;
    Navigator.of(context).pop(
      PatrolLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        recordedAt: DateTime.now().toUtc(),
        source: PatrolLocationSource.manual,
      ),
    );
  }
}
