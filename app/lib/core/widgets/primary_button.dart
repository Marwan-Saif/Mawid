import 'package:flutter/material.dart';

/// The main call to action. Shows a spinner while [loading] and ignores taps meanwhile.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Theme.of(context).colorScheme.onPrimary),
          )
        : Text(label);
    final button = icon == null || loading
        ? FilledButton(onPressed: loading ? null : onPressed, child: child)
        : FilledButton.icon(onPressed: onPressed, icon: Icon(icon, size: 20), label: child);
    return Semantics(button: true, enabled: onPressed != null && !loading, label: label, excludeSemantics: true, child: button);
  }
}
