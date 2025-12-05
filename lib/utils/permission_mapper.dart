import 'package:flutter/material.dart';

class PermissionMapper {
  // Map navigation items to their required permission IDs
  static const Map<String, List<String>> navigationPermissions = {
    'dashboard': ['dashboard', 'dashboard.view'],
    'wallet_self': [
      'wallet.self.transaction.view',
      'wallet.self.collection.view',
      'wallet.self.expenses.transaction.view',
    ],
    'wallet_all': [
      'wallet.all.transaction.view',
      'wallet.all.collection.view',
      'wallet.all.expenses.view',
    ],
    'smart_approvals': [
      'smart_approvals.transaction.view',
      'smart_approvals.collection.view',
      'smart_approvals.expenses.view',
    ],
    'all_users': [
      'all_users.user_management.view',
      'all_users.roles.view',
    ],
    'accounts': ['accounts.payment_account_reports.view'],
    'expenses': [
      'expenses.expenses_type.view',
      'expenses.expenses_report.view',
    ],
    'quick_actions': ['dashboard.quick_actions.enable'],
  };

  /// Get visible navigation items based on selected permissions
  static List<String> getVisibleNavigationItems(List<String> permissionIds) {
    final visibleItems = <String>[];

    navigationPermissions.forEach((itemKey, requiredPermissions) {
      // Check if user has at least one of the required permissions
      final hasAccess = requiredPermissions.any((permission) {
        // Check exact match or parent permission
        return permissionIds.contains(permission) ||
            permissionIds.any((p) => p.startsWith(permission.split('.').take(2).join('.')));
      });

      if (hasAccess) {
        visibleItems.add(itemKey);
      }
    });

    return visibleItems;
  }

  /// Get navigation item label
  static String getNavigationItemLabel(String itemKey) {
    switch (itemKey) {
      case 'dashboard':
        return 'Dashboard';
      case 'wallet_self':
        return 'Wallet (Self Wallet)';
      case 'wallet_all':
        return 'Wallet (All User Wallets)';
      case 'smart_approvals':
        return 'Smart Approvals';
      case 'all_users':
        return 'All Users';
      case 'accounts':
        return 'Accounts';
      case 'expenses':
        return 'Expenses';
      case 'quick_actions':
        return 'Quick Actions';
      default:
        return itemKey;
    }
  }

  /// Get navigation item icon
  static IconData getNavigationItemIcon(String itemKey) {
    switch (itemKey) {
      case 'dashboard':
        return Icons.dashboard_outlined;
      case 'wallet_self':
      case 'wallet_all':
        return Icons.account_balance_wallet_outlined;
      case 'smart_approvals':
        return Icons.settings_outlined;
      case 'all_users':
        return Icons.people_outlined;
      case 'accounts':
        return Icons.account_balance_outlined;
      case 'expenses':
        return Icons.receipt_long_outlined;
      case 'quick_actions':
        return Icons.flash_on_outlined;
      default:
        return Icons.help_outline;
    }
  }

  /// Get all available navigation items
  static List<String> getAllNavigationItems() {
    return navigationPermissions.keys.toList();
  }

  /// Check if a specific navigation item should be visible
  static bool shouldShowNavigationItem(String itemKey, List<String> permissionIds) {
    final requiredPermissions = navigationPermissions[itemKey] ?? [];
    if (requiredPermissions.isEmpty) return false;

    // Check if user has at least one of the required permissions
    return requiredPermissions.any((permission) {
      return permissionIds.contains(permission) ||
          permissionIds.any((p) => p.startsWith(permission.split('.').take(2).join('.')));
    });
  }
}

