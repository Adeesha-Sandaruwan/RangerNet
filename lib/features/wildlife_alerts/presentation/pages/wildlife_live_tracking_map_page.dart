import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../domain/models/geo_location.dart';
import '../../domain/models/wildlife_alert.dart';
import '../controllers/wildlife_alert_controller.dart';
import '../services/alert_sound_service.dart';
import '../widgets/alert_badges.dart';
import '../widgets/wildlife_conservation_map_widget.dart';
import 'wildlife_alert_detail_page.dart';

enum SimulationRoute {
  elephantBreach('Raja Elephant: Buffer Zone Breach (Geofence Alert)'),
  leopardRiver('Maya Leopard: Menik Ganga River Patrol'),
  rapidPings('Rapid Collar Pings: Throttling & Breadcrumbs Demo');

  const SimulationRoute(this.label);
  final String label;
}

class WildlifeLiveTrackingMapPage extends StatefulWidget {
  const WildlifeLiveTrackingMapPage({
    this.ranger,
    this.rangerId,
    this.rangerName,
    required this.controller,
    this.initialAlertId,
    super.key,
  });

  final User? ranger;
  final String? rangerId;
  final String? rangerName;
  final WildlifeAlertController controller;
  final String? initialAlertId;

  @override
  State<WildlifeLiveTrackingMapPage> createState() =>
      _WildlifeLiveTrackingMapPageState();
}

class _WildlifeLiveTrackingMapPageState
    extends State<WildlifeLiveTrackingMapPage> {
  SimulationRoute _selectedRoute = SimulationRoute.elephantBreach;
  bool _isSimulating = false;
  Timer? _simulationTimer;
  int _currentStepIndex = 0;
  List<GeoLocation> _simulatedBreadcrumbs = [];
  WildlifeAlert? _lastTriggeredAlert;
  String? _selectedAnimalId;

  // Waypoints for Elephant Raja crossing Southern Boundary (lat: 6.35 - 6.37, lon: 81.45 - 81.48)
  final List<GeoLocation> _elephantRouteWaypoints = [
    GeoLocation(latitude: 6.4100, longitude: 81.4300, altitude: 65.0, timestamp: DateTime.now()),
    GeoLocation(latitude: 6.3950, longitude: 81.4400, altitude: 58.0, timestamp: DateTime.now()),
    GeoLocation(latitude: 6.3800, longitude: 81.4480, altitude: 52.0, timestamp: DateTime.now()),
    GeoLocation(latitude: 6.3720, longitude: 81.4520, altitude: 48.0, timestamp: DateTime.now()),
    // Crosses boundary line here! (Inside Southern Buffer Zone)
    GeoLocation(latitude: 6.3650, longitude: 81.4600, altitude: 45.0, timestamp: DateTime.now()),
    GeoLocation(latitude: 6.3610, longitude: 81.4650, altitude: 44.0, timestamp: DateTime.now()),
    GeoLocation(latitude: 6.3570, longitude: 81.4700, altitude: 43.0, timestamp: DateTime.now()),
  ];

  // Waypoints for Leopard Maya patrolling river corridor
  final List<GeoLocation> _leopardRouteWaypoints = [
    GeoLocation(latitude: 6.4500, longitude: 81.3600, altitude: 70.0, timestamp: DateTime.now()),
    GeoLocation(latitude: 6.4350, longitude: 81.3750, altitude: 65.0, timestamp: DateTime.now()),
    GeoLocation(latitude: 6.4220, longitude: 81.3880, altitude: 60.0, timestamp: DateTime.now()),
    GeoLocation(latitude: 6.4150, longitude: 81.3950, altitude: 55.0, timestamp: DateTime.now()),
    GeoLocation(latitude: 6.4080, longitude: 81.4050, altitude: 50.0, timestamp: DateTime.now()),
  ];

  // Rapid pings close together
  final List<GeoLocation> _rapidPingsWaypoints = [
    GeoLocation(latitude: 6.3630, longitude: 81.4620, altitude: 45.0, timestamp: DateTime.now()),
    GeoLocation(latitude: 6.3635, longitude: 81.4625, altitude: 45.2, timestamp: DateTime.now()),
    GeoLocation(latitude: 6.3640, longitude: 81.4630, altitude: 45.4, timestamp: DateTime.now()),
    GeoLocation(latitude: 6.3645, longitude: 81.4635, altitude: 45.6, timestamp: DateTime.now()),
    GeoLocation(latitude: 6.3650, longitude: 81.4640, altitude: 45.8, timestamp: DateTime.now()),
  ];

  List<GeoLocation> get _currentWaypoints {
    switch (_selectedRoute) {
      case SimulationRoute.elephantBreach:
        return _elephantRouteWaypoints;
      case SimulationRoute.leopardRiver:
        return _leopardRouteWaypoints;
      case SimulationRoute.rapidPings:
        return _rapidPingsWaypoints;
    }
  }

  String get _currentCollarId {
    switch (_selectedRoute) {
      case SimulationRoute.elephantBreach:
      case SimulationRoute.rapidPings:
        return 'COLLAR-001';
      case SimulationRoute.leopardRiver:
        return 'COLLAR-002';
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    _selectedAnimalId = 'ANIMAL-ELE-01';
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  void _startSimulation() {
    if (_isSimulating) return;

    setState(() {
      _isSimulating = true;
      if (_currentStepIndex >= _currentWaypoints.length - 1) {
        _currentStepIndex = 0;
        _simulatedBreadcrumbs = [];
      }
    });

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1600), (timer) {
      if (_currentStepIndex < _currentWaypoints.length) {
        _dispatchNextSimulatedPoint();
      } else {
        _pauseSimulation();
      }
    });
  }

  void _pauseSimulation() {
    _simulationTimer?.cancel();
    setState(() => _isSimulating = false);
  }

  void _resetSimulation() {
    _simulationTimer?.cancel();
    setState(() {
      _isSimulating = false;
      _currentStepIndex = 0;
      _simulatedBreadcrumbs = [];
      _lastTriggeredAlert = null;
    });
  }

  Future<void> _dispatchNextSimulatedPoint() async {
    final pt = _currentWaypoints[_currentStepIndex];
    final now = DateTime.now();

    setState(() {
      _simulatedBreadcrumbs.add(pt);
      _currentStepIndex++;
    });

    // Ingest simulated telemetry ping directly into live pipeline!
    final res = await widget.controller.simulator.telemetryService.ingestGpsTelemetry(
      collarId: _currentCollarId,
      latitude: pt.latitude,
      longitude: pt.longitude,
      altitude: pt.altitude,
      batteryLevel: 86.0 - (_currentStepIndex * 0.2),
      timestamp: now,
    );

    if (res.alert != null) {
      setState(() => _lastTriggeredAlert = res.alert);
      if (res.alert!.riskLevel == AlertRiskLevel.high) {
        AlertSoundService.playHighRiskAlarm();
      }
    }
    await widget.controller.loadData();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final animals = controller.animals;
    final zones = controller.zones;
    final sensors = controller.sensors;
    final alerts = controller.alerts;

    return Scaffold(
      backgroundColor: const Color(0xFF1B2E24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14241C),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.satellite_alt, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text(
              'Live Wildlife Tracking GIS Map',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh telemetry',
            icon: const Icon(Icons.refresh),
            onPressed: controller.loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top telemetry HUD stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF14241C),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHudMetric('Monitored Animals', '${animals.length} tracked'),
                _buildHudMetric('Active Geofences', '${zones.length} zones'),
                _buildHudMetric('Active Alerts', '${controller.activeAlertsCount} active'),
                _buildHudMetric(
                  'Collar Telemetry Status',
                  _isSimulating ? 'TRANSMITTING 🟢' : 'STANDBY ⚪',
                  color: _isSimulating ? Colors.greenAccent : Colors.white70,
                ),
              ],
            ),
          ),

          // Main Map View (Flex 1)
          Expanded(
            child: Stack(
              children: [
                WildlifeConservationMapWidget(
                  zones: zones,
                  animals: animals,
                  sensors: sensors,
                  alerts: alerts,
                  selectedAnimalId: _selectedAnimalId,
                  highlightBreadcrumbs: _simulatedBreadcrumbs,
                  initialZoom: 1.1,
                ),

                // Floating Alert Notification when a breach occurs during simulation
                if (_lastTriggeredAlert != null)
                  Positioned(
                    top: 16,
                    right: 60,
                    left: 60,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_rounded,
                              color: Colors.amberAccent, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'BREACH DETECTED: ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    RiskLevelBadge(
                                      riskLevel: _lastTriggeredAlert!.riskLevel,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _lastTriggeredAlert!.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red.shade900,
                            ),
                            onPressed: () {
                              if (_lastTriggeredAlert!.riskLevel == AlertRiskLevel.high) {
                                AlertSoundService.playHighRiskAlarm();
                              }
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WildlifeAlertDetailPage(
                                    alertId: _lastTriggeredAlert!.alertId,
                                    controller: widget.controller,
                                    rangerId: widget.ranger?.uid ?? widget.rangerId ?? 'RANGER-01',
                                    rangerName: widget.ranger?.displayName ??
                                        widget.ranger?.email ??
                                        widget.rangerName ??
                                        'Ranger',
                                  ),
                                ),
                              );
                            },
                            child: const Text('View Alert', style: TextStyle(fontSize: 11)),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                            onPressed: () => setState(() => _lastTriggeredAlert = null),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Simulation Control Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF14241C),
              border: Border(top: BorderSide(color: Colors.black54)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Route selector
                Row(
                  children: [
                    const Icon(Icons.route, color: Colors.greenAccent, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Simulation Scenario:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButton<SimulationRoute>(
                        value: _selectedRoute,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E3A2B),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        underline: Container(height: 1, color: Colors.greenAccent),
                        items: SimulationRoute.values.map((route) {
                          return DropdownMenuItem(
                            value: route,
                            child: Text(route.label),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedRoute = val;
                              _resetSimulation();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Controls row
                Row(
                  children: [
                    // Play / Pause button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _isSimulating
                            ? Colors.orange.shade800
                            : const Color(0xFF17613F),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSimulating ? _pauseSimulation : _startSimulation,
                      icon: Icon(_isSimulating ? Icons.pause : Icons.play_arrow),
                      label: Text(_isSimulating ? 'Pause' : 'Simulate Movement'),
                    ),
                    const SizedBox(width: 8),

                    // Step single ping button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white30),
                      ),
                      onPressed: _isSimulating ? null : _dispatchNextSimulatedPoint,
                      icon: const Icon(Icons.skip_next, size: 16),
                      label: const Text('Step Ping'),
                    ),
                    const SizedBox(width: 8),

                    // Reset button
                    IconButton(
                      tooltip: 'Reset route',
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: _resetSimulation,
                    ),

                    const Spacer(),

                    // Progress indicator
                    Text(
                      'Waypoint: $_currentStepIndex / ${_currentWaypoints.length}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(
                        value: _currentWaypoints.isNotEmpty
                            ? _currentStepIndex / _currentWaypoints.length
                            : 0,
                        backgroundColor: Colors.white12,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudMetric(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
