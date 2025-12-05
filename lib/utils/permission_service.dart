import 'package:shared_preferences/shared_preferences.dart';
import '../services/role_service.dart';

class PermissionService {
  static Map<String, List<String>>? _permissionsCache;

  /// Get permissions for a specific role
  static Future<List<String>> getRolePermissions(String roleName) async {
    // Check cache first
    if (_permissionsCache != null && _permissionsCache!.containsKey(roleName)) {
      return _permissionsCache![roleName]!;
    }

    try {
      final result = await RoleService.getRolePermissions(roleName);
      if (result['success'] == true) {
        final permissions = (result['permissions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        // Cache the permissions
        _permissionsCache ??= {};
        _permissionsCache![roleName] = permissions;

        return permissions;
      }
    } catch (e) {
      // If API fails, return empty list
    }

    return [];
  }

  /// Check if user has a specific permission
  static Future<bool> hasPermission(String permission, String userRole) async {
    final permissions = await getRolePermissions(userRole);
    return permissions.contains(permission);
  }

  /// Check if user can create transactions
  static Future<bool> canCreateTransaction(String userRole) async {
    return hasPermission('wallet.self.transaction.create', userRole);
  }

  /// Check if user can edit transactions
  static Future<bool> canEditTransaction(String userRole) async {
    return hasPermission('wallet.self.transaction.edit', userRole);
  }

  /// Check if user can delete transactions
  static Future<bool> canDeleteTransaction(String userRole) async {
    return hasPermission('wallet.self.transaction.delete', userRole);
  }

  /// Check if user can reject transactions
  static Future<bool> canRejectTransaction(String userRole) async {
    return hasPermission('wallet.self.transaction.reject', userRole);
  }

  /// Check if user can flag transactions
  static Future<bool> canFlagTransaction(String userRole) async {
    return hasPermission('wallet.self.transaction.flag', userRole);
  }

  /// Check if user can approve transactions
  static Future<bool> canApproveTransaction(String userRole) async {
    return hasPermission('wallet.self.transaction.approve', userRole);
  }

  /// Check if user can export transactions
  static Future<bool> canExportTransaction(String userRole) async {
    return hasPermission('wallet.self.transaction.export', userRole);
  }

  /// Check if user can view transactions (read-only)
  static Future<bool> canViewTransaction(String userRole) async {
    return hasPermission('wallet.self.transaction.view', userRole);
  }

  /// Check if user has dashboard access
  static Future<bool> hasDashboardAccess(String userRole) async {
    return hasPermission('dashboard', userRole);
  }

  /// Check if user has wallet access
  static Future<bool> hasWalletAccess(String userRole) async {
    return await hasPermission('wallet', userRole) ||
        await hasPermission('wallet.self', userRole);
  }

  // ========== Expenses Permissions ==========

  /// Check if user can create expenses
  static Future<bool> canCreateExpense(String userRole) async {
    return hasPermission('wallet.self.expenses.transaction.create', userRole);
  }

  /// Check if user can edit expenses
  static Future<bool> canEditExpense(String userRole) async {
    return hasPermission('wallet.self.expenses.transaction.edit', userRole);
  }

  /// Check if user can delete expenses
  static Future<bool> canDeleteExpense(String userRole) async {
    return hasPermission('wallet.self.expenses.transaction.delete', userRole);
  }

  /// Check if user can reject expenses
  static Future<bool> canRejectExpense(String userRole) async {
    return hasPermission('wallet.self.expenses.transaction.reject', userRole);
  }

  /// Check if user can flag expenses
  static Future<bool> canFlagExpense(String userRole) async {
    return hasPermission('wallet.self.expenses.transaction.flag', userRole);
  }

  /// Check if user can approve expenses
  static Future<bool> canApproveExpense(String userRole) async {
    return hasPermission('wallet.self.expenses.transaction.approve', userRole);
  }

  /// Check if user can export expenses
  static Future<bool> canExportExpense(String userRole) async {
    return hasPermission('wallet.self.expenses.transaction.export', userRole);
  }

  /// Check if user can view expenses (read-only)
  static Future<bool> canViewExpense(String userRole) async {
    return hasPermission('wallet.self.expenses.transaction.view', userRole);
  }

  /// Check if user has expenses access
  static Future<bool> hasExpensesAccess(String userRole) async {
    return await hasPermission('wallet.self.expenses', userRole) ||
        await hasPermission('wallet.self.expenses.transaction', userRole);
  }

  // ========== Collection Permissions ==========

  /// Check if user can create collections
  static Future<bool> canCreateCollection(String userRole) async {
    return hasPermission('wallet.self.collection.transaction.create', userRole);
  }

  /// Check if user can edit collections
  static Future<bool> canEditCollection(String userRole) async {
    return hasPermission('wallet.self.collection.transaction.edit', userRole);
  }

  /// Check if user can delete collections
  static Future<bool> canDeleteCollection(String userRole) async {
    return hasPermission('wallet.self.collection.transaction.delete', userRole);
  }

  /// Check if user can reject collections
  static Future<bool> canRejectCollection(String userRole) async {
    return hasPermission('wallet.self.collection.transaction.reject', userRole);
  }

  /// Check if user can flag collections
  static Future<bool> canFlagCollection(String userRole) async {
    return hasPermission('wallet.self.collection.transaction.flag', userRole);
  }

  /// Check if user can approve collections
  static Future<bool> canApproveCollection(String userRole) async {
    return hasPermission('wallet.self.collection.transaction.approve', userRole);
  }

  /// Check if user can export collections
  static Future<bool> canExportCollection(String userRole) async {
    return hasPermission('wallet.self.collection.transaction.export', userRole);
  }

  /// Check if user can view collections (read-only)
  static Future<bool> canViewCollection(String userRole) async {
    return hasPermission('wallet.self.collection.transaction.view', userRole);
  }

  /// Check if user has collection access
  static Future<bool> hasCollectionAccess(String userRole) async {
    return await hasPermission('wallet.self.collection', userRole) ||
        await hasPermission('wallet.self.collection.transaction', userRole);
  }

  // ========== All User Wallets / All Wallet Report Permissions ==========

  // Transaction Permissions
  static Future<bool> canCreateAllTransaction(String userRole) async {
    return hasPermission('wallet.all.transaction.create', userRole);
  }

  static Future<bool> canRemoveAllTransaction(String userRole) async {
    return hasPermission('wallet.all.transaction.remove', userRole);
  }

  static Future<bool> canRejectAllTransaction(String userRole) async {
    return hasPermission('wallet.all.transaction.reject', userRole);
  }

  static Future<bool> canFlagAllTransaction(String userRole) async {
    return hasPermission('wallet.all.transaction.flag', userRole);
  }

  static Future<bool> canApproveAllTransaction(String userRole) async {
    return hasPermission('wallet.all.transaction.approve', userRole);
  }

  static Future<bool> canExportAllTransaction(String userRole) async {
    return hasPermission('wallet.all.transaction.export', userRole);
  }

  static Future<bool> canViewAllTransaction(String userRole) async {
    return hasPermission('wallet.all.transaction.view', userRole);
  }

  static Future<bool> hasAllTransactionAccess(String userRole) async {
    return await hasPermission('wallet.all.transaction', userRole) ||
        await canViewAllTransaction(userRole);
  }

  // Collection Permissions
  static Future<bool> canCreateAllCollection(String userRole) async {
    return hasPermission('wallet.all.collection.create', userRole);
  }

  static Future<bool> canRemoveAllCollection(String userRole) async {
    return hasPermission('wallet.all.collection.remove', userRole);
  }

  static Future<bool> canRejectAllCollection(String userRole) async {
    return hasPermission('wallet.all.collection.reject', userRole);
  }

  static Future<bool> canFlagAllCollection(String userRole) async {
    return hasPermission('wallet.all.collection.flag', userRole);
  }

  static Future<bool> canApproveAllCollection(String userRole) async {
    return hasPermission('wallet.all.collection.approve', userRole);
  }

  static Future<bool> canExportAllCollection(String userRole) async {
    return hasPermission('wallet.all.collection.export', userRole);
  }

  static Future<bool> canViewAllCollection(String userRole) async {
    return hasPermission('wallet.all.collection.view', userRole);
  }

  static Future<bool> hasAllCollectionAccess(String userRole) async {
    return await hasPermission('wallet.all.collection', userRole) ||
        await canViewAllCollection(userRole);
  }

  // Expenses Permissions
  static Future<bool> canCreateAllExpense(String userRole) async {
    return hasPermission('wallet.all.expenses.create', userRole);
  }

  static Future<bool> canRemoveAllExpense(String userRole) async {
    return hasPermission('wallet.all.expenses.remove', userRole);
  }

  static Future<bool> canRejectAllExpense(String userRole) async {
    return hasPermission('wallet.all.expenses.reject', userRole);
  }

  static Future<bool> canFlagAllExpense(String userRole) async {
    return hasPermission('wallet.all.expenses.flag', userRole);
  }

  static Future<bool> canApproveAllExpense(String userRole) async {
    return hasPermission('wallet.all.expenses.approve', userRole);
  }

  static Future<bool> canExportAllExpense(String userRole) async {
    return hasPermission('wallet.all.expenses.export', userRole);
  }

  static Future<bool> canViewAllExpense(String userRole) async {
    return hasPermission('wallet.all.expenses.view', userRole);
  }

  static Future<bool> hasAllExpensesAccess(String userRole) async {
    return await hasPermission('wallet.all.expenses', userRole) ||
        await canViewAllExpense(userRole);
  }

  static Future<bool> hasAllWalletsAccess(String userRole) async {
    return await hasPermission('wallet.all', userRole) ||
        await hasAllTransactionAccess(userRole) ||
        await hasAllCollectionAccess(userRole) ||
        await hasAllExpensesAccess(userRole);
  }

  // ========== Smart Approvals Permissions ==========

  // Transaction Permissions
  static Future<bool> canCreateSmartApprovalTransaction(String userRole) async {
    return hasPermission('smart_approvals.transaction.create', userRole);
  }

  static Future<bool> canRemoveSmartApprovalTransaction(String userRole) async {
    return hasPermission('smart_approvals.transaction.remove', userRole);
  }

  static Future<bool> canRejectSmartApprovalTransaction(String userRole) async {
    return hasPermission('smart_approvals.transaction.reject', userRole);
  }

  static Future<bool> canFlagSmartApprovalTransaction(String userRole) async {
    return hasPermission('smart_approvals.transaction.flag', userRole);
  }

  static Future<bool> canApproveSmartApprovalTransaction(String userRole) async {
    return hasPermission('smart_approvals.transaction.approve', userRole);
  }

  static Future<bool> canExportSmartApprovalTransaction(String userRole) async {
    return hasPermission('smart_approvals.transaction.export', userRole);
  }

  static Future<bool> canViewSmartApprovalTransaction(String userRole) async {
    return hasPermission('smart_approvals.transaction.view', userRole);
  }

  static Future<bool> hasSmartApprovalTransactionAccess(String userRole) async {
    return await hasPermission('smart_approvals.transaction', userRole) ||
        await canViewSmartApprovalTransaction(userRole);
  }

  // Collection Permissions
  static Future<bool> canCreateSmartApprovalCollection(String userRole) async {
    return hasPermission('smart_approvals.collection.create', userRole);
  }

  static Future<bool> canRemoveSmartApprovalCollection(String userRole) async {
    return hasPermission('smart_approvals.collection.remove', userRole);
  }

  static Future<bool> canRejectSmartApprovalCollection(String userRole) async {
    return hasPermission('smart_approvals.collection.reject', userRole);
  }

  static Future<bool> canFlagSmartApprovalCollection(String userRole) async {
    return hasPermission('smart_approvals.collection.flag', userRole);
  }

  static Future<bool> canApproveSmartApprovalCollection(String userRole) async {
    return hasPermission('smart_approvals.collection.approve', userRole);
  }

  static Future<bool> canExportSmartApprovalCollection(String userRole) async {
    return hasPermission('smart_approvals.collection.export', userRole);
  }

  static Future<bool> canViewSmartApprovalCollection(String userRole) async {
    return hasPermission('smart_approvals.collection.view', userRole);
  }

  static Future<bool> hasSmartApprovalCollectionAccess(String userRole) async {
    return await hasPermission('smart_approvals.collection', userRole) ||
        await canViewSmartApprovalCollection(userRole);
  }

  // Expenses Permissions
  static Future<bool> canCreateSmartApprovalExpense(String userRole) async {
    return hasPermission('smart_approvals.expenses.create', userRole);
  }

  static Future<bool> canRemoveSmartApprovalExpense(String userRole) async {
    return hasPermission('smart_approvals.expenses.remove', userRole);
  }

  static Future<bool> canRejectSmartApprovalExpense(String userRole) async {
    return hasPermission('smart_approvals.expenses.reject', userRole);
  }

  static Future<bool> canFlagSmartApprovalExpense(String userRole) async {
    return hasPermission('smart_approvals.expenses.flag', userRole);
  }

  static Future<bool> canApproveSmartApprovalExpense(String userRole) async {
    return hasPermission('smart_approvals.expenses.approve', userRole);
  }

  static Future<bool> canExportSmartApprovalExpense(String userRole) async {
    return hasPermission('smart_approvals.expenses.export', userRole);
  }

  static Future<bool> canViewSmartApprovalExpense(String userRole) async {
    return hasPermission('smart_approvals.expenses.view', userRole);
  }

  static Future<bool> hasSmartApprovalExpensesAccess(String userRole) async {
    return await hasPermission('smart_approvals.expenses', userRole) ||
        await canViewSmartApprovalExpense(userRole);
  }

  static Future<bool> hasSmartApprovalsAccess(String userRole) async {
    return await hasPermission('smart_approvals', userRole) ||
        await hasSmartApprovalTransactionAccess(userRole) ||
        await hasSmartApprovalCollectionAccess(userRole) ||
        await hasSmartApprovalExpensesAccess(userRole);
  }

  /// Clear permissions cache
  static void clearCache() {
    _permissionsCache = null;
  }

  /// Get current user role from storage
  static Future<String?> getCurrentUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_role');
    } catch (e) {
      return null;
    }
  }
}

