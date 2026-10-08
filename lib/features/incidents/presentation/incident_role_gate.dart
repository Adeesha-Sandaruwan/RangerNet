import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/user_role_repository.dart';
import '../domain/ranger_profile.dart';
import 'incident_manager_dashboard_page.dart';
import '../../home/presentation/rangernet_shell.dart';

/// Resolves the authenticated user's trusted Firestore role before routing.
class IncidentRoleGate extends StatefulWidget {
  const IncidentRoleGate({required this.user, super.key});

  final User user;

  @override
  State<IncidentRoleGate> createState() => _IncidentRoleGateState();
}

class _IncidentRoleGateState extends State<IncidentRoleGate> {
  late Future<RangerProfile> _profile;

  @override
  void initState() {
    super.initState();
    _profile = UserRoleRepository().loadOrCreateRangerProfile(widget.user);
  }

  @override
  void didUpdateWidget(covariant IncidentRoleGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _profile = UserRoleRepository().loadOrCreateRangerProfile(widget.user);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<RangerProfile>(
    future: _profile,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('RangerNet access')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    'RangerNet could not load your role. The role-aware '
                    'Firestore rules must be published, and manager accounts '
                    'must be provisioned by a project administrator.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      final profile = snapshot.data!;
      return profile.role == RangerRole.manager
          ? IncidentManagerDashboardPage(manager: profile)
          : RangerNetShell(ranger: widget.user);
    },
  );
}
