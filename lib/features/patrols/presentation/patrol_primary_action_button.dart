import 'package:flutter/material.dart';

/// Standard full-width primary action with an optional busy indicator.
/// SRP: centralizes the shared action-button presentation.
class PatrolPrimaryActionButton extends StatelessWidget {
  const PatrolPrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  /// Text describing the primary action.
  final String label;
  /// Icon shown when the button is not busy.
  final IconData icon;
  /// Action callback; null disables the button.
  final VoidCallback? onPressed;
  /// Whether to replace the action icon with a progress indicator.
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      icon: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
    ),
  );
}
