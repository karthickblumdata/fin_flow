import 'package:flutter/material.dart';
import '../utils/permission_mapper.dart';
import '../theme/app_theme.dart';

class PermissionPreviewWidget extends StatelessWidget {
  final List<String> selectedPermissions;

  const PermissionPreviewWidget({
    super.key,
    required this.selectedPermissions,
  });

  @override
  Widget build(BuildContext context) {
    final groupedPermissions = _groupPermissionsByCategory(selectedPermissions);
    final categoryConfigs = _getCategoryConfigs();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.visibility_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permission Preview',
                      style: AppTheme.headingSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Selected permissions grouped by category',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Category Cards
          if (groupedPermissions.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.errorColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.errorColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No permissions selected',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: groupedPermissions.entries.map((entry) {
                final categoryKey = entry.key;
                final subCategories = entry.value;
                final config = categoryConfigs[categoryKey];
                
                if (config == null) return const SizedBox.shrink();
                
                return _buildCategoryCard(
                  categoryLabel: config['label'] as String,
                  categoryIcon: config['icon'] as IconData,
                  categoryColor: config['color'] as Color,
                  subCategories: subCategories,
                  selectedPermissions: selectedPermissions,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // Group permissions by main category and sub-category
  Map<String, Map<String, List<String>>> _groupPermissionsByCategory(
    List<String> selectedPermissions,
  ) {
    final Map<String, Map<String, List<String>>> grouped = {};
    
    for (final permissionId in selectedPermissions) {
      final parts = permissionId.split('.');
      
      // Handle single-part permissions (e.g., "dashboard")
      if (parts.length == 1) {
        final mainCategory = parts[0];
        if (!grouped.containsKey(mainCategory)) {
          grouped[mainCategory] = {};
        }
        if (!grouped[mainCategory]!.containsKey('general')) {
          grouped[mainCategory]!['general'] = [];
        }
        grouped[mainCategory]!['general']!.add(permissionId);
        continue;
      }
      
      // Handle multi-part permissions
      final mainCategory = parts[0]; // 'wallet', 'expenses', 'smart_approvals', etc.
      final subCategory = _getSubCategory(permissionId);
      
      if (!grouped.containsKey(mainCategory)) {
        grouped[mainCategory] = {};
      }
      
      if (!grouped[mainCategory]!.containsKey(subCategory)) {
        grouped[mainCategory]![subCategory] = [];
      }
      
      grouped[mainCategory]![subCategory]!.add(permissionId);
    }
    
    return grouped;
  }

  // Extract sub-category from permission ID
  String _getSubCategory(String permissionId) {
    final parts = permissionId.split('.');
    if (parts.length >= 2) {
      // Handle nested categories
      if (parts[0] == 'wallet' && parts.length >= 3) {
        // wallet.self.transaction.create -> 'self_transaction'
        // wallet.all.transaction.create -> 'all_transaction'
        // wallet.self.transaction -> 'self_transaction' (parent node)
        return '${parts[1]}_${parts[2]}'; // 'self_transaction', 'all_transaction', etc.
      }
      if (parts[0] == 'smart_approvals' && parts.length >= 2) {
        return parts[1]; // 'transaction', 'collection', 'expenses'
      }
      if (parts[0] == 'all_users' && parts.length >= 2) {
        return parts[1]; // 'user_management', 'roles'
      }
      if (parts[0] == 'expenses' && parts.length >= 2) {
        return parts[1]; // 'expenses_type', 'expenses_report'
      }
      if (parts[0] == 'accounts' && parts.length >= 2) {
        return 'payment_account_reports'; // Single sub-category
      }
      if (parts[0] == 'dashboard') {
        // Handle dashboard permissions with better sub-categorization
        if (parts.length == 2) {
          // dashboard.view -> 'view'
          // dashboard.flagged_financial_flow -> 'flagged_financial_flow'
          return parts[1];
        } else if (parts.length >= 3) {
          // dashboard.flagged_financial_flow.enable -> 'flagged_financial_flow'
          return parts[1];
        }
        return 'dashboard'; // Fallback
      }
      if (parts.length >= 3 && parts[0] == 'dashboard' && parts[1] == 'quick_actions') {
        return 'dashboard'; // Quick Actions is now under dashboard
      }
    }
    return 'general';
  }

  // Get category configuration
  Map<String, Map<String, dynamic>> _getCategoryConfigs() {
    return {
      'dashboard': {
        'label': 'Dashboard',
        'icon': Icons.dashboard_outlined,
        'color': AppTheme.primaryColor,
      },
      'wallet': {
        'label': 'Wallet',
        'icon': Icons.account_balance_wallet_outlined,
        'color': AppTheme.accentBlue,
      },
      'smart_approvals': {
        'label': 'Smart Approvals',
        'icon': Icons.settings_outlined,
        'color': AppTheme.secondaryColor,
      },
      'all_users': {
        'label': 'All Users',
        'icon': Icons.people_outlined,
        'color': AppTheme.primaryColor,
      },
      'accounts': {
        'label': 'Accounts',
        'icon': Icons.account_balance_outlined,
        'color': AppTheme.accentBlue,
      },
      'expenses': {
        'label': 'Expenses',
        'icon': Icons.receipt_long_outlined,
        'color': AppTheme.secondaryColor,
      },
      'quick_actions': {
        'label': 'Quick Actions',
        'icon': Icons.flash_on_outlined,
        'color': AppTheme.warningColor,
      },
    };
  }

  // Format sub-category label (snake_case to Title Case)
  String _formatSubCategoryLabel(String subCategory) {
    // Special handling for wallet sub-categories
    if (subCategory.startsWith('self_') || subCategory.startsWith('all_')) {
      final parts = subCategory.split('_');
      if (parts.length >= 2) {
        final walletType = parts[0] == 'self' ? 'Self Wallet' : 'All User Wallets';
        final category = parts.sublist(1).join('_');
        final formattedCategory = category
            .split('_')
            .map((word) => word.isEmpty 
                ? '' 
                : word[0].toUpperCase() + word.substring(1))
            .join(' ');
        return '$walletType - $formattedCategory';
      }
    }
    
    // Default formatting: snake_case to Title Case
    return subCategory
        .split('_')
        .map((word) => word.isEmpty 
            ? '' 
            : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  // Get action icon map
  Map<String, IconData> _getActionIconMap() {
    return {
      'create': Icons.add_circle_outline,
      'add': Icons.add_circle_outline,
      'edit': Icons.edit_outlined,
      'delete': Icons.delete_outline,
      'remove': Icons.delete_outline,
      'view': Icons.visibility_outlined,
      'export': Icons.download_outlined,
      'approve': Icons.check_circle_outline,
      'reject': Icons.close,
      'flag': Icons.flag_outlined,
    };
  }

  // Get action color
  Color _getActionColor(String action) {
    switch (action) {
      case 'create':
      case 'add':
        return AppTheme.primaryColor;
      case 'edit':
        return AppTheme.accentBlue;
      case 'delete':
      case 'remove':
      case 'reject':
        return AppTheme.errorColor;
      case 'approve':
        return AppTheme.secondaryColor;
      case 'flag':
        return AppTheme.warningColor;
      case 'export':
        return AppTheme.textSecondary;
      case 'view':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textPrimary;
    }
  }

  // Extract action icons from permissions
  List<Map<String, dynamic>> _extractActionIcons(List<String> permissionIds) {
    final actionIconMap = _getActionIconMap();
    final actions = <String, Map<String, dynamic>>{};
    
    for (final permissionId in permissionIds) {
      final parts = permissionId.split('.');
      if (parts.isEmpty) continue;
      
      // Handle single-part permissions (e.g., "dashboard")
      if (parts.length == 1) {
        // Use a default icon for base permissions
        actions[parts[0]] = {
          'icon': Icons.check_circle_outline,
          'color': AppTheme.secondaryColor,
          'label': parts[0],
        };
        continue;
      }
      
      final action = parts.last; // 'create', 'edit', 'delete', etc.
      
      // Check if it's a recognized action
      final icon = actionIconMap[action];
      if (icon != null) {
        actions[action] = {
          'icon': icon,
          'color': _getActionColor(action),
          'label': action,
        };
      } else {
        // For unrecognized actions (e.g., "flagged_financial_flow", "enable"), 
        // show them with a default icon
        // Only add if it's not already added as a recognized action
        if (!actions.containsKey(action)) {
          actions[action] = {
            'icon': Icons.check_circle_outline,
            'color': AppTheme.textSecondary,
            'label': action.replaceAll('_', ' '),
          };
        }
      }
    }
    
    // Return in specific order: Add, Edit, Delete, Reject, Flag, Approve, Export, View
    final orderedActions = ['create', 'add', 'edit', 'delete', 'remove', 
                           'reject', 'flag', 'approve', 'export', 'view'];
    
    // First add recognized actions in order
    final recognizedActions = orderedActions
        .where((action) => actions.containsKey(action))
        .map((action) => actions[action]!)
        .toList();
    
    // Then add unrecognized actions
    final unrecognizedActions = actions.entries
        .where((entry) => !orderedActions.contains(entry.key))
        .map((entry) => entry.value)
        .toList();
    
    return [...recognizedActions, ...unrecognizedActions];
  }

  // Build category card widget
  Widget _buildCategoryCard({
    required String categoryLabel,
    required IconData categoryIcon,
    required Color categoryColor,
    required Map<String, List<String>> subCategories,
    required List<String> selectedPermissions,
  }) {
    final hasPermissions = subCategories.values
        .any((perms) => perms.any((p) => selectedPermissions.contains(p)));
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: categoryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPermissions 
              ? categoryColor.withOpacity(0.3)
              : AppTheme.borderColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card Header
          Row(
            children: [
              Icon(
                hasPermissions ? Icons.check_circle : Icons.cancel_outlined,
                size: 18,
                color: hasPermissions 
                    ? AppTheme.secondaryColor 
                    : AppTheme.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(width: 8),
              Icon(
                categoryIcon,
                size: 20,
                color: categoryColor,
              ),
              const SizedBox(width: 8),
              Text(
                categoryLabel,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Sub-Category Rows
          ...subCategories.entries.map((entry) {
            final subCategoryLabel = _formatSubCategoryLabel(entry.key);
            final permissionIds = entry.value;
            final actionIcons = _extractActionIcons(permissionIds);
            
            // Show even if no action icons - display permission IDs as text
            if (actionIcons.isEmpty && permissionIds.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$subCategoryLabel:',
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: permissionIds.map((permId) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: categoryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            permId,
                            style: AppTheme.bodySmall.copyWith(
                              fontSize: 11,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }
            
            if (actionIcons.isEmpty) return const SizedBox.shrink();
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Sub-Category Label
                  Flexible(
                    flex: 1,
                    child: Text(
                      '$subCategoryLabel:',
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Action Icons
                  Flexible(
                    flex: 2,
                    child: Wrap(
                      spacing: 6,
                      children: actionIcons.map((actionIcon) {
                        return Tooltip(
                          message: actionIcon['label'] as String,
                          child: Icon(
                            actionIcon['icon'] as IconData,
                            size: 16,
                            color: actionIcon['color'] as Color,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPreviewItem({
    required String itemKey,
    required bool isVisible,
    required List<String> selectedPermissions,
  }) {
    final label = PermissionMapper.getNavigationItemLabel(itemKey);
    final icon = PermissionMapper.getNavigationItemIcon(itemKey);
    final permissionGroups = _getScreenPermissionGroups(itemKey, selectedPermissions);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isVisible
            ? AppTheme.secondaryColor.withOpacity(0.1)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isVisible
              ? AppTheme.secondaryColor.withOpacity(0.3)
              : AppTheme.borderColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVisible ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: isVisible
                    ? AppTheme.secondaryColor
                    : AppTheme.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(width: 8),
              Icon(
                icon,
                size: 16,
                color: isVisible
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTheme.bodySmall.copyWith(
                  color: isVisible
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary.withOpacity(0.5),
                  fontWeight: isVisible ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
          
          // Permission Groups (only for visible screens with permissions)
          if (isVisible && permissionGroups.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 24), // Align with icon (16px checkmark + 8px spacing)
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: permissionGroups.map((group) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Category Label
                        Text(
                          '${group['label']}:',
                          style: AppTheme.bodySmall.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Sub-Permission Icons
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.start,
                          children: (group['permissions'] as List<Map<String, dynamic>>)
                              .map((perm) {
                            return Tooltip(
                              message: perm['label'] as String,
                              child: Icon(
                                perm['icon'] as IconData,
                                size: 14,
                                color: perm['color'] as Color,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getScreenPermissionGroups(
    String screenKey,
    List<String> selectedPermissions,
  ) {
    final groups = <Map<String, dynamic>>[];
    
    // Helper function to check if permission exists
    bool hasPermission(String permissionId) {
      return selectedPermissions.contains(permissionId) ||
          selectedPermissions.any((p) => p.startsWith(permissionId));
    }
    
    // Helper function to add sub-permission
    void addPermission(
      List<Map<String, dynamic>> permissions,
      String permissionId,
      IconData icon,
      String label,
      Color color,
    ) {
      if (selectedPermissions.contains(permissionId)) {
        permissions.add({
          'icon': icon,
          'label': label,
          'color': color,
        });
      }
    }
    
    switch (screenKey) {
      case 'wallet_self':
        // Transaction group
        if (hasPermission('wallet.self.transaction')) {
          final transactionPerms = <Map<String, dynamic>>[];
          addPermission(
            transactionPerms,
            'wallet.self.transaction.create',
            Icons.add_circle_outline,
            'Add',
            AppTheme.primaryColor,
          );
          addPermission(
            transactionPerms,
            'wallet.self.transaction.edit',
            Icons.edit_outlined,
            'Edit',
            AppTheme.accentBlue,
          );
          addPermission(
            transactionPerms,
            'wallet.self.transaction.delete',
            Icons.delete_outline,
            'Delete',
            AppTheme.errorColor,
          );
          addPermission(
            transactionPerms,
            'wallet.self.transaction.approve',
            Icons.check_circle_outline,
            'Approve',
            AppTheme.secondaryColor,
          );
          addPermission(
            transactionPerms,
            'wallet.self.transaction.reject',
            Icons.close,
            'Reject',
            AppTheme.errorColor,
          );
          addPermission(
            transactionPerms,
            'wallet.self.transaction.flag',
            Icons.flag_outlined,
            'Flag',
            AppTheme.warningColor,
          );
          addPermission(
            transactionPerms,
            'wallet.self.transaction.export',
            Icons.download_outlined,
            'Export',
            AppTheme.textSecondary,
          );
          
          if (transactionPerms.isNotEmpty) {
            groups.add({
              'label': 'Transaction',
              'permissions': transactionPerms,
            });
          }
        }
        
        // Expenses group
        if (hasPermission('wallet.self.expenses')) {
          final expensesPerms = <Map<String, dynamic>>[];
          addPermission(
            expensesPerms,
            'wallet.self.expenses.create',
            Icons.add_circle_outline,
            'Add',
            AppTheme.primaryColor,
          );
          addPermission(
            expensesPerms,
            'wallet.self.expenses.edit',
            Icons.edit_outlined,
            'Edit',
            AppTheme.accentBlue,
          );
          addPermission(
            expensesPerms,
            'wallet.self.expenses.delete',
            Icons.delete_outline,
            'Delete',
            AppTheme.errorColor,
          );
          addPermission(
            expensesPerms,
            'wallet.self.expenses.approve',
            Icons.check_circle_outline,
            'Approve',
            AppTheme.secondaryColor,
          );
          addPermission(
            expensesPerms,
            'wallet.self.expenses.reject',
            Icons.close,
            'Reject',
            AppTheme.errorColor,
          );
          addPermission(
            expensesPerms,
            'wallet.self.expenses.flag',
            Icons.flag_outlined,
            'Flag',
            AppTheme.warningColor,
          );
          addPermission(
            expensesPerms,
            'wallet.self.expenses.export',
            Icons.download_outlined,
            'Export',
            AppTheme.textSecondary,
          );
          
          if (expensesPerms.isNotEmpty) {
            groups.add({
              'label': 'Expenses',
              'permissions': expensesPerms,
            });
          }
        }
        
        // Collection group
        if (hasPermission('wallet.self.collection')) {
          final collectionPerms = <Map<String, dynamic>>[];
          addPermission(
            collectionPerms,
            'wallet.self.collection.create',
            Icons.add_circle_outline,
            'Add',
            AppTheme.primaryColor,
          );
          addPermission(
            collectionPerms,
            'wallet.self.collection.edit',
            Icons.edit_outlined,
            'Edit',
            AppTheme.accentBlue,
          );
          addPermission(
            collectionPerms,
            'wallet.self.collection.delete',
            Icons.delete_outline,
            'Delete',
            AppTheme.errorColor,
          );
          addPermission(
            collectionPerms,
            'wallet.self.collection.approve',
            Icons.check_circle_outline,
            'Approve',
            AppTheme.secondaryColor,
          );
          addPermission(
            collectionPerms,
            'wallet.self.collection.reject',
            Icons.close,
            'Reject',
            AppTheme.errorColor,
          );
          addPermission(
            collectionPerms,
            'wallet.self.collection.flag',
            Icons.flag_outlined,
            'Flag',
            AppTheme.warningColor,
          );
          addPermission(
            collectionPerms,
            'wallet.self.collection.export',
            Icons.download_outlined,
            'Export',
            AppTheme.textSecondary,
          );
          
          if (collectionPerms.isNotEmpty) {
            groups.add({
              'label': 'Collection',
              'permissions': collectionPerms,
            });
          }
        }
        break;
      
      case 'wallet_all':
        // Transaction group
        if (hasPermission('wallet.all.transaction')) {
          final transactionPerms = <Map<String, dynamic>>[];
          addPermission(
            transactionPerms,
            'wallet.all.transaction.create',
            Icons.add_circle_outline,
            'Add',
            AppTheme.primaryColor,
          );
          addPermission(
            transactionPerms,
            'wallet.all.transaction.remove',
            Icons.delete_outline,
            'Remove',
            AppTheme.errorColor,
          );
          addPermission(
            transactionPerms,
            'wallet.all.transaction.approve',
            Icons.check_circle_outline,
            'Approve',
            AppTheme.secondaryColor,
          );
          addPermission(
            transactionPerms,
            'wallet.all.transaction.reject',
            Icons.close,
            'Reject',
            AppTheme.errorColor,
          );
          addPermission(
            transactionPerms,
            'wallet.all.transaction.flag',
            Icons.flag_outlined,
            'Flag',
            AppTheme.warningColor,
          );
          addPermission(
            transactionPerms,
            'wallet.all.transaction.export',
            Icons.download_outlined,
            'Export',
            AppTheme.textSecondary,
          );
          
          if (transactionPerms.isNotEmpty) {
            groups.add({
              'label': 'Transaction',
              'permissions': transactionPerms,
            });
          }
        }
        
        // Collection group
        if (hasPermission('wallet.all.collection')) {
          final collectionPerms = <Map<String, dynamic>>[];
          addPermission(
            collectionPerms,
            'wallet.all.collection.create',
            Icons.add_circle_outline,
            'Add',
            AppTheme.primaryColor,
          );
          addPermission(
            collectionPerms,
            'wallet.all.collection.remove',
            Icons.delete_outline,
            'Remove',
            AppTheme.errorColor,
          );
          addPermission(
            collectionPerms,
            'wallet.all.collection.approve',
            Icons.check_circle_outline,
            'Approve',
            AppTheme.secondaryColor,
          );
          addPermission(
            collectionPerms,
            'wallet.all.collection.reject',
            Icons.close,
            'Reject',
            AppTheme.errorColor,
          );
          addPermission(
            collectionPerms,
            'wallet.all.collection.flag',
            Icons.flag_outlined,
            'Flag',
            AppTheme.warningColor,
          );
          addPermission(
            collectionPerms,
            'wallet.all.collection.export',
            Icons.download_outlined,
            'Export',
            AppTheme.textSecondary,
          );
          
          if (collectionPerms.isNotEmpty) {
            groups.add({
              'label': 'Collection',
              'permissions': collectionPerms,
            });
          }
        }
        
        // Expenses group
        if (hasPermission('wallet.all.expenses')) {
          final expensesPerms = <Map<String, dynamic>>[];
          addPermission(
            expensesPerms,
            'wallet.all.expenses.create',
            Icons.add_circle_outline,
            'Add',
            AppTheme.primaryColor,
          );
          addPermission(
            expensesPerms,
            'wallet.all.expenses.remove',
            Icons.delete_outline,
            'Remove',
            AppTheme.errorColor,
          );
          addPermission(
            expensesPerms,
            'wallet.all.expenses.approve',
            Icons.check_circle_outline,
            'Approve',
            AppTheme.secondaryColor,
          );
          addPermission(
            expensesPerms,
            'wallet.all.expenses.reject',
            Icons.close,
            'Reject',
            AppTheme.errorColor,
          );
          addPermission(
            expensesPerms,
            'wallet.all.expenses.flag',
            Icons.flag_outlined,
            'Flag',
            AppTheme.warningColor,
          );
          addPermission(
            expensesPerms,
            'wallet.all.expenses.export',
            Icons.download_outlined,
            'Export',
            AppTheme.textSecondary,
          );
          
          if (expensesPerms.isNotEmpty) {
            groups.add({
              'label': 'Expenses',
              'permissions': expensesPerms,
            });
          }
        }
        break;
      
      case 'smart_approvals':
        if (hasPermission('smart_approvals')) {
          final approvalPerms = <Map<String, dynamic>>[];
          addPermission(
            approvalPerms,
            'smart_approvals.approve',
            Icons.check_circle_outline,
            'Approve',
            AppTheme.secondaryColor,
          );
          addPermission(
            approvalPerms,
            'smart_approvals.reject',
            Icons.close,
            'Reject',
            AppTheme.errorColor,
          );
          addPermission(
            approvalPerms,
            'smart_approvals.flag',
            Icons.flag_outlined,
            'Flag',
            AppTheme.warningColor,
          );
          
          if (approvalPerms.isNotEmpty) {
            groups.add({
              'label': 'Approvals',
              'permissions': approvalPerms,
            });
          }
        }
        break;
      
      case 'all_users':
        // User Management group
        if (hasPermission('all_users.user_management')) {
          final userMgmtPerms = <Map<String, dynamic>>[];
          addPermission(
            userMgmtPerms,
            'all_users.user_management.edit',
            Icons.edit_outlined,
            'Edit',
            AppTheme.accentBlue,
          );
          addPermission(
            userMgmtPerms,
            'all_users.user_management.delete',
            Icons.delete_outline,
            'Delete',
            AppTheme.errorColor,
          );
          
          if (userMgmtPerms.isNotEmpty) {
            groups.add({
              'label': 'User Management',
              'permissions': userMgmtPerms,
            });
          }
        }
        
        // Roles group
        if (hasPermission('all_users.roles')) {
          final rolesPerms = <Map<String, dynamic>>[];
          addPermission(
            rolesPerms,
            'all_users.roles.edit',
            Icons.edit_outlined,
            'Edit',
            AppTheme.accentBlue,
          );
          addPermission(
            rolesPerms,
            'all_users.roles.delete',
            Icons.delete_outline,
            'Delete',
            AppTheme.errorColor,
          );
          
          if (rolesPerms.isNotEmpty) {
            groups.add({
              'label': 'Roles',
              'permissions': rolesPerms,
            });
          }
        }
        break;
      
      case 'accounts':
        if (hasPermission('accounts.payment_account_reports')) {
          final accountPerms = <Map<String, dynamic>>[];
          
          // Check if parent permission is selected (without children)
          final hasParentOnly = selectedPermissions.contains('accounts.payment_account_reports') &&
              !selectedPermissions.any((p) => p.startsWith('accounts.payment_account_reports.') && p != 'accounts.payment_account_reports');
          
          // If parent is selected but no children, show parent permission
          if (hasParentOnly) {
            accountPerms.add({
              'icon': Icons.check_circle_outline,
              'label': 'Payment/Account Reports',
              'color': AppTheme.secondaryColor,
            });
          } else {
            // Show selected child permissions
            addPermission(
              accountPerms,
              'accounts.payment_account_reports.create',
              Icons.add_circle_outline,
              'Add',
              AppTheme.primaryColor,
            );
            addPermission(
              accountPerms,
              'accounts.payment_account_reports.edit',
              Icons.edit_outlined,
              'Edit',
              AppTheme.accentBlue,
            );
            addPermission(
              accountPerms,
              'accounts.payment_account_reports.delete',
              Icons.delete_outline,
              'Delete',
              AppTheme.errorColor,
            );
            addPermission(
              accountPerms,
              'accounts.payment_account_reports.export',
              Icons.download_outlined,
              'Export As',
              AppTheme.textSecondary,
            );
            addPermission(
              accountPerms,
              'accounts.payment_account_reports.view',
              Icons.visibility_outlined,
              'View',
              AppTheme.textSecondary,
            );
          }
          
          if (accountPerms.isNotEmpty) {
            groups.add({
              'label': 'Payment Account Reports',
              'permissions': accountPerms,
            });
          }
        }
        break;
      
      case 'expenses':
        // Expenses Type group
        if (hasPermission('expenses.expenses_type')) {
          final typePerms = <Map<String, dynamic>>[];
          addPermission(
            typePerms,
            'expenses.expenses_type.create',
            Icons.add_circle_outline,
            'Add',
            AppTheme.primaryColor,
          );
          addPermission(
            typePerms,
            'expenses.expenses_type.edit',
            Icons.edit_outlined,
            'Edit',
            AppTheme.accentBlue,
          );
          addPermission(
            typePerms,
            'expenses.expenses_type.delete',
            Icons.delete_outline,
            'Delete',
            AppTheme.errorColor,
          );
          addPermission(
            typePerms,
            'expenses.expenses_type.view',
            Icons.visibility_outlined,
            'View',
            AppTheme.textSecondary,
          );
          
          if (typePerms.isNotEmpty) {
            groups.add({
              'label': 'Expenses Type',
              'permissions': typePerms,
            });
          }
        }
        
        // Expenses Report group
        if (hasPermission('expenses.expenses_report')) {
          final reportPerms = <Map<String, dynamic>>[];
          addPermission(
            reportPerms,
            'expenses.expenses_report.create',
            Icons.add_circle_outline,
            'Add',
            AppTheme.primaryColor,
          );
          addPermission(
            reportPerms,
            'expenses.expenses_report.edit',
            Icons.edit_outlined,
            'Edit',
            AppTheme.accentBlue,
          );
          addPermission(
            reportPerms,
            'expenses.expenses_report.delete',
            Icons.delete_outline,
            'Delete',
            AppTheme.errorColor,
          );
          addPermission(
            reportPerms,
            'expenses.expenses_report.view',
            Icons.visibility_outlined,
            'View',
            AppTheme.textSecondary,
          );
          addPermission(
            reportPerms,
            'expenses.expenses_report.export',
            Icons.download_outlined,
            'Export',
            AppTheme.secondaryColor,
          );
          
          if (reportPerms.isNotEmpty) {
            groups.add({
              'label': 'Expenses Report',
              'permissions': reportPerms,
            });
          }
        }
        break;
      
      case 'dashboard':
        // Dashboard includes Quick Actions as a sub-section
        break;
    }
    
    return groups;
  }
}

