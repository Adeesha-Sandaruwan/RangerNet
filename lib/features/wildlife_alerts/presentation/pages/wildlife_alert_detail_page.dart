import 'package:flutter/material.dart';
import '../../domain/models/alert_response.dart';
import '../../domain/models/animal.dart';
import '../../domain/models/sensor.dart';
import '../../domain/models/wildlife_alert.dart';
import '../controllers/wildlife_alert_controller.dart';
import '../dialogs/submit_response_dialog.dart';
import '../widgets/alert_badges.dart';
import '../widgets/location_history_timeline.dart';

class WildlifeAlertDetailPage extends StatefulWidget {
  const WildlifeAlertDetailPage({
    required this.alertId,
    required this.controller,
    required this.rangerId,
    this.rangerName,
    super.key,
  });

  final String alertId;
  final WildlifeAlertController controller;
  final String rangerId;
  final String? rangerName;

  @override
  State<WildlifeAlertDetailPage> createState() =>
      _WildlifeAlertDetailPageState();
}

class _WildlifeAlertDetailPageState extends State<WildlifeAlertDetailPage> {
  WildlifeAlert? _alert;
  Animal? _animal;
  Sensor? _sensor;
  List<AlertResponse> _responses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlertDetails();
  }

  Future<void> _loadAlertDetails() async {
    setState(() => _isLoading = true);
    final alert = await widget.controller.getAlertById(widget.alertId);
    if (alert != null) {
      final animals = widget.controller.animals;
      final animal = animals.cast<Animal?>().firstWhere(
            (a) => a?.id == alert.targetId,
            orElse: () => null,
          );
      final sensors = widget.controller.sensors;
      final sensor = sensors.cast<Sensor?>().firstWhere(
            (s) => s?.id == alert.sensorId,
            orElse: () => null,
          );
      final responses =
          await widget.controller.getResponsesForAlert(alert.alertId);

      if (mounted) {
        setState(() {
          _alert = alert;
          _animal = animal;
          _sensor = sensor;
          _responses = responses;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAcknowledge() async {
    if (_alert == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Acknowledge Alert'),
        content: Text(
          'Mark alert "${_alert!.title}" as ACKNOWLEDGED? This signifies to other rangers that an active response is underway.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF17613F),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Acknowledge'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await widget.controller.acknowledgeAlert(
        alertId: _alert!.alertId,
        rangerId: widget.rangerId,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alert status transitioned to ACKNOWLEDGED.'),
            backgroundColor: Color(0xFF0277BD),
          ),
        );
        _loadAlertDetails();
      }
    }
  }

  Future<void> _handleResolve() async {
    if (_alert == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SubmitResponseDialog(
        alert: _alert!,
        rangerId: widget.rangerId,
        rangerName: widget.rangerName,
      ),
    );

    if (result != null) {
      final success = await widget.controller.resolveAlert(
        alertId: _alert!.alertId,
        rangerId: widget.rangerId,
        actionTaken: result['actionTaken'] as String,
        observations: result['observations'] as String,
        rangerName: widget.rangerName,
        followUpRequired: result['followUpRequired'] as bool? ?? false,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Response logged and alert successfully RESOLVED!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        _loadAlertDetails();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_alert == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Alert Details')),
        body: const Center(child: Text('Alert not found.')),
      );
    }

    final alert = _alert!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F8F3),
        title: Text(
          'Alert #${alert.alertId}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlertDetails,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top status and urgency card
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RiskLevelBadge(riskLevel: alert.riskLevel, isLarge: true),
                            AlertStatusBadge(status: alert.status, isLarge: true),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          alert.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF17613F),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          alert.description,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            _buildInfoChip(
                              Icons.access_time,
                              'Triggered: ${_formatDateTime(alert.triggeredAt)}',
                            ),
                            if (alert.lastUpdatedAt != null)
                              _buildInfoChip(
                                Icons.update,
                                'Last Ping: ${_formatDateTime(alert.lastUpdatedAt!)}',
                              ),
                            _buildInfoChip(
                              alert.triggerType == AlertTriggerType.cameraDetection
                                  ? Icons.camera_alt
                                  : Icons.gps_fixed,
                              alert.triggerType.label,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Animal / Target Information Card
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.pets, color: Color(0xFF17613F)),
                            const SizedBox(width: 8),
                            Text(
                              'Target / Monitored Subject',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        if (_animal != null) ...[
                          _buildDetailRow('Animal Name', _animal!.name),
                          _buildDetailRow('Species', _animal!.species),
                          _buildDetailRow('Collar Sensor ID', _animal!.collarId),
                          _buildDetailRow(
                            'Conservation Risk Profile',
                            _animal!.riskProfile.label,
                          ),
                          if (_animal!.notes != null)
                            _buildDetailRow('Ecology Notes', _animal!.notes!),
                        ] else ...[
                          _buildDetailRow('Target ID', alert.targetId),
                          if (alert.targetName != null)
                            _buildDetailRow('Target Name', alert.targetName!),
                          if (alert.targetSpecies != null)
                            _buildDetailRow('Species/Category', alert.targetSpecies!),
                        ],
                        if (alert.zoneName != null) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow('Breached Zone', alert.zoneName!),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Telemetry / Vision Detection Card
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              alert.triggerType == AlertTriggerType.cameraDetection
                                  ? Icons.camera_enhance
                                  : Icons.satellite_alt,
                              color: const Color(0xFF17613F),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              alert.triggerType == AlertTriggerType.cameraDetection
                                  ? 'Camera Trap Detection Frame'
                                  : 'GPS Collar Telemetry & Coordinates',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        // If Camera Trap Alert: preview detection image and tag
                        if (alert.capturedImageUrl != null ||
                            alert.simulatedDetectionTag != null) ...[
                          if (alert.simulatedDetectionTag != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFC62828)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.warning,
                                      color: Color(0xFFC62828), size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'AI DETECTION TAG: ${alert.simulatedDetectionTag}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFFC62828),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (alert.capturedImageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Image.network(
                                  alert.capturedImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: Icon(Icons.broken_image,
                                          size: 48, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],

                        // Current Coordinates & Sensor Status
                        if (alert.currentLocation != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F8F5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFF17613F).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: Color(0xFF17613F), size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Lat: ${alert.currentLocation!.latitude.toStringAsFixed(5)}, Lon: ${alert.currentLocation!.longitude.toStringAsFixed(5)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (alert.currentLocation!.altitude != null)
                                        Text(
                                          'Altitude: ${alert.currentLocation!.altitude!.toStringAsFixed(1)}m | Sensor: ${alert.sensorId}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (_sensor != null)
                                  Column(
                                    children: [
                                      Icon(
                                        Icons.battery_charging_full,
                                        color: _sensor!.isBatteryCritical
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                      Text(
                                        '${_sensor!.batteryLevel.toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Location Breadcrumb Trail
                        LocationHistoryTimeline(
                          locations: alert.locationHistory,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Response History (if any)
                if (_responses.isNotEmpty) ...[
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.assignment_turned_in,
                                  color: Color(0xFF2E7D32)),
                              const SizedBox(width: 8),
                              Text(
                                'Ranger Response Record',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          ..._responses.map((resp) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          resp.rangerName ?? 'Ranger (${resp.rangerId})',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          _formatDateTime(resp.timestamp),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Action: ${resp.actionTaken}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Observations: ${resp.observations}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade800),
                                    ),
                                    if (resp.followUpRequired)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '⚠️ Requires Follow-up Field Inspection',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Bar
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (alert.isActive) ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0277BD),
                              side: const BorderSide(color: Color(0xFF0277BD)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            onPressed: _handleAcknowledge,
                            icon: const Icon(Icons.visibility),
                            label: const Text('Acknowledge Alert'),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (!alert.isResolved) ...[
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF17613F),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            onPressed: _handleResolve,
                            icon: const Icon(Icons.done_all),
                            label: const Text('Submit Response & Resolve'),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Color(0xFF2E7D32), size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Alert Resolved & Archived',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
