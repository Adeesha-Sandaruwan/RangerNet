import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../incidents/presentation/incident_home_page.dart';
import '../../incidents/presentation/incident_responder_inbox_page.dart';

import '../../wildlife_alerts/data/repositories/wildlife_alert_repository_impl.dart';
import '../../wildlife_alerts/presentation/controllers/wildlife_alert_controller.dart';
import '../../wildlife_alerts/presentation/pages/wildlife_alert_dashboard_page.dart';

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _RangerHomePage(
            ranger: widget.ranger,
            openAlerts: () => setState(() => _selectedIndex = 1),
            openIncidents: () => setState(() => _selectedIndex = 2),
          ),
          WildlifeAlertDashboardPage(
            ranger: widget.ranger,
            controller: _wildlifeAlertController,
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
    required this.openAlerts,
    required this.openIncidents,
  });

  final User ranger;
  final VoidCallback openAlerts;
  final VoidCallback openIncidents;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F8F3),
    appBar: AppBar(
      title: const Text('RangerNet'),
      backgroundColor: const Color(0xFFF5F8F3),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: FirebaseAuth.instance.signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.forest, size: 54, color: Color(0xFF17613F)),
              const SizedBox(height: 18),
              Text(
                'Welcome to RangerNet',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text('Signed in as ${ranger.email ?? 'ranger'}'),
              const SizedBox(height: 18),
              const Text(
                'Monitor wildlife sensor telemetry, geofence breaches, and report '
                'illegal poaching incidents with real-time field synchronization.',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF17613F),
                ),
                onPressed: openAlerts,
                icon: const Icon(Icons.radar),
                label: const Text('UC03: Monitor Wildlife & Sensor Alerts'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: openIncidents,
                icon: const Icon(Icons.crisis_alert),
                label: const Text('Incident reporting (Incidents tab)'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
