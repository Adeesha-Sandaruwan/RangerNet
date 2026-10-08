import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/patrol.dart';
import '../domain/patrol_records.dart';

class PatrolRouteMap extends StatelessWidget {
  const PatrolRouteMap({
    this.patrol,
    this.plannedRoute,
    this.height = 260,
    super.key,
  });

  final Patrol? patrol;
  final PatrolRoutePlan? plannedRoute;
  final double height;

  @override
  Widget build(BuildContext context) {
    final currentPatrol = patrol;
    final plan = plannedRoute ?? currentPatrol?.plannedRoute;
    final planned = plan?.routeLocations
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList() ??
        const <LatLng>[];
    final actual = <LatLng>[
      if (currentPatrol?.startLocation != null)
        _latLng(currentPatrol!.startLocation!),
      ...?currentPatrol?.routePoints.map((point) => _latLng(point.location)),
      if (currentPatrol?.endLocation != null)
        _latLng(currentPatrol!.endLocation!),
    ];
    final allPoints = [...planned, ...actual];
    if (allPoints.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: allPoints.length > 1
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(allPoints),
                    padding: const EdgeInsets.all(36),
                  )
                : CameraFit.coordinates(
                    coordinates: allPoints,
                    maxZoom: 14,
                  ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'lk.rangernet.rangernet',
            ),
            if (planned.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: planned,
                    strokeWidth: 5,
                    color: const Color(0xFF17613F),
                  ),
                ],
              ),
            if (actual.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: actual,
                    strokeWidth: 4,
                    color: const Color(0xFF2673B8),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (plan != null) ...[
                  _marker(plan.start, 'S', const Color(0xFF17613F)),
                  ...plan.stops.indexed.map(
                    (entry) => _marker(
                      entry.$2,
                      '${entry.$1 + 1}',
                      const Color(0xFF4677A8),
                    ),
                  ),
                  _marker(plan.end, 'E', Colors.deepOrange),
                ],
                ...?currentPatrol?.manualWaypoints.map(
                  (waypoint) => Marker(
                    point: _latLng(waypoint.location),
                    width: 36,
                    height: 40,
                    child: const Icon(
                      Icons.add_location_alt,
                      color: Colors.deepPurple,
                      size: 34,
                    ),
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
    );
  }

  LatLng _latLng(PatrolLocation location) =>
      LatLng(location.latitude, location.longitude);

  Marker _marker(
    PatrolCoverageCheckpoint checkpoint,
    String label,
    Color color,
  ) => Marker(
    point: LatLng(checkpoint.latitude, checkpoint.longitude),
    width: 42,
    height: 46,
    child: CircleAvatar(
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
  );
}
