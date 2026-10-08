import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/ranger_profile.dart';
import '../../conservation_reports/presentation/conservation_report_page.dart';
import 'incident_manager_inbox_page.dart';

/// Landing page shown only to authenticated Park Manager accounts.
class IncidentManagerDashboardPage extends StatelessWidget {
  const IncidentManagerDashboardPage({required this.manager, super.key});

  final RangerProfile manager;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F8F3),
    appBar: AppBar(
      title: const Text('RangerNet Manager'),
      backgroundColor: const Color(0xFFF5F8F3),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: () => FirebaseAuth.instance.signOut(),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.nature_people_outlined, size: 56),
            const SizedBox(height: 12),
            Text(
              'Welcome, ${manager.displayName}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Open incident management to review ranger reports, view their '
              'evidence, assign responders, and manage incident outcomes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.crisis_alert_outlined, size: 38),
                    const SizedBox(height: 10),
                    Text(
                      'Wildlife and poaching incidents',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Review submitted reports and coordinate the response.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              IncidentManagerInboxPage(manager: manager),
                        ),
                      ),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('Go to incident management'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.analytics_outlined, size: 38,
                        color: Color(0xFF17613F)),
                    const SizedBox(height: 10),
                    Text(
                      'Conservation reports',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Analyse conservation data and generate reports on '
                      'poaching hotspots, patrol coverage, wildlife conflicts, '
                      'incident trends, and conservation outcomes.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF17613F),
                      ),
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ConservationReportPage(manager: manager),
                        ),
                      ),
                      icon: const Icon(Icons.assessment_outlined),
                      label: const Text('Go to conservation reports'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

