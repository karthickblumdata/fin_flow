import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/user_service.dart';
import '../../services/role_service.dart';
import '../../services/permission_service.dart';
import '../../services/socket_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../utils/permission_tree_builder.dart';
import '../../utils/permission_mapper.dart';
import '../../widgets/screen_back_button.dart';
import '../../widgets/hierarchical_checkbox.dart';
import '../../widgets/permission_preview_widget.dart';
import '../../models/permission_node.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({
    super.key,
    this.embedInDashboard = false,
    this.highlightRole, // Role to highlight when screen loads
  });

  final bool embedInDashboard;
  final String? highlightRole; // Role name to highlight

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  static const String _editRoleComingSoonMessage =
      'Edit role management is coming soon.';
  static const String _createRoleComingSoonMessage =
      'Role creation is coming soon.';

  bool _isLoading = true;
  String? _errorMessage;
  List<_RoleSummary> _roleSummaries = const [];
  int _totalUsers = 0;
  Timer? _refreshDebounceTimer;
  
  // Debounce configuration for socket-based refresh
  static const Duration _debounceRefreshDelay = Duration(seconds: 2); // Debounce to prevent rapid refreshes
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    _loadRoles();
    _setupSocketListener();
  }

  @override
  void dispose() {
    _refreshDebounceTimer?.cancel();
    SocketService.offUserCreated();
    super.dispose();
  }

  void _setupSocketListener() {
    SocketService.onUserCreated((data) {
      if (mounted) {
        final userName = data['userName'] ?? data['name'] ?? 'Unknown';
        final userRole = data['userRole'] ?? data['role'] ?? 'Unknown';
        print('📢 New user created: $userName ($userRole)');
        _debouncedRefresh();
      }
    });
    
    // Listen to dashboard updates (general updates)
    SocketService.onDashboardUpdate((data) {
      if (mounted) {
        _autoRefreshRoles();
      }
    });
    
    // Listen to amount updates (user creation emits this)
    SocketService.onAmountUpdate((data) {
      if (mounted) {
        // Check if this is a user_created event
        if (data is Map<String, dynamic> && data['type'] == 'user_created') {
          _autoRefreshRoles();
        }
      }
    });
  }

  void _debouncedRefresh() {
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadRoles();
      }
    });
  }

  /// Auto-refresh method with debouncing to prevent excessive API calls
  /// This method is called by socket events when roles data changes
  void _autoRefreshRoles() {
    if (!mounted) return;
    
    // Debounce: Don't refresh if we just refreshed recently
    if (_lastRefreshTime != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
      if (timeSinceLastRefresh < _debounceRefreshDelay) {
        // Too soon since last refresh, skip this one
        return;
      }
    }
    
    // Don't refresh if already loading
    if (_isLoading) {
      return;
    }
    
    // Update last refresh time
    _lastRefreshTime = DateTime.now();
    
    // Refresh roles data silently
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('\n🔄 ===== LOADING ROLES AND USERS =====');
      print('   Timestamp: ${DateTime.now().toIso8601String()}');
      
      final result = await UserService.getUsers();
      if (!mounted) return;

      if (result['success'] == true) {
        final users = (result['users'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();

        print('📊 Roles Screen: Loaded ${users.length} users from API');
        
        // Log user permissions for debugging
        for (final user in users.take(5)) { // Log first 5 users
          final userId = user['id'] ?? user['_id'];
          final userName = user['name'] ?? 'Unknown';
          final userEmail = user['email'] ?? '';
          final permissions = user['userSpecificPermissions'] as List<dynamic>? ?? [];
          print('   User: $userName ($userEmail) - Permissions: ${permissions.length}');
        }
        
        // Log admin@examples.com if present
        Map<String, dynamic>? adminUser;
        try {
          adminUser = users.firstWhere(
            (u) => (u['email']?.toString().toLowerCase() ?? '') == 'admin@examples.com',
          ) as Map<String, dynamic>?;
        } catch (e) {
          adminUser = null;
        }
        
        if (adminUser != null) {
          print('✅ Found admin@examples.com user: ${adminUser['name']}, role: ${adminUser['role']}');
        } else {
          print('⚠️  admin@examples.com user not found in API response');
        }

        final Map<String, _RoleAccumulator> accumulator = {};
        for (final user in users) {
          // Ensure we have valid user data
          if (user == null) continue;
          
          final userId = user['id'] ?? user['_id'];
          final userEmail = user['email']?.toString() ?? '';
          final userName = user['name']?.toString() ?? 'Unknown';
          final userRole = _normalizeRole(user['role']);
          final isVerified = user['isVerified'] == true;

          // Skip if no valid ID
          if (userId == null) {
            print('⚠️  Skipping user without ID: $userEmail');
            continue;
          }

          final entry = accumulator.putIfAbsent(userRole, _RoleAccumulator.new);
          entry.total += 1;
          if (isVerified) {
            entry.active += 1;
          } else {
            entry.inactive += 1;
          }
          entry.users.add(
            {
              'id': userId,
              'name': userName,
              'fullName': user['fullName'] ?? userName,
              'email': userEmail,
              'phoneNumber': user['phoneNumber'] ?? user['phone'] ?? user['mobile'] ?? user['mobileNumber'] ?? '',
              'role': userRole,
              'isVerified': isVerified,
              'status': isVerified ? 'Active' : 'Inactive',
              'createdAt': user['createdAt'] ?? user['created_at'] ?? user['createdAt'],
            },
          );
        }
        
        print('📊 Roles Screen: Grouped users into ${accumulator.length} roles');
        print('✅ ===== ROLES LOADED SUCCESSFULLY =====\n');

        final summaries = accumulator.entries
            .map(
              (entry) => _RoleSummary(
                role: entry.key,
                totalUsers: entry.value.total,
                activeUsers: entry.value.active,
                inactiveUsers: entry.value.inactive,
                assignedUsers: List<Map<String, dynamic>>.unmodifiable(
                  entry.value.users,
                ),
              ),
            )
            .toList()
          ..sort((a, b) => a.role.toLowerCase().compareTo(b.role.toLowerCase()));

        setState(() {
          _roleSummaries = summaries;
          _totalUsers = users.length;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = (result['message'] ?? 'Unable to load roles').toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);

    if (widget.embedInDashboard) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBackButton(fallbackRoute: '/super-admin-dashboard'),
        title: const Text('Roles'),
        actions: [
          // Quick Actions button
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bolt,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Quick Actions',
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            offset: const Offset(0, 50),
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.1),
            surfaceTintColor: Colors.transparent,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (String value) {
              if (value == 'create_role') {
                _onCreateRolePressed();
              } else if (value == 'add_user') {
                context.push('/manage-users');
              }
            },
            itemBuilder: (BuildContext context) {
              // Use the same solid color as Quick Actions button (AppTheme.primaryColor)
              final menuItemBgColor = AppTheme.primaryColor;
              
              return [
                PopupMenuItem<String>(
                  value: 'create_role',
                  padding: EdgeInsets.zero,
                  child: Material(
                    color: menuItemBgColor,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.pop(context);
                        _onCreateRolePressed();
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Create Role',
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'add_user',
                  padding: EdgeInsets.zero,
                  child: Material(
                    color: menuItemBgColor,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/manage-users');
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_add_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Add User',
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ];
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState(context);
    }

    if (_roleSummaries.isEmpty) {
      return _buildEmptyState(context);
    }

    final isMobile = Responsive.isMobile(context);
    final horizontalPadding = isMobile ? 16.0 : 24.0;

    return RefreshIndicator(
      onRefresh: _loadRoles,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          isMobile ? 16 : 24,
          horizontalPadding,
          isMobile ? 24 : 32,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildOverviewHeader(context),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const double spacing = 16;
              final double maxWidth = constraints.maxWidth;
              final bool isCompactWidth = maxWidth < 520;
              final bool isTabletWidth = maxWidth < 980;
              final int columns =
                  isCompactWidth ? 1 : (isTabletWidth ? 2 : 3);
              final double availableWidth =
                  maxWidth - spacing * (columns - 1);
              final double cardWidth =
                  columns > 0 ? availableWidth / columns : maxWidth;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _roleSummaries
                    .map(
                      (summary) => SizedBox(
                        width: cardWidth,
                        child: _buildRoleCard(context, summary),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompactHeader = constraints.maxWidth < 640;
              final TextStyle baseTitleStyle =
                  theme.textTheme.titleMedium ?? AppTheme.headingSmall;
              final Widget titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Roles Overview',
                    style: baseTitleStyle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track user distribution and activation status across roles in real time.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              );
              final Widget actions = _buildOverviewActions(
                context,
                isCompact: isCompactHeader,
              );

              if (isCompactHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 12),
                    actions,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleSection),
                  const SizedBox(width: 16),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const double spacing = 6;
              final double maxWidth = constraints.maxWidth;
              final bool isCompactWidth = maxWidth < 520;
              final bool isTabletWidth = maxWidth < 920;
              final int columns = isCompactWidth
                  ? 1
                  : (isTabletWidth ? 2 : 3);
              final double availableWidth =
                  maxWidth - spacing * (columns - 1);
              final double cardWidth =
                  columns > 0 ? availableWidth / columns : maxWidth;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _buildOverviewStat(
                    context,
                    label: 'Distinct Roles',
                    value: _roleSummaries.length.toString(),
                    icon: Icons.label_important_outline,
                    cardWidth: cardWidth,
                  ),
                  _buildOverviewStat(
                    context,
                    label: 'Total Users',
                    value: _totalUsers.toString(),
                    icon: Icons.people_alt_outlined,
                    cardWidth: cardWidth,
                  ),
                  _buildOverviewStat(
                    context,
                    label: 'Active Ratio',
                    value: _formatActivationRatio(),
                    icon: Icons.trending_up,
                    cardWidth: cardWidth,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewActions(
    BuildContext context, {
    required bool isCompact,
  }) {
    final double horizontalPadding = isCompact ? 12 : 16;
    final double verticalPadding = isCompact ? 8 : 10;
    final TextStyle labelStyle = AppTheme.bodySmall.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: isCompact ? 12 : 13,
    );

    final ButtonStyle actionStyle = OutlinedButton.styleFrom(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      side: BorderSide(
        color: AppTheme.primaryColor.withValues(alpha: 0.6),
      ),
      foregroundColor: AppTheme.primaryColor,
    );

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: _onCreateRolePressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: Icon(
            Icons.add_circle_outline,
            size: isCompact ? 16 : 18,
            color: Colors.white,
          ),
          label: Text(
            'Create Role',
            style: labelStyle.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _onCreateRolePressed() {
    _showCreateRoleDialog();
  }

  Future<void> _showCreateRoleDialog() async {
    final isMobile = Responsive.isMobile(context);
    final permissionTree = PermissionTreeBuilder.buildDefaultPermissionTree();
    final formKey = GlobalKey<FormState>();
    PermissionNode currentTree = permissionTree;
    bool isSubmitting = false;
    
    final nameController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 32,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: isMobile ? double.infinity : 650,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with gradient
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.badge_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create Role',
                                    style: AppTheme.headingMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Configure permissions for user role',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              onPressed: isSubmitting
                                  ? null
                                  : () {
                                      nameController.dispose();
                                      Navigator.of(dialogContext).pop();
                                    },
                            ),
                          ],
                        ),
                      ),

                      // Form Content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Name Field
                              Text(
                                'Name',
                                style: AppTheme.labelMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: nameController,
                                decoration: InputDecoration(
                                  hintText: 'Enter name',
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
                                    color: AppTheme.primaryColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter a name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 32),

                              // Configure User Role Section
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.settings_outlined,
                                      color: AppTheme.secondaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Configure User Role',
                                    style: AppTheme.headingSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Permission Tree
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(16),
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
                                constraints: const BoxConstraints(
                                  maxHeight: 450,
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: currentTree.children.map((node) {
                                      final nodeIndex = currentTree.children.indexOf(node);
                                      return HierarchicalCheckbox(
                                        key: ValueKey('${node.id}_$nodeIndex'),
                                        node: node,
                                        onChanged: (updatedNode) {
                                          setDialogState(() {
                                            final updatedChildren =
                                                List<PermissionNode>.from(
                                                    currentTree.children);
                                            updatedChildren[nodeIndex] = updatedNode;
                                            currentTree = currentTree.copyWith(
                                              children: updatedChildren,
                                            );
                                            currentTree.updateSelectionState();
                                          });
                                        },
                                        isMobile: isMobile,
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Permission Preview
                              PermissionPreviewWidget(
                                selectedPermissions: currentTree.getSelectedPermissionIds(),
                              ),
                              const SizedBox(height: 24),

                              // Icon Reference
                              _buildIconReference(isMobile: isMobile),
                            ],
                          ),
                        ),
                      ),

                      // Action Buttons
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor.withOpacity(0.5),
                          border: Border(
                            top: BorderSide(
                              color: AppTheme.borderColor.withOpacity(0.5),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () {
                                      nameController.dispose();
                                      Navigator.of(dialogContext).pop();
                                    },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (formKey.currentState!.validate()) {
                                        setDialogState(() {
                                          isSubmitting = true;
                                        });

                                        try {
                                          final allSelectedPermissions =
                                              currentTree.getSelectedPermissionIds();
                                          
                                          // Filter out root node ID and empty strings
                                          final selectedPermissions = allSelectedPermissions
                                              .where((id) => id.isNotEmpty && id != 'root')
                                              .toList();

                                          // Debug logging
                                          print('💾 Creating role with permissions');
                                          print('   Selected ${selectedPermissions.length} permission IDs');
                                          if (selectedPermissions.isNotEmpty) {
                                            print('   Sample IDs: ${selectedPermissions.take(5).join(', ')}');
                                          }

                                          // Validate permissions
                                          if (selectedPermissions.isEmpty) {
                                            setDialogState(() {
                                              isSubmitting = false;
                                            });
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.warning_amber_rounded,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        'Please select at least one permission',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: AppTheme.errorColor,
                                                duration: const Duration(seconds: 3),
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          final visibleItems = PermissionMapper.getVisibleNavigationItems(selectedPermissions);
                                          if (visibleItems.isEmpty) {
                                            // Show warning but allow to proceed
                                            final shouldProceed = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Row(
                                                  children: [
                                                    Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
                                                    const SizedBox(width: 12),
                                                    const Text('Warning'),
                                                  ],
                                                ),
                                                content: Text(
                                                  'No screens will be visible with the selected permissions. Do you want to continue?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(context, true),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppTheme.errorColor,
                                                    ),
                                                    child: const Text('Continue'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (shouldProceed != true) {
                                              setDialogState(() {
                                                isSubmitting = false;
                                              });
                                              return;
                                            }
                                          }

                                          final result =
                                              await RoleService.createRole(
                                            roleName: nameController.text.trim(),
                                            permissionIds: selectedPermissions,
                                            name: nameController.text.trim(),
                                          );

                                          if (mounted) {
                                            if (result['success'] == true) {
                                              // Clear all permission caches to ensure changes reflect everywhere
                                              await PermissionService.clearAllCaches();
                                              
                                              // Refresh current user permissions if they have this role
                                              try {
                                                final userRole = await AuthService.getUserRole();
                                                if (userRole == nameController.text.trim() || userRole == 'SuperAdmin') {
                                                  await AuthService.refreshPermissions();
                                                }
                                              } catch (e) {
                                                print('⚠️  Could not refresh permissions: $e');
                                              }
                                              
                                              nameController.dispose();
                                              Navigator.of(dialogContext).pop();
                                              
                                              final visibleCount = visibleItems.length;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                            Icons.check_circle,
                                                            color: Colors.white,
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Expanded(
                                                            child: Text(
                                                              result['message'] ??
                                                                  'Role permissions configured successfully',
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (visibleCount > 0) ...[
                                                        const SizedBox(height: 8),
                                                        Text(
                                                          '$visibleCount screen(s) will be visible to users with this role',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.white.withOpacity(0.9),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  backgroundColor:
                                                      AppTheme.secondaryColor,
                                                  duration:
                                                      const Duration(seconds: 4),
                                                  behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                              );
                                              // Reload roles
                                              _loadRoles();
                                            } else {
                                              setDialogState(() {
                                                isSubmitting = false;
                                              });
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.error_outline,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          result['message'] ??
                                                              'Failed to configure role',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  backgroundColor:
                                                      AppTheme.errorColor,
                                                  duration:
                                                      const Duration(seconds: 3),
                                                  behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            setDialogState(() {
                                              isSubmitting = false;
                                            });
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Error: ${e.toString().replaceFirst('Exception: ', '')}'),
                                                backgroundColor:
                                                    AppTheme.errorColor,
                                                duration:
                                                    const Duration(seconds: 3),
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                      ),
                                    )
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Create Role',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onEditRolesPressed() {
    _showRoleSelectionDialog();
  }

  Future<void> _showRoleSelectionDialog() async {
    if (_roleSummaries.isEmpty) {
      _showComingSoonSnackBar('No roles available to edit', Icons.info_outline);
      return;
    }

    final isMobile = Responsive.isMobile(context);

    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: isMobile ? double.infinity : 500,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Role to Edit',
                              style: AppTheme.headingMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose a role to modify its permissions',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),

                // Role List
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _roleSummaries.length,
                    itemBuilder: (context, index) {
                      final role = _roleSummaries[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: AppTheme.borderColor.withOpacity(0.5),
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            _showEditRoleDialog(role);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.badge,
                                    color: AppTheme.primaryColor,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        role.role,
                                        style: AppTheme.headingSmall.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${role.totalUsers} user(s) • ${role.activeUsers} active',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditRoleDialog(_RoleSummary roleSummary) async {
    final isMobile = Responsive.isMobile(context);
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    bool isLoadingPermissions = true;
    String? errorMessage;

    // Extract role name from summary
    final roleName = roleSummary.role;
    
    // Create controller for editable name field
    final nameController = TextEditingController(text: roleName);

    // Load existing permissions
    List<String> existingPermissionIds = [];
    try {
      final permissionsResult = await RoleService.getRolePermissions(roleName);
    
    if (permissionsResult['success'] == true) {
      existingPermissionIds = List<String>.from(permissionsResult['permissions'] ?? [])
          .where((id) => id.isNotEmpty && id != 'root') // Filter out empty and root IDs
          .toList();
      
      // Debug logging
      print('📋 Loading permissions for role: $roleName');
      print('   Found ${existingPermissionIds.length} permission IDs');
      if (existingPermissionIds.isNotEmpty) {
        print('   Sample IDs: ${existingPermissionIds.take(5).join(', ')}');
      }
      } else {
        errorMessage = permissionsResult['message'] ?? 'Failed to load permissions';
      }
    } catch (e) {
      errorMessage = 'Error loading permissions: ${e.toString()}';
      print('❌ Error loading permissions: $e');
    }

    // Build permission tree with existing permissions
    final permissionTree = PermissionTreeBuilder.buildDefaultPermissionTree();
    PermissionNode currentTree = PermissionTreeBuilder.applyPermissions(
      permissionTree,
      existingPermissionIds,
    );
    
    // Verify permissions were applied
    final appliedIds = currentTree.getSelectedPermissionIds()
        .where((id) => id != 'root')
        .toList();
    print('✅ Applied ${appliedIds.length} permissions to tree');

    isLoadingPermissions = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return WillPopScope(
              onWillPop: () async {
                nameController.dispose();
                return true;
              },
              child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 32,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: isMobile ? double.infinity : 650,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: isLoadingPermissions
                    ? const Center(child: CircularProgressIndicator())
                    : Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryColor,
                                    AppTheme.primaryColor.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.edit_outlined,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Edit Role: $roleName',
                                          style: AppTheme.headingMedium.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Update permissions for this role',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    onPressed: isSubmitting
                                        ? null
                                        : () {
                                            nameController.dispose();
                                            Navigator.of(dialogContext).pop();
                                          },
                                  ),
                                ],
                              ),
                            ),

                            // Form Content
                            Flexible(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Name (Editable)
                                    Text(
                                      'Name',
                                      style: AppTheme.labelMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: nameController,
                                      decoration: InputDecoration(
                                        hintText: 'Enter role name',
                                        prefixIcon: Icon(
                                          Icons.badge,
                                          color: AppTheme.primaryColor,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: AppTheme.borderColor.withOpacity(0.5),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: AppTheme.borderColor.withOpacity(0.5),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: AppTheme.primaryColor,
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: AppTheme.surfaceColor,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                      ),
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Role name is required';
                                        }
                                        if (value.trim().length < 2) {
                                          return 'Role name must be at least 2 characters';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 24),

                                    // Error Message (if any)
                                    if (errorMessage != null) ...[
                                    Container(
                                        padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: AppTheme.errorColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AppTheme.errorColor.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                              Icons.error_outline,
                                              color: AppTheme.errorColor,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                errorMessage!,
                                                style: AppTheme.bodySmall.copyWith(
                                                  color: AppTheme.errorColor,
                                              fontWeight: FontWeight.w500,
                                                ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    ],

                                    // Configure User Role Section
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.secondaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.settings_outlined,
                                            color: AppTheme.secondaryColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Configure User Role',
                                          style: AppTheme.headingSmall.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Permission Tree
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceColor,
                                        borderRadius: BorderRadius.circular(16),
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
                                      constraints: const BoxConstraints(
                                        maxHeight: 450,
                                      ),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: currentTree.children.map((node) {
                                            final nodeIndex = currentTree.children.indexOf(node);
                                            return HierarchicalCheckbox(
                                              key: ValueKey('${node.id}_$nodeIndex'),
                                              node: node,
                                              onChanged: (updatedNode) {
                                                setDialogState(() {
                                                  final updatedChildren =
                                                      List<PermissionNode>.from(
                                                          currentTree.children);
                                                  updatedChildren[nodeIndex] = updatedNode;
                                                  currentTree = currentTree.copyWith(
                                                    children: updatedChildren,
                                                  );
                                                  currentTree.updateSelectionState();
                                                });
                                              },
                                              isMobile: isMobile,
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Permission Preview
                                    PermissionPreviewWidget(
                                      selectedPermissions: currentTree.getSelectedPermissionIds(),
                                    ),
                                    const SizedBox(height: 24),

                                    // Icon Reference
                                    _buildIconReference(isMobile: isMobile),
                                  ],
                                ),
                              ),
                            ),

                            // Action Buttons
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor.withOpacity(0.5),
                                border: Border(
                                  top: BorderSide(
                                    color: AppTheme.borderColor.withOpacity(0.5),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: isSubmitting
                                        ? null
                                        : () {
                                            nameController.dispose();
                                            Navigator.of(dialogContext).pop();
                                          },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: isSubmitting
                                        ? null
                                        : () async {
                                            try {
                                              // Validate form (including name field)
                                              if (!formKey.currentState!.validate()) {
                                                return;
                                              }

                                              final newName = nameController.text.trim();
                                              final allSelectedPermissions =
                                                  currentTree.getSelectedPermissionIds();
                                              
                                              // Filter out root node ID and empty strings
                                              final selectedPermissions = allSelectedPermissions
                                                  .where((id) => id.isNotEmpty && id != 'root')
                                                  .toList();

                                              // Debug logging
                                              print('💾 Saving permissions for role: $roleName');
                                              print('   Selected ${selectedPermissions.length} permission IDs');
                                              if (selectedPermissions.isNotEmpty) {
                                                print('   Sample IDs: ${selectedPermissions.take(5).join(', ')}');
                                              }

                                              // Validate permissions
                                              if (selectedPermissions.isEmpty) {
                                                setDialogState(() {
                                                  isSubmitting = false;
                                                });
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.warning_amber_rounded,
                                                          color: Colors.white,
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Expanded(
                                                          child: Text(
                                                            'Please select at least one permission',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    backgroundColor: AppTheme.errorColor,
                                                    duration: const Duration(seconds: 3),
                                                    behavior: SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              final visibleItems = PermissionMapper.getVisibleNavigationItems(selectedPermissions);
                                              
                                              setDialogState(() {
                                                isSubmitting = true;
                                              });

                                              // Update role permissions (and name if changed)
                                              final result = await RoleService.updateRolePermissions(
                                                roleName: roleName,
                                                permissionIds: selectedPermissions,
                                                newName: newName != roleName ? newName : null,
                                              );

                                              if (mounted) {
                                                if (result['success'] == true) {
                                                  // Clear all permission caches to ensure changes reflect everywhere
                                                  await PermissionService.clearAllCaches();
                                                  
                                                  // Refresh current user permissions if they have this role
                                                  try {
                                                    final userRole = await AuthService.getUserRole();
                                                    if (userRole == roleName || userRole == 'SuperAdmin') {
                                                      await AuthService.refreshPermissions();
                                                    }
                                                  } catch (e) {
                                                    print('⚠️  Could not refresh permissions: $e');
                                                  }
                                                  
                                                  nameController.dispose();
                                                  Navigator.of(dialogContext).pop();
                                                  
                                                  final visibleCount = visibleItems.length;
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              const Icon(
                                                                Icons.check_circle,
                                                                color: Colors.white,
                                                              ),
                                                              const SizedBox(width: 12),
                                                              Expanded(
                                                                child: Text(
                                                                  result['message'] ??
                                                                      'Role permissions updated successfully',
                                                                  style: const TextStyle(
                                                                    fontWeight: FontWeight.w600,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          if (visibleCount > 0) ...[
                                                            const SizedBox(height: 8),
                                                            Text(
                                                              '$visibleCount screen(s) will be visible to users with this role',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors.white.withOpacity(0.9),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      backgroundColor: AppTheme.secondaryColor,
                                                      duration: const Duration(seconds: 4),
                                                      behavior: SnackBarBehavior.floating,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                    ),
                                                  );
                                                  // Reload roles
                                                  _loadRoles();
                                                } else {
                                                  setDialogState(() {
                                                    isSubmitting = false;
                                                  });
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Row(
                                                        children: [
                                                          const Icon(
                                                            Icons.error_outline,
                                                            color: Colors.white,
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Expanded(
                                                            child: Text(
                                                              result['message'] ??
                                                                  'Failed to update role permissions',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      backgroundColor: AppTheme.errorColor,
                                                      duration: const Duration(seconds: 3),
                                                      behavior: SnackBarBehavior.floating,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                setDialogState(() {
                                                  isSubmitting = false;
                                                });
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Error: ${e.toString().replaceFirst('Exception: ', '')}'),
                                                    backgroundColor: AppTheme.errorColor,
                                                    duration: const Duration(seconds: 3),
                                                    behavior: SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.secondaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: isSubmitting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                            ),
                                          )
                                        : const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.save, size: 20),
                                              SizedBox(width: 8),
                                              Text(
                                                'Update Role',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                ),
            );
          },
        );
      },
    );
  }

  void _showComingSoonSnackBar(String message, IconData icon) {
    if (!mounted) {
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.92),
        content: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Build icon reference widget showing what each action icon means
  Widget _buildIconReference({bool isMobile = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Icon Reference',
                style: AppTheme.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: isMobile ? 12 : 16,
            runSpacing: 8,
            children: [
              _buildIconReferenceItem(Icons.add_circle_outline, 'Add', isMobile),
              _buildIconReferenceItem(Icons.edit_outlined, 'Edit', isMobile),
              _buildIconReferenceItem(Icons.delete_outline, 'Delete', isMobile),
              _buildIconReferenceItem(Icons.close, 'Reject', isMobile),
              _buildIconReferenceItem(Icons.flag_outlined, 'Flag', isMobile),
              _buildIconReferenceItem(Icons.check_circle_outline, 'Approve', isMobile),
              _buildIconReferenceItem(Icons.download_outlined, 'Export As', isMobile),
              _buildIconReferenceItem(Icons.visibility_outlined, 'View', isMobile),
            ],
          ),
        ],
      ),
    );
  }

  /// Build individual icon reference item
  Widget _buildIconReferenceItem(IconData icon, String label, bool isMobile) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: isMobile ? 14 : 16,
          color: AppTheme.textPrimary,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            fontSize: isMobile ? 11 : 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewStat(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    String? subtitle,
    double? cardWidth,
  }) {
    final double baseWidth = cardWidth ?? 240;
    final double resolvedWidth = baseWidth * 0.85;
    final bool isCompact = resolvedWidth < 220;
    final Color accentColor = _resolveOverviewAccentColor(label);
    final TextStyle valueStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: isCompact ? 18 : 22,
          color: accentColor,
          letterSpacing: 0.2,
        ) ??
        AppTheme.headingMedium.copyWith(
          fontSize: isCompact ? 18 : 22,
          fontWeight: FontWeight.w700,
          color: accentColor,
        );
    final TextStyle labelStyle = AppTheme.bodyMedium.copyWith(
      color: AppTheme.textSecondary,
      fontSize: isCompact ? 11 : 12,
      fontWeight: FontWeight.w500,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, valueAnimation, child) {
        return Transform.scale(
          scale: 0.96 + (0.04 * valueAnimation),
          child: Opacity(
            opacity: valueAnimation,
            child: SizedBox(
              width: resolvedWidth,
              child: Container(
                padding: EdgeInsets.all(isCompact ? 12 : 14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: AppTheme.textPrimary.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isCompact ? 10 : 12),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        color: accentColor,
                        size: isCompact ? 22 : 24,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: labelStyle,
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            value,
                            style: valueStyle,
                            textAlign: TextAlign.right,
                          ),
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                subtitle,
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _resolveOverviewAccentColor(String label) {
    switch (label) {
      case 'Distinct Roles':
        return AppTheme.secondaryColor;
      case 'Total Users':
        return AppTheme.primaryColor;
      case 'Active Ratio':
        return AppTheme.accentBlue;
      default:
        return AppTheme.primaryColor;
    }
  }

  Widget _buildRoleCard(BuildContext context, _RoleSummary summary) {
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, animationValue, child) {
        return Transform.translate(
          offset: Offset(0, (1 - animationValue) * 12),
          child: Opacity(
            opacity: animationValue,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.borderColor.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Icon, Name, Total users (top right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.badge_outlined,
                    color: AppTheme.primaryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    summary.role,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppTheme.borderColor.withValues(alpha: 0.6),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total users',
                          textAlign: TextAlign.center,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary.withValues(alpha: 0.9),
                            letterSpacing: 0.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary.totalUsers.toString(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Row 2: Status pills only
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildMetricPill(
                  label: 'Active',
                  value: summary.activeUsers.toString(),
                  color: AppTheme.secondaryColor,
                ),
                _buildMetricPill(
                  label: 'Inactive',
                  value: summary.inactiveUsers.toString(),
                  color: AppTheme.warningColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Row 3: Assigned users tag and Edit Role button
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showAssignedUsersDialog(context, summary),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Assigned users',
                          style: AppTheme.labelMedium.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: () => _showEditRoleDialog(summary),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label · $value',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(_RoleSummary summary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        summary.role,
        style: AppTheme.labelMedium.copyWith(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _showAssignedUsersDialog(
    BuildContext context,
    _RoleSummary summary,
  ) async {
    final users = summary.assignedUsers;
    final isMobile = Responsive.isMobile(context);

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final viewport = MediaQuery.of(dialogContext).size;

        return Dialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 48,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? 380 : 520,
              maxHeight: viewport.height * 0.7,
              minHeight: users.isEmpty ? 220 : 280,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 8, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${summary.role} users',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Assigned people currently in this role',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: users.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'No users are assigned to this role yet.',
                              textAlign: TextAlign.center,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : Scrollbar(
                          thumbVisibility: true,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final userId = user['id'] ?? user['_id'] ?? '';
                              final name = _resolveUserName(user);
                              final email = _resolveOptionalString(user['email']);
                              final phoneNumber =
                                  _resolveOptionalString(user['phoneNumber']);
                              final role = _resolveOptionalString(user['role']) ?? summary.role;
                              final status = _resolveUserStatus(user);
                              final isNew = _isNewUser(user);

                              return _AssignedUserTile(
                                userId: userId.toString(),
                                name: name,
                                email: email,
                                phoneNumber: phoneNumber,
                                role: role,
                                statusLabel: status,
                                isNewUser: isNew,
                                onPermissionsUpdated: _debouncedRefresh,
                              );
                            },
                            separatorBuilder: (_, __) => Divider(
                              height: 24,
                              color: AppTheme.borderColor.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _resolveUserName(Map<String, dynamic> user) {
    final name = _resolveOptionalString(user['name']);
    if (name != null) {
      return name;
    }

    final fullName = _resolveOptionalString(user['fullName']);
    if (fullName != null) {
      return fullName;
    }

    final email = _resolveOptionalString(user['email']);
    if (email != null) {
      return email;
    }

    final role = _resolveOptionalString(user['role']);
    if (role != null) {
      return role;
    }

    return 'Unknown';
  }

  String? _resolveOptionalString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  String _resolveUserStatus(Map<String, dynamic> user) {
    final status = _resolveOptionalString(user['status']);
    if (status != null) {
      return _capitalize(status);
    }

    final dynamic isVerified = user['isVerified'];
    if (isVerified is bool) {
      return isVerified ? 'Active' : 'Inactive';
    }

    return 'Unknown';
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    final lower = value.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  /// Check if user is newly created (within last 5 minutes)
  bool _isNewUser(Map<String, dynamic> user) {
    final createdAt = user['createdAt'] ?? user['created_at'];
    if (createdAt == null) return false;

    try {
      final createdAtDate = createdAt is String
          ? DateTime.parse(createdAt)
          : (createdAt is DateTime ? createdAt : null);
      if (createdAtDate == null) return false;

      final now = DateTime.now();
      final difference = now.difference(createdAtDate);

      // Consider user "new" if created within last 5 minutes
      return difference.inMinutes < 5;
    } catch (e) {
      return false;
    }
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorColor, size: 42),
            const SizedBox(height: 16),
            Text(
              'We couldn\'t load roles right now.',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadRoles,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_off_outlined, color: AppTheme.textSecondary, size: 42),
            const SizedBox(height: 16),
            Text(
              'No roles available yet',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add users or sync with the backend to populate roles.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _formatActivationRatio() {
    final totalActive = _roleSummaries.fold<int>(0, (sum, role) => sum + role.activeUsers);
    if (_totalUsers == 0) {
      return '0%';
    }
    final ratio = (totalActive / _totalUsers) * 100;
    return '${ratio.toStringAsFixed(1)}%';
  }

  String _normalizeRole(dynamic rawRole) {
    final role = rawRole?.toString().trim() ?? '';
    if (role.isEmpty) {
      return 'Unknown';
    }
    return role;
  }
}

class _AssignedUserTile extends StatelessWidget {
  const _AssignedUserTile({
    required this.userId,
    required this.name,
    required this.role,
    required this.statusLabel,
    this.email,
    this.phoneNumber,
    this.isNewUser = false,
    this.onPermissionsUpdated,
  });

  final String userId;
  final String name;
  final String role;
  final String statusLabel;
  final String? email;
  final String? phoneNumber;
  final bool isNewUser;
  final VoidCallback? onPermissionsUpdated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmedName = name.trim();
    final initial = trimmedName.isNotEmpty
        ? trimmedName[0].toUpperCase()
        : '?';
    final normalizedStatus = statusLabel.toLowerCase();
    final bool isActive =
        normalizedStatus.contains('active') || normalizedStatus.contains('verify');
    final Color chipColor = isActive ? AppTheme.secondaryColor : AppTheme.warningColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
          child: Text(
            initial,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (isNewUser) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'NEW',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (email != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    email!,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              if (phoneNumber != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    phoneNumber!,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusLabel,
                style: AppTheme.labelMedium.copyWith(
                  color: chipColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

}

class _RoleSummary {
  const _RoleSummary({
    required this.role,
    required this.totalUsers,
    required this.activeUsers,
    required this.inactiveUsers,
    required this.assignedUsers,
  });

  final String role;
  final int totalUsers;
  final int activeUsers;
  final int inactiveUsers;
  final List<Map<String, dynamic>> assignedUsers;

  double get activeRatio => totalUsers == 0 ? 0 : activeUsers / totalUsers;

  double get inactiveRatio => totalUsers == 0 ? 0 : inactiveUsers / totalUsers;
}

class _RoleAccumulator {
  int total = 0;
  int active = 0;
  int inactive = 0;
  final List<Map<String, dynamic>> users = [];
}

