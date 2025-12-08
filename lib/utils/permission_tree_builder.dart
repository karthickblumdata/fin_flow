import '../models/permission_node.dart';

class PermissionTreeBuilder {
  // Build the default permission tree structure
  static PermissionNode buildDefaultPermissionTree() {
    return PermissionNode(
      id: 'root',
      label: 'Root',
      children: [
        // Dashboard Section
        PermissionNode(
          id: 'dashboard',
          label: 'Dashboard',
          isExpanded: false,
          children: [
            PermissionNode(
              id: 'dashboard.view',
              label: 'View',
              description: 'Read-only access to dashboard',
            ),
            // Flagged Financial Flow Section
            PermissionNode(
              id: 'dashboard.flagged_financial_flow',
              label: 'Flagged Financial Flow',
              isExpanded: false,
              children: [
                PermissionNode(
                  id: 'dashboard.flagged_financial_flow.enable',
                  label: 'Enable',
                  description: 'Enable or disable access to Flagged Financial Flow feature',
                ),
              ],
            ),
            // Status Count Table Section
            PermissionNode(
              id: 'dashboard.status_count',
              label: 'Status Count Table',
              isExpanded: false,
              children: [
                PermissionNode(
                  id: 'dashboard.status_count.view',
                  label: 'View',
                  description: 'Enable or disable access to Status Count Table feature',
                ),
              ],
            ),
            // Quick Actions Section (moved under Dashboard)
            PermissionNode(
              id: 'dashboard.quick_actions',
              label: 'Quick Actions',
              isExpanded: false,
              children: [
                PermissionNode(
                  id: 'dashboard.quick_actions.enable',
                  label: 'Enable Quick Actions',
                  description: 'Allow quick action buttons in dashboard',
                ),
                PermissionNode(
                  id: 'dashboard.quick_actions.add_amount',
                  label: 'Add Amount',
                  description: 'Allow adding amount to wallet (Super Admin only)',
                ),
                PermissionNode(
                  id: 'dashboard.quick_actions.withdraw',
                  label: 'Withdraw',
                  description: 'Allow withdrawing amount from wallet (Super Admin only)',
                ),
              ],
            ),
          ],
        ),
        // Wallet Section
        PermissionNode(
          id: 'wallet',
          label: 'Wallet',
          isExpanded: false,
          children: [
            PermissionNode(
              id: 'wallet.self',
              label: 'Self Wallet',
              isExpanded: false,
              children: [
                PermissionNode(
                  id: 'wallet.self.transaction',
                  label: 'Transaction',
                  isExpanded: false,
                  children: [
                    PermissionNode(
                      id: 'wallet.self.transaction.create',
                      label: 'Add',
                    ),
                    PermissionNode(
                      id: 'wallet.self.transaction.edit',
                      label: 'Edit',
                    ),
                    PermissionNode(
                      id: 'wallet.self.transaction.delete',
                      label: 'Delete',
                    ),
                    PermissionNode(
                      id: 'wallet.self.transaction.reject',
                      label: 'Reject',
                    ),
                    PermissionNode(
                      id: 'wallet.self.transaction.flag',
                      label: 'Flag',
                    ),
                    PermissionNode(
                      id: 'wallet.self.transaction.approve',
                      label: 'Approve',
                    ),
                    PermissionNode(
                      id: 'wallet.self.transaction.unapprove',
                      label: 'Unapprove',
                    ),
                    PermissionNode(
                      id: 'wallet.self.transaction.export',
                      label: 'Export As',
                    ),
                    PermissionNode(
                      id: 'wallet.self.transaction.view',
                      label: 'View',
                      description: 'Read-only access',
                    ),
                  ],
                ),
                PermissionNode(
                  id: 'wallet.self.expenses',
                  label: 'Expenses',
                  isExpanded: false,
                  children: [
                    PermissionNode(
                      id: 'wallet.self.expenses.create',
                      label: 'Add',
                    ),
                    PermissionNode(
                      id: 'wallet.self.expenses.edit',
                      label: 'Edit',
                    ),
                    PermissionNode(
                      id: 'wallet.self.expenses.delete',
                      label: 'Delete',
                    ),
                    PermissionNode(
                      id: 'wallet.self.expenses.reject',
                      label: 'Reject',
                    ),
                    PermissionNode(
                      id: 'wallet.self.expenses.flag',
                      label: 'Flag',
                    ),
                    PermissionNode(
                      id: 'wallet.self.expenses.approve',
                      label: 'Approve',
                    ),
                    PermissionNode(
                      id: 'wallet.self.expenses.unapprove',
                      label: 'Unapprove',
                    ),
                    PermissionNode(
                      id: 'wallet.self.expenses.export',
                      label: 'Export As',
                    ),
                    PermissionNode(
                      id: 'wallet.self.expenses.view',
                      label: 'View',
                      description: 'Read-only access',
                    ),
                  ],
                ),
                PermissionNode(
                  id: 'wallet.self.collection',
                  label: 'Collection',
                  isExpanded: false,
                  children: [
                    PermissionNode(
                      id: 'wallet.self.collection.create',
                      label: 'Add',
                    ),
                    PermissionNode(
                      id: 'wallet.self.collection.edit',
                      label: 'Edit',
                    ),
                    PermissionNode(
                      id: 'wallet.self.collection.delete',
                      label: 'Delete',
                    ),
                    PermissionNode(
                      id: 'wallet.self.collection.reject',
                      label: 'Reject',
                    ),
                    PermissionNode(
                      id: 'wallet.self.collection.flag',
                      label: 'Flag',
                    ),
                    PermissionNode(
                      id: 'wallet.self.collection.approve',
                      label: 'Approve',
                    ),
                    PermissionNode(
                      id: 'wallet.self.collection.export',
                      label: 'Export As',
                    ),
                    PermissionNode(
                      id: 'wallet.self.collection.view',
                      label: 'View',
                      description: 'Read-only access',
                    ),
                  ],
                ),
              ],
            ),
            // All User Wallets
            PermissionNode(
              id: 'wallet.all',
              label: 'All User Wallets',
              isExpanded: false,
              children: [
                // Top-level action permissions
                PermissionNode(
                  id: 'wallet.all.add_expense',
                  label: 'Add Expense',
                  description: 'Permission to add expenses for all users',
                ),
                PermissionNode(
                  id: 'wallet.all.add_amount',
                  label: 'Add Amount',
                  description: 'Permission to add amount to wallets',
                ),
                PermissionNode(
                  id: 'wallet.all.add_collection',
                  label: 'Add Collection',
                  description: 'Permission to add collections for all users',
                ),
                PermissionNode(
                  id: 'wallet.all.add_transaction',
                  label: 'Add Transaction',
                  description: 'Permission to add transactions for all users',
                ),
                PermissionNode(
                  id: 'wallet.all.withdraw',
                  label: 'Withdraw',
                  description: 'Permission to withdraw amount from wallets',
                ),
                // Transaction category (without Add)
                PermissionNode(
                  id: 'wallet.all.transaction',
                  label: 'Transaction',
                  isExpanded: false,
                  children: [
                    PermissionNode(
                      id: 'wallet.all.transaction.remove',
                      label: 'Delete',
                    ),
                    PermissionNode(
                      id: 'wallet.all.transaction.reject',
                      label: 'Reject',
                    ),
                    PermissionNode(
                      id: 'wallet.all.transaction.flag',
                      label: 'Flag',
                    ),
                    PermissionNode(
                      id: 'wallet.all.transaction.approve',
                      label: 'Approve',
                    ),
                    PermissionNode(
                      id: 'wallet.all.transaction.export',
                      label: 'Export As',
                    ),
                    PermissionNode(
                      id: 'wallet.all.transaction.view',
                      label: 'View',
                      description: 'Read-only access',
                    ),
                  ],
                ),
                // Collection category (without Add)
                PermissionNode(
                  id: 'wallet.all.collection',
                  label: 'Collection',
                  isExpanded: false,
                  children: [
                    PermissionNode(
                      id: 'wallet.all.collection.remove',
                      label: 'Delete',
                    ),
                    PermissionNode(
                      id: 'wallet.all.collection.reject',
                      label: 'Reject',
                    ),
                    PermissionNode(
                      id: 'wallet.all.collection.flag',
                      label: 'Flag',
                    ),
                    PermissionNode(
                      id: 'wallet.all.collection.approve',
                      label: 'Approve',
                    ),
                    PermissionNode(
                      id: 'wallet.all.collection.export',
                      label: 'Export As',
                    ),
                    PermissionNode(
                      id: 'wallet.all.collection.view',
                      label: 'View',
                      description: 'Read-only access',
                    ),
                  ],
                ),
                // Expenses category (without Add)
                PermissionNode(
                  id: 'wallet.all.expenses',
                  label: 'Expenses',
                  isExpanded: false,
                  children: [
                    PermissionNode(
                      id: 'wallet.all.expenses.remove',
                      label: 'Delete',
                    ),
                    PermissionNode(
                      id: 'wallet.all.expenses.reject',
                      label: 'Reject',
                    ),
                    PermissionNode(
                      id: 'wallet.all.expenses.flag',
                      label: 'Flag',
                    ),
                    PermissionNode(
                      id: 'wallet.all.expenses.approve',
                      label: 'Approve',
                    ),
                    PermissionNode(
                      id: 'wallet.all.expenses.export',
                      label: 'Export As',
                    ),
                    PermissionNode(
                      id: 'wallet.all.expenses.view',
                      label: 'View',
                      description: 'Read-only access',
                    ),
                  ],
                ),
              ],
            ),
            // All Wallet Report
            PermissionNode(
              id: 'wallet.report',
              label: 'All Wallet Report',
              isExpanded: false,
              children: [
                PermissionNode(
                  id: 'wallet.report.transaction',
                  label: 'Transaction',
                  isExpanded: false,
                  children: [
                    PermissionNode(
                      id: 'wallet.report.transaction.create',
                      label: 'Add',
                    ),
                    PermissionNode(
                      id: 'wallet.report.transaction.remove',
                      label: 'Delete',
                    ),
                    PermissionNode(
                      id: 'wallet.report.transaction.reject',
                      label: 'Reject',
                    ),
                    PermissionNode(
                      id: 'wallet.report.transaction.flag',
                      label: 'Flag',
                    ),
                    PermissionNode(
                      id: 'wallet.report.transaction.approve',
                      label: 'Approve',
                    ),
                    PermissionNode(
                      id: 'wallet.report.transaction.export',
                      label: 'Export As',
                    ),
                    PermissionNode(
                      id: 'wallet.report.transaction.view',
                      label: 'View',
                      description: 'Read-only access',
                    ),
                  ],
                ),
                PermissionNode(
                  id: 'wallet.report.collection',
                  label: 'Collection',
                  isExpanded: false,
                  children: [
                    PermissionNode(
                      id: 'wallet.report.collection.create',
                      label: 'Add',
                    ),
                    PermissionNode(
                      id: 'wallet.report.collection.remove',
                      label: 'Delete',
                    ),
                    PermissionNode(
                      id: 'wallet.report.collection.reject',
                      label: 'Reject',
                    ),
                    PermissionNode(
                      id: 'wallet.report.collection.flag',
                      label: 'Flag',
                    ),
                    PermissionNode(
                      id: 'wallet.report.collection.approve',
                      label: 'Approve',
                    ),
                    PermissionNode(
                      id: 'wallet.report.collection.export',
                      label: 'Export As',
                    ),
                    PermissionNode(
                      id: 'wallet.report.collection.view',
                      label: 'View',
                      description: 'Read-only access',
                    ),
                  ],
                ),
                PermissionNode(
                  id: 'wallet.report.expenses',
                  label: 'Expenses',
                  isExpanded: false,
                  children: [
                    PermissionNode(
                      id: 'wallet.report.expenses.create',
                      label: 'Add',
                    ),
                    PermissionNode(
                      id: 'wallet.report.expenses.remove',
                      label: 'Delete',
                    ),
                    PermissionNode(
                      id: 'wallet.report.expenses.reject',
                      label: 'Reject',
                    ),
                    PermissionNode(
                      id: 'wallet.report.expenses.flag',
                      label: 'Flag',
                    ),
                    PermissionNode(
                      id: 'wallet.report.expenses.approve',
                      label: 'Approve',
                    ),
                    PermissionNode(
                      id: 'wallet.report.expenses.export',
                      label: 'Export As',
                    ),
                    PermissionNode(
                      id: 'wallet.report.expenses.view',
                      label: 'View',
                      description: 'Read-only access',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        // Smart Approvals Section
        PermissionNode(
          id: 'smart_approvals',
          label: 'Smart Approvals',
          isExpanded: false,
          children: [
            PermissionNode(
              id: 'smart_approvals.transaction',
              label: 'Transaction',
              isExpanded: false,
              children: [
                PermissionNode(
                  id: 'smart_approvals.transaction.create',
                  label: 'Add',
                ),
                PermissionNode(
                  id: 'smart_approvals.transaction.reject',
                  label: 'Reject',
                ),
                PermissionNode(
                  id: 'smart_approvals.transaction.flag',
                  label: 'Flag',
                ),
                PermissionNode(
                  id: 'smart_approvals.transaction.approve',
                  label: 'Approve',
                ),
                PermissionNode(
                  id: 'smart_approvals.transaction.export',
                  label: 'Export As',
                ),
                PermissionNode(
                  id: 'smart_approvals.transaction.view',
                  label: 'View',
                  description: 'Read-only access',
                ),
              ],
            ),
            PermissionNode(
              id: 'smart_approvals.collection',
              label: 'Collection',
              isExpanded: false,
              children: [
                PermissionNode(
                  id: 'smart_approvals.collection.create',
                  label: 'Add',
                ),
                PermissionNode(
                  id: 'smart_approvals.collection.reject',
                  label: 'Reject',
                ),
                PermissionNode(
                  id: 'smart_approvals.collection.flag',
                  label: 'Flag',
                ),
                PermissionNode(
                  id: 'smart_approvals.collection.approve',
                  label: 'Approve',
                ),
                PermissionNode(
                  id: 'smart_approvals.collection.export',
                  label: 'Export As',
                ),
                PermissionNode(
                  id: 'smart_approvals.collection.view',
                  label: 'View',
                  description: 'Read-only access',
                ),
              ],
            ),
            PermissionNode(
              id: 'smart_approvals.expenses',
              label: 'Expenses',
              isExpanded: false,
              children: [
                PermissionNode(
                  id: 'smart_approvals.expenses.create',
                  label: 'Add',
                ),
                PermissionNode(
                  id: 'smart_approvals.expenses.reject',
                  label: 'Reject',
                ),
                PermissionNode(
                  id: 'smart_approvals.expenses.flag',
                  label: 'Flag',
                ),
                PermissionNode(
                  id: 'smart_approvals.expenses.approve',
                  label: 'Approve',
                ),
                PermissionNode(
                  id: 'smart_approvals.expenses.export',
                  label: 'Export As',
                ),
                PermissionNode(
                  id: 'smart_approvals.expenses.view',
                  label: 'View',
                  description: 'Read-only access',
                ),
              ],
            ),
          ],
        ),
        // All Users Section
        PermissionNode(
          id: 'all_users',
          label: 'All Users',
          isExpanded: false,
          children: [
            // User Management
            PermissionNode(
              id: 'all_users.user_management',
              label: 'User Management',
              isExpanded: false,
              children: [
                PermissionNode(
                  id: 'all_users.user_management.create',
                  label: 'Add',
                ),
                PermissionNode(
                  id: 'all_users.user_management.edit',
                  label: 'Edit',
                ),
                PermissionNode(
                  id: 'all_users.user_management.view',
                  label: 'View',
                  description: 'Read-only access',
                ),
                PermissionNode(
                  id: 'all_users.user_management.delete',
                  label: 'Delete',
                ),
              ],
            ),
            // Roles
            PermissionNode(
              id: 'all_users.roles',
              label: 'Roles',
              isExpanded: false,
              children: [
                PermissionNode(
                  id: 'all_users.roles.edit',
                  label: 'Edit',
                ),
                PermissionNode(
                  id: 'all_users.roles.create',
                  label: 'Add',
                ),
                PermissionNode(
                  id: 'all_users.roles.delete',
                  label: 'Delete',
                ),
                PermissionNode(
                  id: 'all_users.roles.view',
                  label: 'View',
                  description: 'Read-only access',
                ),
              ],
            ),
            // Assign Wallet
            PermissionNode(
              id: 'all_users.assign_wallet',
              label: 'Assign Wallet',
              description: 'Permission to assign wallet to users',
            ),
          ],
        ),
        // Accounts Section
        PermissionNode(
          id: 'accounts',
          label: 'Accounts',
          isExpanded: false,
          children: [
            // Payment/Account Reports
            PermissionNode(
              id: 'accounts.payment_account_reports',
              label: 'Payment/Account Reports',
              isExpanded: false,
              children: [
                PermissionNode(
                  id: 'accounts.payment_account_reports.edit',
                  label: 'Edit',
                ),
                PermissionNode(
                  id: 'accounts.payment_account_reports.create',
                  label: 'Add',
                ),
                PermissionNode(
                  id: 'accounts.payment_account_reports.delete',
                  label: 'Delete',
                ),
                PermissionNode(
                  id: 'accounts.payment_account_reports.export',
                  label: 'Export As',
                ),
                PermissionNode(
                  id: 'accounts.payment_account_reports.view',
                  label: 'View',
                  description: 'Read-only access',
                ),
              ],
            ),
            // Payment Modes
            PermissionNode(
              id: 'accounts.payment_modes',
              label: 'Payment Modes',
              isExpanded: false,
              children: [
                PermissionNode(
                  id: 'accounts.payment_modes.create',
                  label: 'Add',
                ),
                PermissionNode(
                  id: 'accounts.payment_modes.edit',
                  label: 'Edit',
                ),
                PermissionNode(
                  id: 'accounts.payment_modes.delete',
                  label: 'Delete',
                ),
                PermissionNode(
                  id: 'accounts.payment_modes.manage',
                  label: 'Manage',
                  description: 'Full access to add, edit, and delete payment modes',
                ),
                PermissionNode(
                  id: 'accounts.payment_modes.view',
                  label: 'View',
                  description: 'Read-only access',
                ),
              ],
            ),
          ],
        ),
        // Expenses Section
        PermissionNode(
          id: 'expenses',
          label: 'Expenses',
          isExpanded: false,
          children: [
            // Expenses Type
            PermissionNode(
              id: 'expenses.expenses_type',
              label: 'Expenses Type',
              isExpanded: false,
              children: [
                PermissionNode(
                  id: 'expenses.expenses_type.create',
                  label: 'Add',
                ),
                PermissionNode(
                  id: 'expenses.expenses_type.edit',
                  label: 'Edit',
                ),
                PermissionNode(
                  id: 'expenses.expenses_type.delete',
                  label: 'Delete',
                ),
                PermissionNode(
                  id: 'expenses.expenses_type.view',
                  label: 'View',
                  description: 'Read-only access',
                ),
              ],
            ),
            // Expenses Report
            PermissionNode(
              id: 'expenses.expenses_report',
              label: 'Expenses Report',
              isExpanded: false,
              children: [
                PermissionNode(
                  id: 'expenses.expenses_report.edit',
                  label: 'Edit',
                ),
                PermissionNode(
                  id: 'expenses.expenses_report.create',
                  label: 'Add',
                ),
                PermissionNode(
                  id: 'expenses.expenses_report.delete',
                  label: 'Delete',
                ),
                PermissionNode(
                  id: 'expenses.expenses_report.export',
                  label: 'Export As',
                ),
                PermissionNode(
                  id: 'expenses.expenses_report.view',
                  label: 'View',
                  description: 'Read-only access',
                ),
              ],
            ),
          ],
        ),
        // Settings Section
        PermissionNode(
          id: 'settings',
          label: 'Settings',
          isExpanded: false,
          children: [
            // Collection Custom Field
            PermissionNode(
              id: 'settings.collection_custom_field',
              label: 'Collection Custom Field',
              isExpanded: false,
              children: [
                PermissionNode(
                  id: 'settings.collection_custom_field.create',
                  label: 'Add',
                ),
                PermissionNode(
                  id: 'settings.collection_custom_field.edit',
                  label: 'Edit',
                ),
                PermissionNode(
                  id: 'settings.collection_custom_field.delete',
                  label: 'Delete',
                ),
                PermissionNode(
                  id: 'settings.collection_custom_field.view',
                  label: 'View',
                  description: 'Read-only access',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // Apply selected permissions to the tree
  static PermissionNode applyPermissions(
    PermissionNode tree,
    List<String> selectedPermissionIds,
  ) {
    return _applyPermissionsRecursive(tree, selectedPermissionIds);
  }

  static PermissionNode _applyPermissionsRecursive(
    PermissionNode node,
    List<String> selectedPermissionIds,
  ) {
    final isSelected = selectedPermissionIds.contains(node.id);
    
    final updatedChildren = node.children.map((child) {
      return _applyPermissionsRecursive(child, selectedPermissionIds);
    }).toList();

    final updatedNode = node.copyWith(
      isSelected: isSelected,
      children: updatedChildren,
    );

    // Update parent state based on children
    updatedNode.updateSelectionState();

    return updatedNode;
  }

  /// Filter out Dashboard and My Wallet permissions for non-wallet users
  static PermissionNode filterForNonWalletUsers(PermissionNode tree) {
    final filteredChildren = tree.children.where((child) {
      // Remove Dashboard node
      if (child.id == 'dashboard') {
        return false;
      }
      // Remove wallet.self (My Wallet) node
      if (child.id == 'wallet.self') {
        return false;
      }
      // Keep other nodes
      return true;
    }).map((child) {
      // Recursively filter children
      if (child.children.isNotEmpty) {
        return filterForNonWalletUsers(child);
      }
      return child;
    }).toList();

    return tree.copyWith(children: filteredChildren);
  }
}

