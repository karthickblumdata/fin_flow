import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/permission_service.dart';
import '../services/auth_service.dart';
import '../models/permission_node.dart';
import '../widgets/hierarchical_checkbox.dart';
import '../widgets/create_permission_dialog.dart';
import '../utils/responsive.dart';

class UserPermissionsDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final String userRole;

  const UserPermissionsDialog({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
  });

  @override
  State<UserPermissionsDialog> createState() => _UserPermissionsDialogState();
}

class _UserPermissionsDialogState extends State<UserPermissionsDialog> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  
  PermissionNode? _permissionTree;
  List<String> _rolePermissions = [];
  List<String> _userSpecificPermissions = [];
  List<Map<String, dynamic>> _allPermissions = [];
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await PermissionService.getUserPermissions(widget.userId);
      
      if (!mounted) return;

      if (result['success'] == true) {
        _rolePermissions = List<String>.from(result['rolePermissions'] ?? []);
        _userSpecificPermissions = List<String>.from(result['userSpecificPermissions'] ?? []);
        _allPermissions = List<Map<String, dynamic>>.from(result['allPermissions'] ?? []);
        
        // Build permission tree
        _permissionTree = _buildPermissionTree(_allPermissions, _userSpecificPermissions);
        
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result['message'] ?? 'Failed to load permissions';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading permissions: $e';
      });
    }
  }

  PermissionNode _buildPermissionTree(
    List<Map<String, dynamic>> permissions,
    List<String> selectedPermissions,
  ) {
    // Build a map of permission IDs to permission data
    final permissionMap = <String, Map<String, dynamic>>{};
    for (final perm in permissions) {
      permissionMap[perm['permissionId']] = perm;
    }

    // Build tree structure from permission IDs
    final root = PermissionNode(
      id: 'root',
      label: 'Root',
      isExpanded: true,
      children: [],
    );

    // Group permissions by category
    final categoryMap = <String, List<Map<String, dynamic>>>{};
    for (final perm in permissions) {
      final category = perm['category'] ?? 'other';
      categoryMap.putIfAbsent(category, () => []).add(perm);
    }

    // Build tree for each category
    for (final entry in categoryMap.entries) {
      final categoryNode = PermissionNode(
        id: entry.key,
        label: _capitalizeFirst(entry.key),
        isExpanded: false,
        children: [],
      );

      // Build hierarchical structure from permission IDs
      final permissionNodes = <String, PermissionNode>{};
      
      for (final perm in entry.value) {
        final permissionId = perm['permissionId'] as String;
        final isSelected = selectedPermissions.contains(permissionId);
        
        // Split permission ID by dots to build hierarchy
        final parts = permissionId.split('.');
        
        // Build path from root
        PermissionNode? currentNode = categoryNode;
        String currentPath = entry.key;
        
        for (int i = 0; i < parts.length; i++) {
          final part = parts[i];
          currentPath += '.$part';
          
          if (!permissionNodes.containsKey(currentPath)) {
            final isLeaf = i == parts.length - 1;
            final node = PermissionNode(
              id: currentPath,
              label: isLeaf 
                  ? (perm['label'] ?? _capitalizeFirst(part))
                  : _capitalizeFirst(part),
              description: isLeaf ? perm['description'] : null,
              isSelected: isLeaf ? isSelected : false,
              isExpanded: false,
              children: [],
            );
            permissionNodes[currentPath] = node;
            
            // Add to parent
            if (currentNode != null) {
              currentNode.children.add(node);
            }
          }
          
          currentNode = permissionNodes[currentPath];
        }
      }

      root.children.add(categoryNode);
    }

    // Update selection states
    root.updateSelectionState();
    return root;
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).replaceAll('_', ' ');
  }

  Future<void> _handleSave() async {
    if (_permissionTree == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Get all selected permission IDs
      final selectedPermissions = _permissionTree!.getSelectedPermissionIds();
      
      // Remove 'root' if present (not a real permission) and filter empty strings
      final cleanedPermissions = selectedPermissions
          .where((p) => p != 'root' && p.isNotEmpty && p.toLowerCase() != 'root')
          .toList();
      
      print('\n💾 ===== SAVING PERMISSIONS =====');
      print('   User ID: ${widget.userId}');
      print('   Selected Permissions Count: ${cleanedPermissions.length}');
      if (cleanedPermissions.isNotEmpty) {
        print('   Permissions: $cleanedPermissions');
      } else {
        print('   ⚠️  WARNING: No permissions selected!');
      }
      print('==================================\n');
      
      final result = await PermissionService.updateUserPermissions(
        widget.userId,
        cleanedPermissions,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Verify permissions were saved by checking the response
        final savedPermissions = result['user']?['userSpecificPermissions'] ?? [];
        print('✅ Permissions saved successfully: ${savedPermissions.length} permissions');
        if (savedPermissions.isNotEmpty) {
          print('   Saved permissions: $savedPermissions');
        }
        
        // If saving for current user, refresh their permissions
        final currentUserId = await AuthService.getUserId();
        if (currentUserId == widget.userId) {
          await AuthService.refreshPermissions();
          print('✅ Refreshed current user permissions after save');
        }
        
        Navigator.of(context).pop({
          'success': true,
          'message': 'Permissions updated successfully',
          'permissionsCount': savedPermissions.length,
          'permissions': savedPermissions,
        });
      } else {
        // Return error result so parent can handle it
        if (!mounted) return;
        Navigator.of(context).pop({
          'success': false,
          'message': result['message'] ?? 'Failed to update permissions',
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Return error result so parent can handle it
      Navigator.of(context).pop({
        'success': false,
        'message': 'Error updating permissions: $e',
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _handleCreatePermission() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CreatePermissionDialog(),
    );

    if (result != null && result['success'] == true) {
      // Reload permissions to include the new one
      await _loadPermissions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission "${result['permission']?['label']}" created successfully'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    }
  }

  void _handlePermissionChanged(PermissionNode node) {
    setState(() {
      // Update the tree by finding and replacing the node
      _permissionTree = _updateNodeInTree(_permissionTree!, node);
      _permissionTree!.updateSelectionState();
    });
  }

  PermissionNode _updateNodeInTree(PermissionNode root, PermissionNode updatedNode) {
    // If this is the node we're looking for, return the updated version
    if (root.id == updatedNode.id) {
      return updatedNode;
    }

    // Recursively update children
    final updatedChildren = root.children.map((child) {
      return _updateNodeInTree(child, updatedNode);
    }).toList();

    // Return updated root with updated children
    return root.copyWith(children: updatedChildren);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: isMobile ? double.infinity : (isTablet ? 700 : 900),
        height: isMobile ? double.infinity : 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Permissions Configuration',
                        style: AppTheme.headingMedium.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.userName} (${widget.userEmail})',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Role: ${widget.userRole}',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Search and Create Permission button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search permissions...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        // TODO: Implement search filtering
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleCreatePermission,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Permission'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Permissions Tree
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: AppTheme.errorColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.errorColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadPermissions,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _permissionTree == null
                          ? const Center(child: Text('No permissions available'))
                          : ListView.builder(
                              itemCount: _permissionTree!.children.length,
                              itemBuilder: (context, index) {
                                final child = _permissionTree!.children[index];
                                return HierarchicalCheckbox(
                                  node: child,
                                  onChanged: _handlePermissionChanged,
                                  isMobile: isMobile,
                                );
                              },
                            ),
            ),
            
            const SizedBox(height: 16),
            
            // Footer buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving 
                      ? null 
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save Permissions'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

