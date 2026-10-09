import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../domain/models/wildlife_alert.dart';
import '../controllers/wildlife_alert_controller.dart';
import '../dialogs/sensor_simulator_dialog.dart';
import '../services/alert_sound_service.dart';
import '../widgets/alert_badges.dart';
import 'wildlife_alert_detail_page.dart';
import 'wildlife_live_tracking_map_page.dart';

class WildlifeAlertDashboardPage extends StatefulWidget {
  const WildlifeAlertDashboardPage({
    required this.ranger,
    required this.controller,
    super.key,
  });

  final User ranger;
  final WildlifeAlertController controller;

  @override
  State<WildlifeAlertDashboardPage> createState() =>
      _WildlifeAlertDashboardPageState();
}

class _WildlifeAlertDashboardPageState
    extends State<WildlifeAlertDashboardPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _openSimulatorDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => SensorSimulatorDialog(controller: widget.controller),
    );
  }

  void _openLiveMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WildlifeLiveTrackingMapPage(
          ranger: widget.ranger,
          controller: widget.controller,
        ),
      ),
    );
  }

  void _openDetailPage(String alertId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WildlifeAlertDetailPage(
          alertId: alertId,
          controller: widget.controller,
          rangerId: widget.ranger.uid,
          rangerName: widget.ranger.displayName ?? widget.ranger.email,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final alerts = controller.filteredAlerts;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F8F3),
        title: const Row(
          children: [
            Icon(Icons.radar, color: Color(0xFF17613F)),
            SizedBox(width: 8),
            Text(
              'Wildlife Sensor Alerts',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Online / Offline indicator
          InkWell(
            onTap: controller.toggleOnlineStatus,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: controller.isOnline
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: controller.isOnline
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    controller.isOnline ? Icons.cloud_done : Icons.cloud_off,
                    size: 14,
                    color: controller.isOnline
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    controller.isOnline ? 'Online' : 'Offline Mode',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: controller.isOnline
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Live GIS Tracking Map',
            icon: const Icon(Icons.map_outlined, color: Color(0xFF17613F)),
            onPressed: _openLiveMap,
          ),
          IconButton(
            tooltip: 'Live Sensor Simulator',
            icon: const Icon(Icons.sensors, color: Color(0xFF17613F)),
            onPressed: _openSimulatorDialog,
          ),
          IconButton(
            tooltip: 'Refresh telemetry',
            icon: const Icon(Icons.refresh),
            onPressed: controller.loadData,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: RefreshIndicator(
            onRefresh: controller.loadData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Metrics overview banner
                _buildMetricsRow(controller),
                const SizedBox(height: 16),

                // Simulator CTA Banner
                _buildSimulatorBanner(),
                const SizedBox(height: 16),

                // Filters bar
                _buildFiltersBar(controller),
                const SizedBox(height: 16),

                // Error banner if any
                if (controller.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF9A9A)),
                    ),
                    child: Text(
                      controller.errorMessage!,
                      style: const TextStyle(color: Color(0xFFC62828)),
                    ),
                  ),
                ],

                // List of alert cards
                if (controller.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (alerts.isEmpty)
                  _buildEmptyState()
                else
                  ...alerts.map((alert) => _buildAlertCard(alert)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsRow(WildlifeAlertController controller) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            label: 'Active Alerts',
            value: '${controller.activeAlertsCount}',
            color: const Color(0xFFD84315),
            icon: Icons.notifications_active,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            label: 'High Risk Active',
            value: '${controller.highRiskActiveCount}',
            color: const Color(0xFFC62828),
            icon: Icons.warning_amber_rounded,
            onTap: () {
              AlertSoundService.playHighRiskAlarm();
              controller.setRiskFilter(
                controller.filterRisk == AlertRiskLevel.high
                    ? null
                    : AlertRiskLevel.high,
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            label: 'Acknowledged',
            value: '${controller.acknowledgedAlertsCount}',
            color: const Color(0xFF0277BD),
            icon: Icons.visibility,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            label: 'Resolved',
            value: '${controller.resolvedAlertsCount}',
            color: const Color(0xFF2E7D32),
            icon: Icons.check_circle,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: onTap != null
          ? InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: content,
            )
          : content,
    );
  }

  Widget _buildSimulatorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF17613F).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF17613F).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.sensors, color: Color(0xFF17613F), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sensor Telemetry & Scenario Simulator',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF17613F),
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Simulate collar movements, geofence breaches, throttling pings, or camera traps.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF17613F),
                  side: const BorderSide(color: Color(0xFF17613F)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                onPressed: _openLiveMap,
                icon: const Icon(Icons.map, size: 14),
                label: const Text('Live Map', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF17613F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: _openSimulatorDialog,
                child: const Text('Simulator', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar(WildlifeAlertController controller) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Filters:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            ChoiceChip(
              label: const Text('All Alerts', style: TextStyle(fontSize: 11)),
              selected:
                  controller.filterStatus == null &&
                  controller.filterRisk == null,
              onSelected: (_) {
                controller.setStatusFilter(null);
                controller.setRiskFilter(null);
              },
            ),
            ChoiceChip(
              label: const Text('Active', style: TextStyle(fontSize: 11)),
              selected: controller.filterStatus == AlertStatus.active,
              onSelected: (_) => controller.setStatusFilter(
                controller.filterStatus == AlertStatus.active
                    ? null
                    : AlertStatus.active,
              ),
            ),
            ChoiceChip(
              label: const Text('Acknowledged', style: TextStyle(fontSize: 11)),
              selected: controller.filterStatus == AlertStatus.acknowledged,
              onSelected: (_) => controller.setStatusFilter(
                controller.filterStatus == AlertStatus.acknowledged
                    ? null
                    : AlertStatus.acknowledged,
              ),
            ),
            ChoiceChip(
              label: const Text('Resolved', style: TextStyle(fontSize: 11)),
              selected: controller.filterStatus == AlertStatus.resolved,
              onSelected: (_) => controller.setStatusFilter(
                controller.filterStatus == AlertStatus.resolved
                    ? null
                    : AlertStatus.resolved,
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text(
                'High Risk Only',
                style: TextStyle(fontSize: 11),
              ),
              selected: controller.filterRisk == AlertRiskLevel.high,
              onSelected: (_) {
                if (controller.filterRisk != AlertRiskLevel.high) {
                  AlertSoundService.playHighRiskAlarm();
                }
                controller.setRiskFilter(
                  controller.filterRisk == AlertRiskLevel.high
                      ? null
                      : AlertRiskLevel.high,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(WildlifeAlert alert) {
    final hasMultiplePings = alert.locationHistory.length > 1;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: alert.isActive && alert.riskLevel == AlertRiskLevel.high
              ? const Color(0xFFC62828).withValues(alpha: 0.5)
              : Colors.grey.shade300,
          width: alert.isActive && alert.riskLevel == AlertRiskLevel.high
              ? 1.5
              : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (alert.riskLevel == AlertRiskLevel.high) {
            AlertSoundService.playHighRiskAlarm();
          }
          _openDetailPage(alert.alertId);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        alert.triggerType == AlertTriggerType.cameraDetection
                        ? Colors.purple.shade50
                        : const Color(0xFFE8F5E9),
                    child: Icon(
                      alert.triggerType == AlertTriggerType.cameraDetection
                          ? Icons.camera_alt
                          : Icons.satellite_alt,
                      color:
                          alert.triggerType == AlertTriggerType.cameraDetection
                          ? Colors.purple.shade800
                          : const Color(0xFF17613F),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              alert.targetName ?? 'Sensor ${alert.sensorId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (alert.targetSpecies != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '(${alert.targetSpecies})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          alert.title,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RiskLevelBadge(riskLevel: alert.riskLevel),
                      const SizedBox(height: 4),
                      AlertStatusBadge(status: alert.status),
                    ],
                  ),
                ],
              ),
              const Divider(height: 18),

              // Footer row with badges and time
              Row(
                children: [
                  if (alert.zoneName != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        alert.zoneName!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (hasMultiplePings) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.route,
                            size: 11,
                            color: Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${alert.locationHistory.length} pings (throttled)',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimeAgo(alert.triggeredAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 56,
            color: Colors.green.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No matching alerts in queue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'All monitored wildlife and sensor perimeters are within safe thresholds.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
