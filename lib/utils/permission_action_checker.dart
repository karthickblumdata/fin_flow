import '../services/auth_service.dart';
import 'ui_permission_checker.dart';

/// Utility class to check if user can perform specific actions
/// based on their permissions
class PermissionActionChecker {
  /// Check if user can perform a specific action on a section
  /// 
  /// [section] - e.g., 'dashboard', 'all_users.user_management', 'wallet.self.transaction'
  /// [action] - e.g., 'create', 'edit', 'delete', 'approve', 'reject', 'flag', 'export', 'view'
  /// 
  /// Returns true if:
  /// 1. User is Super Admin (always has access)
  /// 2. User has parent permission (e.g., 'dashboard' grants all actions)
  /// 3. User has specific action permission (e.g., 'dashboard.create')
  static Future<bool> canPerformAction(String section, String action) async {
    // Super Admin always has access
    if (await UIPermissionChecker.isSuperAdmin()) {
      return true;
    }
    
    // Check if user has parent permission (grants all actions)
    if (await UIPermissionChecker.hasPermission(section)) {
      return true;
    }
    
    // Check if user has specific action permission
    final actionPermission = '$section.$action';
    return await UIPermissionChecker.hasPermission(actionPermission);
  }
  
  /// Get all allowed actions for a section
  /// Returns a set of action strings that the user can perform
  static Future<Set<String>> getAllowedActions(String section) async {
    final allowedActions = <String>{};
    
    // Check each action type
    final actions = ['create', 'edit', 'delete', 'approve', 'unapprove', 'reject', 'flag', 'export', 'view'];
    
    for (final action in actions) {
      if (await canPerformAction(section, action)) {
        allowedActions.add(action);
      }
    }
    
    return allowedActions;
  }
  
  /// Check if user has full access to a section (parent permission)
  /// This means user can perform all actions in that section
  static Future<bool> hasFullAccess(String section) async {
    if (await UIPermissionChecker.isSuperAdmin()) {
      return true;
    }
    
    return await UIPermissionChecker.hasPermission(section);
  }
  
  /// Check if user can only view (read-only access)
  /// Returns true if user has view permission but not full access
  static Future<bool> canOnlyView(String section) async {
    if (await UIPermissionChecker.isSuperAdmin()) {
      return false; // Super Admin has full access, not read-only
    }
    
    final hasView = await canPerformAction(section, 'view');
    final hasFull = await hasFullAccess(section);
    
    return hasView && !hasFull;
  }
  
  /// Check if user can create items in a section
  static Future<bool> canCreate(String section) async {
    return await canPerformAction(section, 'create');
  }
  
  /// Check if user can edit items in a section
  static Future<bool> canEdit(String section) async {
    return await canPerformAction(section, 'edit');
  }
  
  /// Check if user can delete items in a section
  static Future<bool> canDelete(String section) async {
    // Also check for 'remove' action (used in some sections)
    return await canPerformAction(section, 'delete') || 
           await canPerformAction(section, 'remove');
  }
  
  /// Check if user can approve items in a section
  static Future<bool> canApprove(String section) async {
    return await canPerformAction(section, 'approve');
  }
  
  /// Check if user can unapprove items in a section
  /// Note: Unapprove typically uses the same permission as approve
  static Future<bool> canUnapprove(String section) async {
    // Unapprove uses the same permission as approve
    return await canPerformAction(section, 'unapprove') || 
           await canPerformAction(section, 'approve');
  }
  
  /// Check if user can reject items in a section
  static Future<bool> canReject(String section) async {
    return await canPerformAction(section, 'reject');
  }
  
  /// Check if user can flag items in a section
  static Future<bool> canFlag(String section) async {
    return await canPerformAction(section, 'flag');
  }
  
  /// Check if user can export items in a section
  static Future<bool> canExport(String section) async {
    return await canPerformAction(section, 'export');
  }
  
  /// Check if user can view items in a section
  static Future<bool> canView(String section) async {
    return await canPerformAction(section, 'view');
  }
}

