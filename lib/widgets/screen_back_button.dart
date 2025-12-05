import 'package:flutter/material.dart';

/// A Back button widget that gracefully handles navigation when a screen
/// might be launched both as a pushed route and as a standalone entry point.
class ScreenBackButton extends StatelessWidget {
  const ScreenBackButton({
    super.key,
    this.onPressed,
    this.icon = Icons.arrow_back,
    this.tooltip,
    this.fallbackRoute,
  });

  /// Explicit handler if custom behaviour is required.
  final VoidCallback? onPressed;

  /// Icon to use for the back button. Defaults to [Icons.arrow_back].
  final IconData icon;

  /// Optional tooltip override. Defaults to the Material back tooltip.
  final String? tooltip;

  /// Optional fallback route that will be used if the current navigator
  /// stack cannot be popped.
  final String? fallbackRoute;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip ?? MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () {
        if (onPressed != null) {
          onPressed!();
          return;
        }

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
          return;
        }

        if (fallbackRoute != null && fallbackRoute!.isNotEmpty) {
          Navigator.pushReplacementNamed(context, fallbackRoute!);
        }
      },
    );
  }
}

