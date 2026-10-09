// Checks that signing out clears manager pages and returns to the login screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rangernet/features/incidents/presentation/auth_navigation.dart';

void main() {
  // A successful sign-out should remove any page opened above the login gate.
  testWidgets('sign out clears pushed pages and returns to login', (
    tester,
  ) async {
    await tester.pumpWidget(const _TestGate());
    await tester.tap(find.text('Open incident management'));
    await tester.pumpAndSettle();
    expect(find.text('Incident management page'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Login screen'), findsOneWidget);
    expect(find.text('Incident management page'), findsNothing);
  });

  // If Firebase sign-out fails, keep the user on the page and show the error.
  testWidgets('failed sign out leaves the manager page open', (tester) async {
    await tester.pumpWidget(const _TestGate(failSignOut: true));
    await tester.tap(find.text('Open incident management'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Incident management page'), findsOneWidget);
    expect(find.text('Login screen'), findsNothing);
  });
}

// A small test-only sign-in gate that does not need Firebase.
class _TestGate extends StatefulWidget {
  const _TestGate({this.failSignOut = false});

  final bool failSignOut;

  @override
  State<_TestGate> createState() => _TestGateState();
}

class _TestGateState extends State<_TestGate> {
  bool _signedIn = true;

  // Pretend to sign out, or throw when testing the error case.
  Future<void> _signOut() async {
    if (widget.failSignOut) throw StateError('Simulated sign-out failure');
    setState(() => _signedIn = false);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: _signedIn
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Manager dashboard'),
                    TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => _ManagerPage(onSignOut: _signOut),
                        ),
                      ),
                      child: const Text('Open incident management'),
                    ),
                  ],
                )
              : const Text('Login screen'),
        ),
      ),
    ),
  );
}

// Fake manager page used to trigger the shared sign-out helper in tests.
class _ManagerPage extends StatelessWidget {
  const _ManagerPage({required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Incident management page'),
          TextButton(
            onPressed: () async {
              try {
                await signOutAndReturnToLogin(context, signOut: onSignOut);
              } on StateError {
                // Keep the page visible when sign-out fails.
              }
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    ),
  );
}
