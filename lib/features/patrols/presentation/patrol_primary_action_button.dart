import 'package:flutter/material.dart';

class PatrolPrimaryActionButton extends StatelessWidget {
  const PatrolPrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
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
