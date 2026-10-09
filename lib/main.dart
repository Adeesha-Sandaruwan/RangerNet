import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'features/incidents/presentation/incident_role_gate.dart';
import 'features/incidents/presentation/incident_home_page.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const RangerNetApp());
}

class RangerNetApp extends StatelessWidget {
  const RangerNetApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'RangerNet',
    debugShowCheckedModeBanner: false,
    theme: _buildTheme(),
    home: const _AuthenticationGate(),
  );
}

ThemeData _buildTheme() {
  const green = Color(0xFF17613F);
  const outline = Color(0xFFDCE5DD);
  final scheme = ColorScheme.fromSeed(
    seedColor: green,
    surface: const Color(0xFFF5F8F3),
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF5F8F3),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F8F3),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Color(0xFF16231B),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: outline),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: outline),
      backgroundColor: const Color(0xFFEAF2EC),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: shape,
        side: const BorderSide(color: green),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: Color(0xFF536459)),
      border: border(outline),
      enabledBorder: border(outline),
      focusedBorder: border(green, 2),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: shape,
    ),
    dividerTheme: const DividerThemeData(color: outline),
  );
}

class _AuthenticationGate extends StatelessWidget {
  const _AuthenticationGate();

  @override
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
