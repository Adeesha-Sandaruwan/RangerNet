import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/patrol.dart';
import '../domain/patrol_records.dart';

class PatrolRouteMap extends StatelessWidget {
  const PatrolRouteMap({
    this.patrol,
    this.plannedRoute,
    this.latestLocation,
    this.height = 260,
    super.key,
  });

  final Patrol? patrol;
  final PatrolRoutePlan? plannedRoute;
  final PatrolLocation? latestLocation;
  final double height;

  @override
  Widget build(BuildContext context) {
    final currentPatrol = patrol;
    final plan = plannedRoute ?? currentPatrol?.plannedRoute;
    final actualStart = currentPatrol?.startLocation;
    final actualEnd = currentPatrol?.endLocation;
    final lastRoutePoint = currentPatrol?.routePoints.isNotEmpty == true
        ? currentPatrol!.routePoints.last.location
        : null;
    final planned =
        plan?.routeLocations
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList() ??
        const <LatLng>[];
    final actual = <LatLng>[
      if (currentPatrol?.startLocation != null)
        _latLng(currentPatrol!.startLocation!),
      ...?currentPatrol?.routePoints.map((point) => _latLng(point.location)),
      if (currentPatrol?.routePoints.isNotEmpty == true &&
          actualEnd?.source == PatrolLocationSource.gps &&
          lastRoutePoint != null &&
          actualEnd!.recordedAt.isAfter(lastRoutePoint.recordedAt))
        _latLng(currentPatrol!.endLocation!),
    ];
    final manualPoints =
        currentPatrol?.manualWaypoints
            .map((waypoint) => _latLng(waypoint.location))
            .toList() ??
        const <LatLng>[];
    final allPoints = [
      ...planned,
      ...actual,
      ...manualPoints,
      if (latestLocation != null) _latLng(latestLocation!),
    ];
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
                : CameraFit.coordinates(coordinates: allPoints, maxZoom: 14),
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
                if (plan == null && actualStart != null)
                  Marker(
                    point: _latLng(actualStart),
                    width: 36,
                    height: 40,
                    child: const Icon(
                      Icons.trip_origin,
                      color: Color(0xFF17613F),
                      size: 32,
                    ),
                  ),
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
                if (actualEnd != null &&
                    actualEnd.source == PatrolLocationSource.manual)
                  Marker(
                    point: _latLng(actualEnd),
                    width: 36,
                    height: 40,
                    child: const Icon(
                      Icons.flag_outlined,
                      color: Colors.deepPurple,
                      size: 32,
                    ),
                  ),
                if (latestLocation != null)
                  Marker(
                    point: _latLng(latestLocation!),
                    width: 28,
                    height: 28,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2673B8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
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
