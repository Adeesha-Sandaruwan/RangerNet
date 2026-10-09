// Shared sign-out helper for manager screens with nested pages.
import 'package:flutter/widgets.dart';

/// Signs out first, then clears pushed pages so the auth gate can show login.
// Sign out, then clear pushed pages so the auth gate can show the login screen.
Future<void> signOutAndReturnToLogin(
  BuildContext context, {
  required Future<void> Function() signOut,
}) async {
  await signOut();
  if (!context.mounted) return;
  Navigator.of(context).popUntil((route) => route.isFirst);
}
