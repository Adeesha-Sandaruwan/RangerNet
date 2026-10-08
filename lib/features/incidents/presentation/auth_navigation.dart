import 'package:flutter/widgets.dart';

/// Signs out first, then clears pushed pages so the auth gate can show login.
Future<void> signOutAndReturnToLogin(
  BuildContext context, {
  required Future<void> Function() signOut,
}) async {
  await signOut();
  if (!context.mounted) return;
  Navigator.of(context).popUntil((route) => route.isFirst);
}
