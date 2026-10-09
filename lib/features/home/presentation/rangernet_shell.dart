import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../incidents/presentation/incident_home_page.dart';
import '../../incidents/presentation/incident_responder_inbox_page.dart';
import '../../patrols/application/patrol_service.dart';
import '../../patrols/application/patrol_sync_service.dart';
import '../../patrols/application/patrol_tracking_service.dart';
import '../../patrols/data/firestore_patrol_assignment_source.dart';
import '../../patrols/data/firestore_patrol_sync_repository.dart';
import '../../patrols/data/geolocator_patrol_location_provider.dart';
import '../../patrols/data/connectivity_patrol_network_status_provider.dart';
import '../../patrols/data/local_patrol_repository.dart';
import '../../patrols/presentation/patrol_home_page.dart';

import '../../wildlife_alerts/data/repositories/wildlife_alert_repository_impl.dart';
import '../../wildlife_alerts/presentation/controllers/wildlife_alert_controller.dart';
import '../../wildlife_alerts/presentation/pages/wildlife_alert_dashboard_page.dart';
import '../../wildlife_alerts/presentation/pages/wildlife_live_tracking_map_page.dart';

/// Navigation container for RangerNet.
/// Hosts UC02 Incident Reporting and UC03 Wildlife Sensor Alerts.
class RangerNetShell extends StatefulWidget {
  const RangerNetShell({required this.ranger, super.key});

  final User ranger;

  @override
  State<RangerNetShell> createState() => _RangerNetShellState();
}

class _RangerNetShellState extends State<RangerNetShell> {
  int _selectedIndex = 0;
  late final WildlifeAlertController _wildlifeAlertController;

  @override
  void initState() {
    super.initState();
    _wildlifeAlertController = WildlifeAlertController(
      repository: WildlifeAlertRepositoryImpl(),
    );
  }

  @override
  void dispose() {
    _wildlifeAlertController.dispose();
    unawaited(_patrolTrackingService.dispose());
    super.dispose();
  }

  late final _patrolService = PatrolService(
    repository: LocalPatrolRepository(),
    assignmentSource: FirestorePatrolAssignmentSource(),
  );
  late final _patrolTrackingService = PatrolTrackingService(
    patrolService: _patrolService,
    locationProvider: const GeolocatorPatrolLocationProvider(),
  );
  late final _patrolSyncService = PatrolSyncService(
    patrolService: _patrolService,
    syncRepository: FirestorePatrolSyncRepository(),
    networkStatus: _patrolNetworkStatus,
  );
  late final _patrolNetworkStatus = ConnectivityPatrolNetworkStatusProvider();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _RangerHomePage(
            ranger: widget.ranger,
            controller: _wildlifeAlertController,
            openAlerts: () => setState(() => _selectedIndex = 1),
            openIncidents: () => setState(() => _selectedIndex = 3),
            openLiveMap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WildlifeLiveTrackingMapPage(
                    controller: _wildlifeAlertController,
                    ranger: widget.ranger,
                  ),
                ),
              );
            },
          ),
          WildlifeAlertDashboardPage(
            ranger: widget.ranger,
            controller: _wildlifeAlertController,
          ),
          PatrolHomePage(
            rangerId: widget.ranger.uid,
            rangerName:
                widget.ranger.displayName ?? widget.ranger.email ?? 'Ranger',
            service: _patrolService,
            trackingService: _patrolTrackingService,
            syncService: _patrolSyncService,
            networkStatus: _patrolNetworkStatus,
          ),
          IncidentHomePage(ranger: widget.ranger),
          IncidentResponderInboxPage(
            rangerId: widget.ranger.uid,
            responderName:
                widget.ranger.displayName ?? widget.ranger.email ?? 'Ranger',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.radar_outlined),
            selectedIcon: Icon(Icons.radar),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Patrols',
          ),
          NavigationDestination(
            icon: Icon(Icons.crisis_alert_outlined),
            selectedIcon: Icon(Icons.crisis_alert),
            label: 'Incidents',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Assigned',
          ),
        ],
      ),
    );
  }
}

class _RangerHomePage extends StatelessWidget {
  const _RangerHomePage({
    required this.ranger,
    required this.controller,
    required this.openAlerts,
    required this.openIncidents,
    required this.openLiveMap,
  });

  final User ranger;
  final WildlifeAlertController controller;
  final VoidCallback openAlerts;
  final VoidCallback openIncidents;
  final VoidCallback openLiveMap;

  @override
  Widget build(BuildContext context) {
    final displayName =
        ranger.displayName ?? ranger.email?.split('@').first ?? 'Ranger';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F3),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF17613F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.forest, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'RangerNet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF81C784)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Yala Sector 1 Online',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: FirebaseAuth.instance.signOut,
            icon: const Icon(Icons.logout, size: 20),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ranger Greeting Header
                _buildHeader(context, displayName),
                const SizedBox(height: 20),

                // FEATURED UC03 COMMAND CARD
                _buildWildlifeAlertsCard(context),
                const SizedBox(height: 16),

                // UC02 INCIDENTS CARD
                _buildIncidentsCard(context),
                const SizedBox(height: 24),

                // Quick Station Telemetry Footer
                _buildQuickMetricsFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String displayName) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF17613F),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'R',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $displayName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF14241C),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Yala National Park • Conservation Ops Center',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWildlifeAlertsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2F20), Color(0xFF174731)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF174731).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF34D399).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: openAlerts,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag & Node Status Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34D399).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFF34D399).withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34D399),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'USE CASE 03 • TELEMETRY ENGINE',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) {
                        final active = controller.activeAlertsCount;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: active > 0
                                ? const Color(
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active > 0
                                  ? const Color(0xFFEF4444)
                                  : Colors.white24,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                active > 0
                                    ? Icons.warning_amber_rounded
                                    : Icons.sensors,
                                size: 13,
                                color: active > 0
                                    ? const Color(0xFFFCA5A5)
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                active > 0
                                    ? '$active ACTIVE ALERT${active > 1 ? "S" : ""}'
                                    : '3 SENSORS ONLINE',
                                style: TextStyle(
                                  color: active > 0
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title & Icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Icon(
                        Icons.radar,
                        color: Color(0xFF34D399),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monitor Wildlife & Sensor Alerts',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Live GPS collars, ray-casting geofence breach detection, camera trap night-vision feeds, and automated ranger dispatch.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Live Sensor Badges Row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildPillTag(
                      '🐘 Raja (Collar-001)',
                      const Color(0xFF10B981),
                    ),
                    _buildPillTag(
                      '🐆 Maya (Collar-002)',
                      const Color(0xFF3B82F6),
                    ),
                    _buildPillTag(
                      '📹 CAM-TRAP-101 (River)',
                      const Color(0xFFA855F7),
                    ),
                    _buildPillTag(
                      '🛡️ 4 Active Geofences',
                      const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Bottom Action Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34D399),
                          foregroundColor: const Color(0xFF062817),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: openAlerts,
                        icon: const Icon(Icons.dashboard_outlined, size: 18),
                        label: const Text(
                          'Open Telemetry Center',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: openLiveMap,
                      icon: const Icon(
                        Icons.map_outlined,
                        size: 18,
                        color: Color(0xFF34D399),
                      ),
                      label: const Text(
                        'Live Map',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIncidentsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: openIncidents,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.crisis_alert,
                    color: Color(0xFF17613F),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Text(
                              'USE CASE 02',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Incident Management',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Report illegal poaching, habitat encroachment, and assign response teams.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillTag(String label, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMetricsFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusDot('GPS Collars', '2 Active', Colors.green),
          _buildStatusDot('Camera Traps', '1 Live', Colors.purple),
          _buildStatusDot('Geofences', '4 Armed', Colors.orange),
          _buildStatusDot('Sync State', 'Real-Time', Colors.teal),
        ],
      ),
    );
  }

  Widget _buildStatusDot(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
