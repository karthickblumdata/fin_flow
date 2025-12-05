import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ActionPillButton extends StatelessWidget {
  const ActionPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.enabled = true,
    this.dense = false,
    this.filled = true,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool dense;
   final bool filled;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = enabled ? onPressed : null;
    final Color activeColor = color;
    final bool isFilled = filled;

    Color resolveForegroundColor(Set<MaterialState> states) {
      if (states.contains(MaterialState.disabled)) {
        return activeColor.withOpacity(0.45);
      }
      return activeColor;
    }

    Color? resolveOverlayColor(Set<MaterialState> states) {
      if (states.contains(MaterialState.disabled)) {
        return Colors.transparent;
      }
      if (states.contains(MaterialState.pressed)) {
        return activeColor.withOpacity(isFilled ? 0.16 : 0.12);
      }
      if (states.contains(MaterialState.hovered) ||
          states.contains(MaterialState.focused)) {
        return activeColor.withOpacity(isFilled ? 0.1 : 0.06);
      }
      return null;
    }

    final textStyle = AppTheme.bodySmall.copyWith(
      fontWeight: isFilled ? FontWeight.w600 : FontWeight.w500,
      letterSpacing: 0.1,
    );

    final horizontalPadding = dense ? 8.0 : 10.0;
    final verticalPadding = dense ? 4.0 : 6.0;

    return TextButton.icon(
      onPressed: effectiveOnPressed,
      icon: Icon(
        icon,
        size: dense ? 14 : 16,
      ),
      label: Text(
        label,
        style: textStyle,
      ),
      style: ButtonStyle(
        minimumSize: MaterialStateProperty.all(Size.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: MaterialStateProperty.all(
          EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
        ),
        backgroundColor: MaterialStateProperty.all(Colors.transparent),
        foregroundColor:
            MaterialStateProperty.resolveWith(resolveForegroundColor),
        overlayColor:
            MaterialStateProperty.resolveWith(resolveOverlayColor),
        shape: MaterialStateProperty.all(
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
        visualDensity:
            dense ? VisualDensity.compact : VisualDensity.standard,
      ),
    );
  }
}

