// Starts Firebase before Flutter shows the app and routes signed-in users.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'features/incidents/presentation/incident_role_gate.dart';
import 'features/incidents/presentation/incident_home_page.dart';
import 'firebase_options.dart';

/// Starts Firebase, then opens the RangerNet app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const RangerNetApp());
}

/// Builds the shared app theme and opens the sign-in routing gate.
class RangerNetApp extends StatelessWidget {
  const RangerNetApp({super.key});

  @override
  // Flutter calls build whenever it needs to draw this widget.
  Widget build(BuildContext context) => MaterialApp(
    title: 'RangerNet',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF17613F),
        surface: const Color(0xFFF5F8F3),
      ),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: Color(0xFF536459)),
      ),
    ),
    home: const _AuthenticationGate(),
  );
}

/// Watches sign-in changes and chooses the login or role-based screen.
class _AuthenticationGate extends StatelessWidget {
  const _AuthenticationGate();

  @override
  // Wait for Firebase, then show login or load the signed-in user's role.
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = snapshot.data;
      return user == null
          ? const RangerNetLoginPage()
          : IncidentRoleGate(user: user);
    },
  );
}
