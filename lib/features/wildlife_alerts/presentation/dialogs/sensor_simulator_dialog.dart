import 'package:flutter/material.dart';
import '../../domain/models/wildlife_alert.dart';
import '../../domain/services/wildlife_sensor_simulator.dart';
import '../controllers/wildlife_alert_controller.dart';
import '../services/alert_sound_service.dart';
import '../widgets/camera_trap_live_video_feed_widget.dart';

class SensorSimulatorDialog extends StatefulWidget {
  const SensorSimulatorDialog({required this.controller, super.key});

  final WildlifeAlertController controller;

  @override
  State<SensorSimulatorDialog> createState() => _SensorSimulatorDialogState();
}

class _SensorSimulatorDialogState extends State<SensorSimulatorDialog> {
  SimulationScenarioResult? _lastResult;
  bool _isRunning = false;

  Future<void> _executeScenario(
    String title,
    Future<SimulationScenarioResult> Function(WildlifeSensorSimulator) action,
  ) async {
    setState(() => _isRunning = true);
    try {
      final res = await widget.controller.runSimulationScenario(action);
      setState(() => _lastResult = res);
      final hasHighRiskAlert = res.telemetryResults.any(
        (tr) => tr.alert?.riskLevel == AlertRiskLevel.high,
      );
      if (hasHighRiskAlert) {
        AlertSoundService.playHighRiskAlarm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Simulation error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  void _openCameraLiveFeed(String cameraTrapId, String? tag, String? imageUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 720,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: const Color(0xFF14241C),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.videocam,
                      color: Colors.greenAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Live Video Stream — $cameraTrapId',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              CameraTrapLiveVideoFeedWidget(
                cameraTrapId: cameraTrapId,
                initialImageUrl: imageUrl,
                detectionTag: tag,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.sensors, color: Color(0xFF17613F)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Sensor & Wildlife Telemetry Simulator',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Trigger live mock telemetry events to test geofencing, threat detection, '
                'and alert throttling workflows in real-time.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 16),

              if (_isRunning)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),

              if (_lastResult != null && !_isRunning) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2E7D32)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF2E7D32),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _lastResult!.scenarioName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _lastResult!.description,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Telemetry Events (${_lastResult!.telemetryResults.length}):',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ..._lastResult!.telemetryResults.map(
                        (tr) => Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '• ${tr.message} ${tr.wasThrottled
                                ? "⚡ [THROTTLED/APPENDED]"
                                : tr.alert != null
                                ? "🚨 [NEW ALERT: ${tr.alert!.alertId}]"
                                : "✓ [SAFE]"}',
                            style: TextStyle(
                              fontSize: 11,
                              color: tr.wasThrottled
                                  ? Colors.orange.shade900
                                  : tr.alert != null
                                  ? Colors.red.shade900
                                  : Colors.green.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (_lastResult!.scenarioName.contains(
                        'Camera Trap',
                      )) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF17613F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () {
                            final alert = _lastResult!.telemetryResults
                                .where((r) => r.alert != null)
                                .map((r) => r.alert)
                                .firstOrNull;
                            _openCameraLiveFeed(
                              alert?.sensorId ?? 'CAM-TRAP-101',
                              alert?.simulatedDetectionTag ??
                                  'POACHER_DETECTED',
                              alert?.capturedImageUrl,
                            );
                          },
                          icon: const Icon(Icons.videocam, size: 16),
                          label: const Text(
                            '📹 Open Live Camera Video Feed',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const Text(
                'Available Telemetry Scenarios:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),

              _buildScenarioTile(
                icon: Icons.crisis_alert,
                color: Colors.red,
                title: 'Scenario 1: Elephant Breaches High-Risk Zone',
                subtitle:
                    'Tusker Raja (COLLAR-001) enters Southern Boundary Buffer Zone. Spawns HIGH priority geofence breach alert.',
                onTap: () => _executeScenario(
                  'Elephant Breaches High-Risk Zone',
                  (sim) => sim.simulateElephantBreachingZone(),
                ),
              ),
              _buildScenarioTile(
                icon: Icons.speed,
                color: Colors.orange,
                title: 'Scenario 2: Rapid Pings Throttling Demo',
                subtitle:
                    '3 rapid pings 1-3 mins apart. 1st creates alert; 2nd and 3rd are throttled and appended as location history breadcrumbs.',
                onTap: () => _executeScenario(
                  'Rapid Pings Throttling Demo',
                  (sim) => sim.simulateRapidThrottledPings(),
                ),
              ),
              _buildScenarioTile(
                icon: Icons.shield,
                color: Colors.green,
                title: 'Scenario 3: Normal Movement (Safe Range)',
                subtitle:
                    'Elephant Raja moves in core forest sector. Telemetry is saved with NO alert created.',
                onTap: () => _executeScenario(
                  'Normal Movement',
                  (sim) => sim.simulateSafeMovement(),
                ),
              ),
              _buildScenarioTile(
                icon: Icons.photo_camera,
                color: Colors.deepPurple,
                title: 'Scenario 4: Camera Trap - Poaching / Trespass',
                subtitle:
                    'Camera CAM-TRAP-101 detects unauthorized armed intruders near river trail.',
                onTap: () => _executeScenario(
                  'Camera Trap: Poaching Infiltration',
                  (sim) => sim.simulatePoacherCameraTrap(),
                ),
              ),
              _buildScenarioTile(
                icon: Icons.pets,
                color: Colors.indigo,
                title: 'Scenario 5: Camera Trap - Distressed Wildlife',
                subtitle:
                    'Camera CAM-TRAP-102 flags distressed leopard needing ranger/vet response.',
                onTap: () => _executeScenario(
                  'Camera Trap: Distressed Wildlife',
                  (sim) => sim.simulateDistressedAnimalCameraTrap(),
                ),
              ),
              _buildScenarioTile(
                icon: Icons.timeline,
                color: Colors.teal,
                title: 'Scenario 6: Exact Geofence Boundary Test',
                subtitle:
                    'Collar located precisely on polygon perimeter boundary segment.',
                onTap: () => _executeScenario(
                  'Exact Geofence Boundary Test',
                  (sim) => sim.simulateBoundaryEdgeTest(),
                ),
              ),
              _buildScenarioTile(
                icon: Icons.battery_alert,
                color: Colors.amber.shade900,
                title: 'Scenario 7: Critical Collar Battery (<10%)',
                subtitle:
                    'Collar COLLAR-003 drops to 8.5% battery. Flags low-battery warning.',
                onTap: () => _executeScenario(
                  'Critical Battery Warning',
                  (sim) => sim.simulateCriticalBattery(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildScenarioTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: FilledButton.tonal(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: _isRunning ? null : onTap,
          child: const Text('Trigger', style: TextStyle(fontSize: 11)),
        ),
      ),
    );
  }
}
