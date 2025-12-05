import '../services/auth_service.dart';
import '../services/permission_service.dart';

/// Utility to check if user can access specific screens/features
/// Super Admin always has access to everything
class UIPermissionChecker {
  /// Check if user has permission to view a screen
  /// Returns true if user is Super Admin (always has access)
  /// Returns true if user has ANY permission related to that screen section
  /// (e.g., if user has 'dashboard.create' or 'dashboard.edit', they can access dashboard)
  /// Returns true if permission not mapped (backwards compatibility)
  static Future<bool> canViewScreen(String screenKey) async {
    // Check if user is Super Admin first
    final userRole = await AuthService.getUserRole();
    if (userRole == 'SuperAdmin' || userRole == 'Super Admin') {
      return true; // Super Admin always has access to everything
    }
    
    // Get user permissions
    final permissions = await AuthService.getUserPermissions();
    
    // Enhanced debug logging for first few checks
    // Note: Logs dashboard checks, empty permissions, or when permissions count is low
    if (screenKey == 'dashboard' || permissions.isEmpty || permissions.length <= 10) {
      print('\n🔐 ===== PERMISSION CHECK =====');
      print('   Screen Key: $screenKey');
      print('   User Role: $userRole');
      print('   Permissions Count: ${permissions.length}');
      print('   Permissions: $permissions');
    }
    
    // Debug logging (only log once per check to avoid spam)
    if (screenKey == 'dashboard' && permissions.isEmpty) {
      print('⚠️  WARNING: User has no permissions stored. Screen: $screenKey');
      print('   User Role: $userRole');
      print('   Stored Permissions Count: ${permissions.length}');
    }
    
    // Check if user has special '*' permission (all access - Super Admin)
    if (permissions.contains('*')) {
      if (screenKey == 'dashboard' || permissions.isEmpty || permissions.length <= 10) {
        print('   ✅ Access granted: User has "*" permission (all access)');
        print('================================\n');
      }
      return true; // All permissions granted
    }
    
    // Map screen keys to permission section prefixes
    final permissionMap = _getScreenPermissionMap();
    final sectionPrefixMap = _getScreenSectionPrefixMap();
    
    final requiredPermission = permissionMap[screenKey];
    final sectionPrefix = sectionPrefixMap[screenKey];
    
    if (requiredPermission == null && sectionPrefix == null) {
      // If screen not mapped, allow access (backwards compatibility)
      if (screenKey == 'dashboard' || permissions.isEmpty || permissions.length <= 10) {
        print('   ✅ Access granted: Screen not mapped (backwards compatibility)');
        print('================================\n');
      }
      return true;
    }
    
    // First, check if user has the exact required permission (e.g., 'dashboard.view')
    if (requiredPermission != null) {
      final hasExactPermission = _hasPermission(permissions, requiredPermission);
      if (hasExactPermission) {
        if (screenKey == 'dashboard' || permissions.isEmpty || permissions.length <= 10) {
          print('   ✅ Access granted: User has exact permission ($requiredPermission)');
          print('================================\n');
        }
        return true;
      }
    }
    
    // If user doesn't have exact permission, check if they have ANY permission in that section
    // This allows access if user has 'dashboard.create', 'dashboard.edit', etc.
    if (sectionPrefix != null) {
      final hasAnyPermissionInSection = permissions.any((p) => 
        p == sectionPrefix || p.startsWith('$sectionPrefix.')
      );
      
      if (hasAnyPermissionInSection) {
        if (screenKey == 'dashboard' || permissions.isEmpty || permissions.length <= 10) {
          print('   ✅ Access granted: User has permission in section ($sectionPrefix)');
          print('================================\n');
        }
        return true;
      }
    }
    
    // Log permission check result for debugging
    if (screenKey == 'dashboard' || permissions.isEmpty || permissions.length <= 10) {
      print('   Required Permission: $requiredPermission');
      print('   Section Prefix: $sectionPrefix');
      print('   Has Access: ❌ NO');
      print('   ❌ Permission Check Failed:');
      print('   User Permissions: $permissions');
      print('   User Role: $userRole');
      print('================================\n');
    }
    
    return false;
  }
  
  /// Map screen keys to permission section prefixes
  /// This allows checking if user has ANY permission in that section
  static Map<String, String> _getScreenSectionPrefixMap() {
    return {
      // Dashboard - check for any 'dashboard' permission
      'dashboard': 'dashboard',
      // Wallet screens - check for any 'wallet' permission
      'wallet': 'wallet',
      'wallet-self': 'wallet.self',
      'wallet-all': 'wallet.all',
      'all-user-wallets': 'wallet.all',
      // Smart Approvals - check for any 'smart_approvals' permission
      'smart_approvals': 'smart_approvals',
      'smart-approvals': 'smart_approvals',
      'pending-approvals': 'smart_approvals',
      // User Management - check for any 'all_users' permission
      'manage-users': 'all_users',
      'users': 'all_users',
      'roles': 'all_users.roles',
      // Payment Accounts - check for any 'accounts' or 'settings' permission
      'payment-modes': 'accounts',
      'paymentModes': 'accounts',
      'account-reports': 'accounts',
      'accountReports': 'accounts',
      // Expenses - check for any 'expenses' permission
      'expense-type': 'expenses',
      'expenseType': 'expenses',
      'expense-report': 'expenses',
      'expenseReport': 'expenses',
      // Reports
      'reports': 'reports',
      // Settings
      'settings': 'settings',
    };
  }
  
  /// Map screen keys to permission IDs
  static Map<String, String> _getScreenPermissionMap() {
    return {
      // Dashboard
      'dashboard': 'dashboard.view',
      // Wallet screens
      'wallet': 'wallet.self.view',
      'wallet-self': 'wallet.self.view',
      'wallet-all': 'wallet.all.view',
      'all-user-wallets': 'wallet.all.view',
      // Smart Approvals
      'smart_approvals': 'smart_approvals.transaction.view',
      'smart-approvals': 'smart_approvals.transaction.view',
      'pending-approvals': 'smart_approvals.transaction.view',
      // User Management
      'manage-users': 'all_users.user_management.view',
      'users': 'all_users.user_management.view',
      'roles': 'all_users.roles.view',
      // Payment Accounts
      'payment-modes': 'settings.payment_modes.view',
      'paymentModes': 'settings.payment_modes.view',
      'account-reports': 'accounts.view',
      'accountReports': 'accounts.view',
      // Expenses
      'expense-type': 'expenses.type.view',
      'expenseType': 'expenses.type.view',
      'expense-report': 'expenses.report.view',
      'expenseReport': 'expenses.report.view',
      // Reports
      'reports': 'reports.view',
      // Settings
      'settings': 'settings.view',
    };
  }
  
  /// Check if user has any of the given permissions
  /// Supports wildcard permissions (e.g., 'wallet.self.*')
  /// Also supports parent permissions (e.g., if user has 'all_users.user_management', 
  /// they have access to 'all_users.user_management.view', 'all_users.user_management.create', etc.)
  static bool _hasPermission(List<String> permissions, String requiredPermission) {
    // Exact match
    if (permissions.contains(requiredPermission)) {
      return true;
    }
    
    // Check if user has parent permission that grants access to child
    // e.g., if user has 'all_users.user_management' and required is 'all_users.user_management.view'
    // the parent permission should grant access
    final parts = requiredPermission.split('.');
    for (int i = parts.length; i > 0; i--) {
      final parentPermission = parts.sublist(0, i).join('.');
      if (permissions.contains(parentPermission)) {
        // User has parent permission, which grants access to all children
        return true;
      }
    }
    
    // Wildcard check - if requiredPermission ends with '.*', check prefix
    if (requiredPermission.endsWith('.*')) {
      final prefix = requiredPermission.replaceAll('.*', '');
      return permissions.any((p) => p.startsWith(prefix));
    }
    
    // Check if user has parent permission with wildcard
    // e.g., if required is 'smart_approvals.transaction.view'
    // check for 'smart_approvals.*' or 'smart_approvals.transaction.*'
    for (int i = parts.length; i > 0; i--) {
      final parentPermission = parts.sublist(0, i).join('.') + '.*';
      if (permissions.contains(parentPermission)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Check if user can access smart approvals
  /// Returns true if user has any smart approval permission
  /// This includes parent permission 'smart_approvals' or any child permission
  static Future<bool> canAccessSmartApprovals() async {
    final userRole = await AuthService.getUserRole();
    if (userRole == 'SuperAdmin' || userRole == 'Super Admin') {
      return true; // Super Admin has access to everything
    }
    
    final permissions = await AuthService.getUserPermissions();
    
    // Check if user has special '*' permission (all access)
    if (permissions.contains('*')) {
      return true;
    }
    
    return permissions.any((p) => 
      p == 'smart_approvals' ||
      p.startsWith('smart_approvals.')
    );
  }
  
  /// Check if user has a specific permission
  /// Super Admin always returns true
  static Future<bool> hasPermission(String permissionId) async {
    final userRole = await AuthService.getUserRole();
    if (userRole == 'SuperAdmin' || userRole == 'Super Admin') {
      return true; // Super Admin has all permissions
    }
    
    final permissions = await AuthService.getUserPermissions();
    
    // Check if user has special '*' permission (all access)
    if (permissions.contains('*')) {
      return true;
    }
    
    return _hasPermission(permissions, permissionId);
  }
  
  /// Check if user can perform specific action on a section
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
    if (await isSuperAdmin()) {
      return true;
    }
    
    // Check if user has parent permission (grants all actions)
    if (await hasPermission(section)) {
      return true;
    }
    
    // Check if user has specific action permission
    final actionPermission = '$section.$action';
    return await hasPermission(actionPermission);
  }
  
  /// Get all user permissions
  /// Super Admin returns empty list (has all permissions)
  static Future<List<String>> getAllPermissions() async {
    final userRole = await AuthService.getUserRole();
    if (userRole == 'SuperAdmin' || userRole == 'Super Admin') {
      return []; // Super Admin has all permissions, return empty (will be handled as "all access")
    }
    
    return await AuthService.getUserPermissions();
  }
  
  /// Check if user is Super Admin
  static Future<bool> isSuperAdmin() async {
    final userRole = await AuthService.getUserRole();
    return userRole == 'SuperAdmin' || userRole == 'Super Admin';
  }
  
  /// Check if user can view a specific menu item
  /// menuKey can be: 'dashboard', 'walletSelf', 'walletAll', 'walletOverview', 
  /// 'smartApprovals', 'users', 'roles', 'paymentModes', 'accountReports', 
  /// 'expenseType', 'expenseReport'
  static Future<bool> canViewMenuItem(String menuKey) async {
    final userRole = await AuthService.getUserRole();
    if (userRole == 'SuperAdmin' || userRole == 'Super Admin') {
      return true;
    }
    
    final permissions = await AuthService.getUserPermissions();
    if (permissions.contains('*')) {
      return true;
    }
    
    // Map menu keys to permissions
    final menuPermissionMap = {
      'dashboard': 'dashboard.view',
      'walletSelf': 'wallet.self.view',
      'walletAll': 'wallet.all.view',
      'walletOverview': 'wallet.report.view',
      'smartApprovals': 'smart_approvals.transaction.view',
      'users': 'all_users.user_management.view',
      'roles': 'all_users.roles.view',
      'paymentModes': 'settings.payment_modes.view',
      'accountReports': 'accounts.view',
      'expenseType': 'expenses.type.view',
      'expenseReport': 'expenses.report.view',
    };
    
    final requiredPermission = menuPermissionMap[menuKey];
    if (requiredPermission == null) {
      // If menu item not mapped, allow access (backwards compatibility)
      return true;
    }
    
    // For smart approvals, check if user has any smart_approvals permission
    // This allows access if user has parent permission 'smart_approvals' or any child permission
    if (menuKey == 'smartApprovals') {
      final hasDirectPermission = permissions.any((p) => 
        p == 'smart_approvals.transaction.view' ||
        p == 'smart_approvals' ||
        p.startsWith('smart_approvals.')
      );
      final hasParentPermission = _hasPermission(permissions, requiredPermission);
      final hasAccess = hasDirectPermission || hasParentPermission;
      
      // Debug logging for smart approvals permission check
      if (!hasAccess) {
        print('\n🔍 ===== SMART APPROVALS PERMISSION CHECK =====');
        print('   Menu Key: $menuKey');
        print('   User Role: $userRole');
        print('   Required Permission: $requiredPermission');
        print('   User Permissions Count: ${permissions.length}');
        print('   User Permissions: $permissions');
        print('   Has Direct Permission: $hasDirectPermission');
        print('   Has Parent Permission: $hasParentPermission');
        print('   Final Access: ❌ NO');
        print('==============================================\n');
      }
      
      return hasAccess;
    }
    
    // For walletSelf, check if user has any wallet.self permission (not just view)
    // This allows users with create/edit/delete permissions to see the menu
    if (menuKey == 'walletSelf') {
      return permissions.any((p) => 
        p == 'wallet.self.view' ||
        p == 'wallet.self' ||
        p.startsWith('wallet.self.')
      );
    }
    
    // For accountReports, check if user has parent permission OR any child permission
    // This allows access if parent 'accounts.payment_account_reports' is selected (even without children)
    if (menuKey == 'accountReports') {
      return permissions.any((p) => 
        p == 'accounts.view' ||
        p == 'accounts.payment_account_reports' ||
        p.startsWith('accounts.payment_account_reports.') ||
        p.startsWith('accounts.')
      ) || _hasPermission(permissions, requiredPermission);
    }
    
    // For paymentModes, check if user has any payment mode permission
    if (menuKey == 'paymentModes') {
      return permissions.any((p) => 
        p == 'settings.payment_modes.view' ||
        p == 'settings.payment_modes' ||
        p.startsWith('settings.payment_modes.') ||
        p == 'accounts.payment_account_reports' ||
        p.startsWith('accounts.payment_account_reports.')
      ) || _hasPermission(permissions, requiredPermission);
    }
    
    // For users (User Management), check if user has ANY all_users.user_management permission
    // This allows access if user has create/edit/delete permissions even without view
    if (menuKey == 'users') {
      return permissions.any((p) => 
        p == 'all_users.user_management.view' ||
        p == 'all_users.user_management' ||
        p.startsWith('all_users.user_management.')
      ) || _hasPermission(permissions, requiredPermission);
    }
    
    // For roles, check if user has ANY all_users.roles permission
    // This allows access if user has create/edit/delete permissions even without view
    if (menuKey == 'roles') {
      return permissions.any((p) => 
        p == 'all_users.roles.view' ||
        p == 'all_users.roles' ||
        p.startsWith('all_users.roles.')
      ) || _hasPermission(permissions, requiredPermission);
    }
    
    // For expenseType, check if user has ANY expenses.type permission
    // This allows access if user has create/edit/delete permissions even without view
    if (menuKey == 'expenseType') {
      return permissions.any((p) => 
        p == 'expenses.type.view' ||
        p == 'expenses.type' ||
        p.startsWith('expenses.type.') ||
        p == 'expenses.expenses_type.view' ||
        p == 'expenses.expenses_type' ||
        p.startsWith('expenses.expenses_type.')
      ) || _hasPermission(permissions, requiredPermission);
    }
    
    // For expenseReport, check if user has ANY expenses.report permission
    // This allows access if user has create/edit/delete permissions even without view
    if (menuKey == 'expenseReport') {
      return permissions.any((p) => 
        p == 'expenses.report.view' ||
        p == 'expenses.report' ||
        p.startsWith('expenses.report.') ||
        p == 'expenses.expenses_report.view' ||
        p == 'expenses.expenses_report' ||
        p.startsWith('expenses.expenses_report.')
      ) || _hasPermission(permissions, requiredPermission);
    }
    
    // For dashboard, check if user has ANY dashboard permission
    if (menuKey == 'dashboard') {
      return permissions.any((p) => 
        p == 'dashboard.view' ||
        p == 'dashboard' ||
        p.startsWith('dashboard.')
      ) || _hasPermission(permissions, requiredPermission);
    }
    
    // For walletAll, check if user has ANY wallet.all permission
    if (menuKey == 'walletAll') {
      return permissions.any((p) => 
        p == 'wallet.all.view' ||
        p == 'wallet.all' ||
        p.startsWith('wallet.all.')
      ) || _hasPermission(permissions, requiredPermission);
    }
    
    // For walletOverview, check if user has ANY wallet.report OR wallet.all permission
    // This allows access if user has:
    // 1. wallet.report.view OR any wallet.report.* action permission
    // 2. wallet.all.view OR any wallet.all.* permission (for backward compatibility)
    // (e.g., wallet.report.transaction.approve, wallet.all.transaction.approve, etc.)
    if (menuKey == 'walletOverview') {
      final hasAnyWalletReportPermission = permissions.any((p) => 
        p == 'wallet.report.view' ||
        p == 'wallet.report' ||
        p.startsWith('wallet.report.')
      );
      
      // Also check for wallet.all.* permissions (for backward compatibility)
      // Users with wallet.all.* permissions should also have access to All Wallet Report
      final hasAnyWalletAllPermission = permissions.any((p) => 
        p == 'wallet.all.view' ||
        p == 'wallet.all' ||
        p.startsWith('wallet.all.')
      );
      
      final hasParentPermission = _hasPermission(permissions, requiredPermission);
      final hasAccess = hasAnyWalletReportPermission || hasAnyWalletAllPermission || hasParentPermission;
      
      // Debug logging for walletOverview permission check
      if (!hasAccess) {
        print('\n🔍 ===== ALL WALLET REPORT PERMISSION CHECK =====');
        print('   Menu Key: $menuKey');
        print('   User Role: $userRole');
        print('   Required Permission: $requiredPermission');
        print('   User Permissions Count: ${permissions.length}');
        print('   Has Any Wallet Report Permission: $hasAnyWalletReportPermission');
        print('   Has Any Wallet All Permission: $hasAnyWalletAllPermission');
        print('   Has Parent Permission: $hasParentPermission');
        print('   Final Access: ❌ NO');
        print('==============================================\n');
      } else {
        print('\n✅ ===== ALL WALLET REPORT PERMISSION CHECK =====');
        print('   Menu Key: $menuKey');
        print('   User Role: $userRole');
        print('   Has Wallet Report Permission: $hasAnyWalletReportPermission');
        print('   Has Wallet All Permission: $hasAnyWalletAllPermission');
        print('   Final Access: ✅ YES');
        print('==============================================\n');
      }
      
      return hasAccess;
    }
    
    return _hasPermission(permissions, requiredPermission);
  }
  
  /// Check if user can view Wallet menu (parent menu)
  /// Returns true if user has any wallet permission
  static Future<bool> canViewWalletMenu() async {
    final userRole = await AuthService.getUserRole();
    if (userRole == 'SuperAdmin' || userRole == 'Super Admin') {
      return true;
    }
    
    final permissions = await AuthService.getUserPermissions();
    if (permissions.contains('*')) {
      return true;
    }
    
    return permissions.any((p) => 
      p == 'wallet.self.view' || 
      p == 'wallet.all.view' || 
      p == 'wallet.report.view' ||
      p.startsWith('wallet.')
    );
  }
  
  /// Check if user can view All Users menu (parent menu)
  /// Returns true if user has any user management permission
  static Future<bool> canViewUsersMenu() async {
    final userRole = await AuthService.getUserRole();
    if (userRole == 'SuperAdmin' || userRole == 'Super Admin') {
      return true;
    }
    
    final permissions = await AuthService.getUserPermissions();
    if (permissions.contains('*')) {
      return true;
    }
    
    return permissions.any((p) => 
      p == 'all_users.user_management.view' || 
      p == 'all_users.roles.view' ||
      p.startsWith('all_users.')
    );
  }
  
  /// Check if user can view Payment Accounts menu (parent menu)
  /// Returns true if user has any payment account permission
  /// This includes parent permission 'accounts.payment_account_reports' even if no children are selected
  static Future<bool> canViewPaymentAccountsMenu() async {
    final userRole = await AuthService.getUserRole();
    if (userRole == 'SuperAdmin' || userRole == 'Super Admin') {
      return true;
    }
    
    final permissions = await AuthService.getUserPermissions();
    if (permissions.contains('*')) {
      return true;
    }
    
    return permissions.any((p) => 
      p == 'settings.payment_modes.view' || 
      p == 'settings.payment_modes' ||
      p.startsWith('settings.payment_modes.') ||
      p == 'accounts.view' ||
      p == 'accounts.report.view' ||
      p == 'accounts.payment_account_reports' ||
      p.startsWith('accounts.payment_account_reports.') ||
      p.startsWith('accounts.')
    );
  }
  
  /// Check if user can view Expenses menu (parent menu)
  /// Returns true if user has any expense permission
  static Future<bool> canViewExpensesMenu() async {
    final userRole = await AuthService.getUserRole();
    if (userRole == 'SuperAdmin' || userRole == 'Super Admin') {
      return true;
    }
    
    final permissions = await AuthService.getUserPermissions();
    if (permissions.contains('*')) {
      return true;
    }
    
    return permissions.any((p) => 
      p == 'expenses.type.view' || 
      p == 'expenses.report.view' ||
      p.startsWith('expenses.')
    );
  }
  
  /// Check if user can access a NavItem
  /// This is a helper that converts NavItem enum to string and checks permission
  static Future<bool> canAccessNavItem(String navItemString) async {
    // Extract the enum value name from string like "NavItem.dashboard"
    final menuKey = navItemString.replaceFirst('NavItem.', '');
    return canViewMenuItem(menuKey);
  }
}

