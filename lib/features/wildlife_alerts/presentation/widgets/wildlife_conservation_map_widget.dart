import 'package:flutter/material.dart';
import '../../domain/models/animal.dart';
import '../../domain/models/geo_location.dart';
import '../../domain/models/high_risk_zone.dart';
import '../../domain/models/sensor.dart';
import '../../domain/models/wildlife_alert.dart';

class MapCoordinateProjection {
  MapCoordinateProjection({
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;
  final double canvasWidth;
  final double canvasHeight;

  Offset project(double lat, double lon) {
    final xRatio = (lon - minLon) / (maxLon - minLon);
    // Invert Y because latitude increases northward (up) but canvas Y increases downward (down)
    final yRatio = (maxLat - lat) / (maxLat - minLat);

    final x = (xRatio * (canvasWidth - 80)) + 40;
    final y = (yRatio * (canvasHeight - 80)) + 40;
    return Offset(x, y);
  }

  double projectRadius(double radiusMeters) {
    // 1 degree latitude ~ 111,000 meters
    final totalLatMeters = (maxLat - minLat) * 111000.0;
    final pixelPerMeter = canvasHeight / totalLatMeters;
    return radiusMeters * pixelPerMeter;
  }
}

/// Rich vector-rendered interactive Conservation Reserve Map.
class WildlifeConservationMapWidget extends StatefulWidget {
  const WildlifeConservationMapWidget({
    required this.zones,
    required this.animals,
    required this.sensors,
    this.alerts = const [],
    this.selectedAnimalId,
    this.selectedAlert,
    this.highlightBreadcrumbs = const [],
    this.onTargetSelected,
    this.showControls = true,
    this.initialZoom = 1.0,
    super.key,
  });

  final List<HighRiskZone> zones;
  final List<Animal> animals;
  final List<Sensor> sensors;
  final List<WildlifeAlert> alerts;
  final String? selectedAnimalId;
  final WildlifeAlert? selectedAlert;
  final List<GeoLocation> highlightBreadcrumbs;
  final void Function(dynamic target)? onTargetSelected;
  final bool showControls;
  final double initialZoom;

  @override
  State<WildlifeConservationMapWidget> createState() =>
      _WildlifeConservationMapWidgetState();
}

class _WildlifeConservationMapWidgetState
    extends State<WildlifeConservationMapWidget>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformController;
  late final AnimationController _pulseController;
  double _currentZoom = 1.0;

  // Geographic bounds of Yala Conservation Sector
  static const double minLat = 6.3300;
  static const double maxLat = 6.5000;
  static const double minLon = 81.3000;
  static const double maxLon = 81.5000;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _currentZoom = widget.initialZoom;
    _transformController.value = Matrix4.diagonal3Values(
      _currentZoom,
      _currentZoom,
      1.0,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _transformController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 0.3).clamp(0.8, 3.5);
      _transformController.value = Matrix4.diagonal3Values(
        _currentZoom,
        _currentZoom,
        1.0,
      );
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 0.3).clamp(0.8, 3.5);
      _transformController.value = Matrix4.diagonal3Values(
        _currentZoom,
        _currentZoom,
        1.0,
      );
    });
  }

  void _resetView() {
    setState(() {
      _currentZoom = 1.0;
      _transformController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final projection = MapCoordinateProjection(
          minLat: minLat,
          maxLat: maxLat,
          minLon: minLon,
          maxLon: maxLon,
          canvasWidth: width,
          canvasHeight: height,
        );

        return Stack(
          children: [
            // Interactive Zoom/Pan canvas
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.8,
                maxScale: 4.0,
                boundaryMargin: const EdgeInsets.all(120),
                child: SizedBox(
                  width: width,
                  height: height,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: Size(width, height),
                        painter: _ConservationMapPainter(
                          projection: projection,
                          zones: widget.zones,
                          animals: widget.animals,
                          sensors: widget.sensors,
                          alerts: widget.alerts,
                          selectedAnimalId: widget.selectedAnimalId,
                          selectedAlert: widget.selectedAlert,
                          highlightBreadcrumbs: widget.highlightBreadcrumbs,
                          pulseValue: _pulseController.value,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Top-left map HUD header & coordinates
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar, size: 14, color: Colors.greenAccent),
                    SizedBox(width: 6),
                    Text(
                      'Yala Sector I — Live Telemetry GIS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Map legend at bottom-left
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLegendItem(
                      const Color(0xFFFF5252),
                      'High Risk Geofence',
                      isFill: true,
                    ),
                    const SizedBox(height: 4),
                    _buildLegendItem(
                      const Color(0xFF00E676),
                      'GPS Collar Breadcrumbs',
                      isLine: true,
                    ),
                    const SizedBox(height: 4),
                    _buildLegendItem(
                      const Color(0xFF40C4FF),
                      'Camera Trap Node',
                      isCircle: true,
                    ),
                  ],
                ),
              ),
            ),

            // Map controls at top-right
            if (widget.showControls)
              Positioned(
                top: 12,
                right: 12,
                child: Column(
                  children: [
                    _buildControlButton(Icons.add, _zoomIn, 'Zoom in'),
                    const SizedBox(height: 6),
                    _buildControlButton(Icons.remove, _zoomOut, 'Zoom out'),
                    const SizedBox(height: 6),
                    _buildControlButton(
                      Icons.my_location,
                      _resetView,
                      'Recenter',
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildControlButton(
    IconData icon,
    VoidCallback onPressed,
    String tooltip,
  ) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: const Color(0xFF17613F)),
        ),
      ),
    );
  }

  Widget _buildLegendItem(
    Color color,
    String label, {
    bool isFill = false,
    bool isLine = false,
    bool isCircle = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFill)
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.4),
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(2),
            ),
          )
        else if (isLine)
          Container(width: 14, height: 3, color: color)
        else
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
}

class _ConservationMapPainter extends CustomPainter {
  _ConservationMapPainter({
    required this.projection,
    required this.zones,
    required this.animals,
    required this.sensors,
    required this.alerts,
    this.selectedAnimalId,
    this.selectedAlert,
    required this.highlightBreadcrumbs,
    required this.pulseValue,
  });

  final MapCoordinateProjection projection;
  final List<HighRiskZone> zones;
  final List<Animal> animals;
  final List<Sensor> sensors;
  final List<WildlifeAlert> alerts;
  final String? selectedAnimalId;
  final WildlifeAlert? selectedAlert;
  final List<GeoLocation> highlightBreadcrumbs;
  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw National Park terrain background
    _drawTerrain(canvas, size);

    // 2. Draw Menik Ganga River watercourse
    _drawRiver(canvas, size);

    // 3. Draw High Risk Geofence zones (Polygons and Circles)
    _drawGeofences(canvas, size);

    // 4. Draw Camera Traps
    _drawCameraTraps(canvas, size);

    // 5. Draw Location Breadcrumb Trajectories
    _drawBreadcrumbs(canvas, size);

    // 6. Draw Monitored Animals
    _drawAnimals(canvas, size);
  }

  void _drawTerrain(Canvas canvas, Size size) {
    // Background terrain fill (rich forest reserve tones)
    final bgPaint = Paint()..color = const Color(0xFF1E3A2B);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Subtle grid coordinates
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    for (double x = 40; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 40; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // National Park Boundary border
    final parkBorderPaint = Paint()
      ..color = const Color(0xFF81C784).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, 20, size.width - 40, size.height - 40),
        const Radius.circular(16),
      ),
      parkBorderPaint,
    );
  }

  void _drawRiver(Canvas canvas, Size size) {
    // Menik Ganga river flow across park sector
    final riverPaint = Paint()
      ..color = const Color(0xFF0288D1).withValues(alpha: 0.6)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final pStart = projection.project(6.4900, 81.3100);
    final pMid1 = projection.project(6.4400, 81.3800);
    final pMid2 = projection.project(6.4000, 81.4200);
    final pEnd = projection.project(6.3400, 81.4900);

    path.moveTo(pStart.dx, pStart.dy);
    path.cubicTo(pMid1.dx, pMid1.dy, pMid2.dx, pMid2.dy, pEnd.dx, pEnd.dy);

    canvas.drawPath(path, riverPaint);

    // River label
    final textPainter = TextPainter(
      text: TextSpan(
        text: '~ Menik Ganga River Corridor ~',
        style: TextStyle(
          color: const Color(0xFF81D4FA).withValues(alpha: 0.7),
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(pMid2.dx - 40, pMid2.dy - 16));
  }

  void _drawGeofences(Canvas canvas, Size size) {
    for (final zone in zones) {
      Color zoneColor;
      switch (zone.severityLevel) {
        case ZoneSeverityLevel.high:
          zoneColor = const Color(0xFFFF5252);
          break;
        case ZoneSeverityLevel.medium:
          zoneColor = const Color(0xFFFFB74D);
          break;
        case ZoneSeverityLevel.low:
          zoneColor = const Color(0xFF81C784);
          break;
      }

      final fillPaint = Paint()
        ..color = zoneColor.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = zoneColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      if (zone.geofenceType == GeofenceType.polygon &&
          zone.boundaryPolygon.length >= 3) {
        final polyPath = Path();
        for (int i = 0; i < zone.boundaryPolygon.length; i++) {
          final loc = zone.boundaryPolygon[i];
          final pt = projection.project(loc.latitude, loc.longitude);
          if (i == 0) {
            polyPath.moveTo(pt.dx, pt.dy);
          } else {
            polyPath.lineTo(pt.dx, pt.dy);
          }
        }
        polyPath.close();

        canvas.drawPath(polyPath, fillPaint);
        canvas.drawPath(polyPath, strokePaint);

        // Zone label
        if (zone.boundaryPolygon.isNotEmpty) {
          final first = projection.project(
            zone.boundaryPolygon[0].latitude,
            zone.boundaryPolygon[0].longitude,
          );
          _drawLabel(
            canvas,
            '🚨 ${zone.name}',
            Offset(first.dx + 6, first.dy + 4),
            zoneColor,
          );
        }
      } else if (zone.centerLocation != null && zone.radiusMeters != null) {
        final center = projection.project(
          zone.centerLocation!.latitude,
          zone.centerLocation!.longitude,
        );
        final radius = projection.projectRadius(zone.radiusMeters!);

        canvas.drawCircle(center, radius, fillPaint);
        canvas.drawCircle(center, radius, strokePaint);

        _drawLabel(
          canvas,
          '⚠️ ${zone.name}',
          Offset(center.dx - 30, center.dy - radius - 14),
          zoneColor,
        );
      }
    }
  }

  void _drawCameraTraps(Canvas canvas, Size size) {
    for (final sensor in sensors) {
      if (sensor is CameraTrap) {
        final pos = projection.project(
          sensor.cameraLocation.latitude,
          sensor.cameraLocation.longitude,
        );

        // Pulsing radar ring
        final pulseRadius = 14 + (pulseValue * 8);
        final pulsePaint = Paint()
          ..color = const Color(
            0xFF40C4FF,
          ).withValues(alpha: (1.0 - pulseValue) * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(pos, pulseRadius, pulsePaint);

        // Camera trap node center
        final nodePaint = Paint()
          ..color = const Color(0xFF0288D1)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 6, nodePaint);

        // Icon outline
        final borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(pos, 6, borderPaint);

        // Label
        _drawLabel(
          canvas,
          '📷 ${sensor.name ?? sensor.id}',
          Offset(pos.dx - 20, pos.dy + 8),
          const Color(0xFF81D4FA),
        );
      }
    }
  }

  void _drawBreadcrumbs(Canvas canvas, Size size) {
    // 1. Draw breadcrumbs for selected alert or highlight
    final breadcrumbsToDraw = highlightBreadcrumbs.isNotEmpty
        ? highlightBreadcrumbs
        : (selectedAlert?.locationHistory ?? []);

    if (breadcrumbsToDraw.length > 1) {
      final linePaint = Paint()
        ..color = const Color(0xFF00E676)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      for (int i = 0; i < breadcrumbsToDraw.length; i++) {
        final loc = breadcrumbsToDraw[i];
        final pt = projection.project(loc.latitude, loc.longitude);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }

        // Draw waypoint dot
        final dotPaint = Paint()
          ..color = i == breadcrumbsToDraw.length - 1
              ? Colors.redAccent
              : const Color(0xFF00E676)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          pt,
          i == breadcrumbsToDraw.length - 1 ? 5 : 3.5,
          dotPaint,
        );
      }
      canvas.drawPath(path, linePaint);
    }
  }

  void _drawAnimals(Canvas canvas, Size size) {
    for (final animal in animals) {
      // Find corresponding collar
      final collar = sensors
          .whereType<GPSCollar>()
          .cast<GPSCollar?>()
          .firstWhere((c) => c?.id == animal.collarId, orElse: () => null);

      if (collar != null) {
        final pos = projection.project(
          collar.currentLocation.latitude,
          collar.currentLocation.longitude,
        );

        final isSelected =
            selectedAnimalId == animal.id ||
            selectedAlert?.targetId == animal.id;

        // Animated pulse ring around animal
        final ringRadius = isSelected
            ? 22 + (pulseValue * 10)
            : 16 + (pulseValue * 6);
        final ringPaint = Paint()
          ..color = (isSelected ? Colors.amberAccent : Colors.greenAccent)
              .withValues(alpha: (1.0 - pulseValue) * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(pos, ringRadius, ringPaint);

        // Core marker avatar
        final avatarPaint = Paint()
          ..color = isSelected
              ? const Color(0xFFFFB300)
              : const Color(0xFF2E7D32)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 10, avatarPaint);

        final avatarBorder = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(pos, 10, avatarBorder);

        // Animal emoji/icon symbol
        String icon = '🐾';
        if (animal.species.toLowerCase().contains('elephant')) {
          icon = '🐘';
        } else if (animal.species.toLowerCase().contains('leopard')) {
          icon = '🐆';
        } else if (animal.species.toLowerCase().contains('deer') ||
            animal.species.toLowerCase().contains('sambar')) {
          icon = '🦌';
        }

        final emojiPainter = TextPainter(
          text: TextSpan(text: icon, style: const TextStyle(fontSize: 11)),
          textDirection: TextDirection.ltr,
        )..layout();
        emojiPainter.paint(
          canvas,
          Offset(
            pos.dx - (emojiPainter.width / 2),
            pos.dy - (emojiPainter.height / 2),
          ),
        );

        // Label above animal
        _drawLabel(
          canvas,
          '${animal.name} (${collar.batteryLevel.toStringAsFixed(0)}%)',
          Offset(pos.dx - 24, pos.dy - 22),
          isSelected ? Colors.amberAccent : Colors.white,
        );
      }
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset position, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black.withValues(alpha: 0.6),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _ConservationMapPainter oldDelegate) {
    return true; // repaint on pulse animation or data changes
  }
}
