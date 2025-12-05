import 'package:flutter/material.dart';
import '../utils/permission_action_checker.dart';

/// A button that automatically shows/hides based on user permissions
/// 
/// Example:
/// ```dart
/// PermissionAwareButton(
///   section: 'all_users.user_management',
///   action: 'create',
///   onPressed: () => _handleAdd(),
///   child: ElevatedButton(
///     child: Text('Add User'),
///   ),
/// )
/// ```
class PermissionAwareButton extends StatelessWidget {
  final String section;
  final String action;
  final Widget child;
  final VoidCallback? onPressed;
  final bool showWhenDisabled;
  final String? disabledTooltip;
  
  const PermissionAwareButton({
    super.key,
    required this.section,
    required this.action,
    required this.child,
    this.onPressed,
    this.showWhenDisabled = false,
    this.disabledTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: PermissionActionChecker.canPerformAction(section, action),
      builder: (context, snapshot) {
        final hasPermission = snapshot.data ?? false;
        
        // If no permission and not showing disabled, hide button
        if (!hasPermission && !showWhenDisabled) {
          return const SizedBox.shrink();
        }
        
        // If no permission but showing disabled, show disabled button with tooltip
        if (!hasPermission && showWhenDisabled) {
          return Tooltip(
            message: disabledTooltip ?? 'You do not have permission to perform this action',
            child: AbsorbPointer(
              child: Opacity(
                opacity: 0.5,
                child: child,
              ),
            ),
          );
        }
        
        // Has permission - show enabled button
        // If child is a button with onPressed, we need to wrap it
        if (child is ElevatedButton || child is OutlinedButton || child is TextButton) {
          return _wrapButtonWithPermission(child, onPressed);
        }
        
        // For other widgets, just return as-is
        return child;
      },
    );
  }
  
  Widget _wrapButtonWithPermission(Widget button, VoidCallback? callback) {
    if (button is ElevatedButton) {
      return ElevatedButton(
        onPressed: callback,
        style: button.style,
        child: button.child,
      );
    } else if (button is OutlinedButton) {
      return OutlinedButton(
        onPressed: callback,
        style: button.style,
        child: button.child,
      );
    } else if (button is TextButton) {
      return TextButton(
        onPressed: callback,
        style: button.style,
        child: button.child,
      );
    }
    return button;
  }
}

/// A button that automatically shows/hides based on user permissions
/// Optimized for IconButton
class PermissionAwareIconButton extends StatelessWidget {
  final String section;
  final String action;
  final VoidCallback? onPressed;
  final Icon icon;
  final String? tooltip;
  final Color? color;
  final bool showWhenDisabled;
  final String? disabledTooltip;
  
  const PermissionAwareIconButton({
    super.key,
    required this.section,
    required this.action,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.showWhenDisabled = false,
    this.disabledTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: PermissionActionChecker.canPerformAction(section, action),
      builder: (context, snapshot) {
        final hasPermission = snapshot.data ?? false;
        
        // If no permission and not showing disabled, hide button
        if (!hasPermission && !showWhenDisabled) {
          return const SizedBox.shrink();
        }
        
        // If no permission but showing disabled, show disabled button
        if (!hasPermission && showWhenDisabled) {
          return Tooltip(
            message: disabledTooltip ?? 'You do not have permission to perform this action',
            child: IconButton(
              icon: icon,
              onPressed: null,
              color: color?.withOpacity(0.5),
              tooltip: tooltip,
            ),
          );
        }
        
        // Has permission - show enabled button
        return IconButton(
          icon: icon,
          onPressed: onPressed,
          color: color,
          tooltip: tooltip,
        );
      },
    );
  }
}

/// A FloatingActionButton that automatically shows/hides based on user permissions
class PermissionAwareFAB extends StatelessWidget {
  final String section;
  final String action;
  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;
  final Color? backgroundColor;
  final bool showWhenDisabled;
  final String? disabledTooltip;
  
  const PermissionAwareFAB({
    super.key,
    required this.section,
    required this.action,
    required this.child,
    this.onPressed,
    this.tooltip,
    this.backgroundColor,
    this.showWhenDisabled = false,
    this.disabledTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: PermissionActionChecker.canPerformAction(section, action),
      builder: (context, snapshot) {
        final hasPermission = snapshot.data ?? false;
        
        // If no permission and not showing disabled, hide button
        if (!hasPermission && !showWhenDisabled) {
          return const SizedBox.shrink();
        }
        
        // If no permission but showing disabled, show disabled button
        if (!hasPermission && showWhenDisabled) {
          return Tooltip(
            message: disabledTooltip ?? 'You do not have permission to perform this action',
            child: FloatingActionButton(
              onPressed: null,
              backgroundColor: backgroundColor?.withOpacity(0.5),
              child: child,
              tooltip: tooltip,
            ),
          );
        }
        
        // Has permission - show enabled button
        return FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: backgroundColor,
          child: child,
          tooltip: tooltip,
        );
      },
    );
  }
}

