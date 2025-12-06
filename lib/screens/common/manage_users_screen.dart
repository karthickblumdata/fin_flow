import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../services/user_service.dart';
import '../../services/wallet_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/add_user_dialog.dart';
import '../../widgets/edit_user_dialog.dart';
import '../../utils/permission_action_checker.dart';
import '../../utils/profile_image_helper.dart';

class ManageUsersScreen extends StatelessWidget {
  final Function(String roleName)? onNavigateToRoles;
  
  const ManageUsersScreen({super.key, this.onNavigateToRoles});

  @override
  Widget build(BuildContext context) {
    return _ManageUsersScreenContent(onNavigateToRoles: onNavigateToRoles);
  }
}

class _ManageUsersScreenContent extends StatefulWidget {
  final Function(String roleName)? onNavigateToRoles;
  
  const _ManageUsersScreenContent({this.onNavigateToRoles});

  @override
  State<_ManageUsersScreenContent> createState() => _ManageUsersScreenContentState();
}

class _ManageUsersScreenContentState extends State<_ManageUsersScreenContent> {
  String _selectedFilter = 'All';
  String _selectedPlanStatus = 'Active';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // Role filters: 'All' + dynamic roles loaded from backend (RoleService.getAllRoles)
  List<String> _filters = ['All'];
  final List<String> _planStatusFilters = ['All', 'Active', 'Inactive'];
  static const int _maxDesktopCardsPerRow = 4;
  static const double _desktopCardWidth = 280;
  static const double _mobileCardWidth = 320;
  static const double _desktopCardHeightEstimate = 150;
  static const double _mobileCardHeightEstimate = 200;
  static const double _gridSpacing = 20;
  static const String _defaultContactNumber = '000-000-0000';

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  
  // Permission states
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canView = false;
  bool _isViewOnly = false;
  
  // Auto-refresh configuration
  Timer? _autoRefreshTimer;
  static const Duration _autoRefreshInterval = Duration(seconds: 30); // Refresh every 30 seconds
  static const Duration _debounceRefreshDelay = Duration(seconds: 2); // Debounce to prevent rapid refreshes
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    _refreshPermissionsAndLoadData();
    _loadRoleFilters();
    
    // Initialize socket for real-time updates
    _initializeSocketListeners();
    
    // Start auto-refresh timer
    _startAutoRefresh();
  }
  
  /// Auto-refresh method with debouncing to prevent excessive API calls
  /// This method ensures user data is refreshed when changes occur
  void _autoRefreshUsers() {
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
    
    // Refresh users data silently
    _refreshPermissionsAndLoadData();
  }

  /// Start the auto-refresh timer
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _autoRefreshUsers();
    });
  }

  /// Stop the auto-refresh timer
  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  /// Initialize socket listeners for real-time user updates
  void _initializeSocketListeners() {
    try {
      // Initialize socket service
      SocketService.initialize().then((_) {
        if (!mounted) return;
        
        // Listen to user created events
        SocketService.onUserCreated((data) {
          if (mounted) {
            _autoRefreshUsers();
          }
        });
        
        // Listen to dashboard updates (may include user-related changes)
        SocketService.onDashboardUpdate((data) {
          if (mounted) {
            _autoRefreshUsers();
          }
        });
        
        // Listen to amount updates (user creation emits this)
        SocketService.onAmountUpdate((data) {
          if (mounted) {
            // Check if this is a user_created event
            if (data is Map<String, dynamic> && data['type'] == 'user_created') {
              _autoRefreshUsers();
            }
          }
        });
        
        final socket = SocketService.socket;
        if (socket != null) {
          // Listen to wallet updates (user wallets may change)
          SocketService.onSelfWalletUpdate((data) {
            if (mounted) {
              // Refresh to update wallet balances in user cards
              _autoRefreshUsers();
            }
          });
        }
      });
    } catch (e) {
      print('❌ [USER MANAGEMENT] Error initializing socket listeners: $e');
    }
  }

  /// Clean up socket listeners
  void _cleanupSocketListeners() {
    try {
      // Socket listeners are automatically cleaned up when socket disconnects
      // No explicit cleanup needed as SocketService manages its own lifecycle
    } catch (e) {
      print('❌ [USER MANAGEMENT] Error cleaning up socket listeners: $e');
    }
  }

  Future<void> _refreshPermissionsAndLoadData() async {
    // Refresh permissions from backend to ensure they're up-to-date
    try {
      await AuthService.refreshPermissions();
    } catch (e) {
      print('⚠️  Error refreshing permissions: $e');
      // Continue even if refresh fails - use cached permissions
    }
    
    // Load permissions and then load data
    await _loadPermissions();
    await _loadUsers();
  }

  /// Load available roles from backend and build role filter list.
  /// This ensures the dropdown always reflects the actual roles defined in the system.
  Future<void> _loadRoleFilters() async {
    try {
      final result = await RoleService.getAllRoles();
      if (!mounted) return;

      if (result['success'] == true) {
        final roles = result['roles'] as List<dynamic>? ?? [];
        final Set<String> roleNames = <String>{};

        for (final role in roles) {
          if (role is Map<String, dynamic>) {
            final backendName = role['roleName']?.toString().trim() ?? '';
            if (backendName.isNotEmpty) {
              roleNames.add(backendName);
            }
          }
        }

        final List<String> sortedRoles = roleNames.toList()..sort();

        setState(() {
          _filters = ['All', ...sortedRoles];
          // Keep current selection if still valid, otherwise reset to 'All'
          if (!_filters.contains(_selectedFilter)) {
            _selectedFilter = 'All';
          }
        });
      }
    } catch (e) {
      // If role load fails, keep existing filters (at minimum: ['All'])
      // Do not show error to user; this is non-critical.
      // print for debug only
      // ignore: avoid_print
      print('⚠️  Failed to load role filters: $e');
    }
  }
  
  Future<void> _loadPermissions() async {
    final canCreate = await PermissionActionChecker.canCreate('all_users.user_management');
    final canEdit = await PermissionActionChecker.canEdit('all_users.user_management');
    final canDelete = await PermissionActionChecker.canDelete('all_users.user_management');
    final canView = await PermissionActionChecker.canView('all_users.user_management');
    final isViewOnly = await PermissionActionChecker.canOnlyView('all_users.user_management');
    
    if (mounted) {
      setState(() {
        _canCreate = canCreate;
        _canEdit = canEdit;
        _canDelete = canDelete;
        _canView = canView;
        _isViewOnly = isViewOnly;
      });
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _cleanupSocketListeners();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    
    // Load permissions first if not loaded
    if (!_canCreate && !_canEdit && !_canDelete && !_canView) {
      await _loadPermissions();
    }
    
    // Check if user has any permission (create, edit, delete, or view)
    // Load users if user has ANY permission
    final hasAnyPermission = _canCreate || _canEdit || _canDelete || _canView;
    
    // Safe debug logging
    try {
      debugPrint('👥 User Management: Loading users');
      debugPrint('   Permissions - Create: $_canCreate, Edit: $_canEdit, Delete: $_canDelete, View: $_canView');
      debugPrint('   Has any permission: $hasAnyPermission');
    } catch (e) {
      // Ignore debug errors
    }
    
    if (!hasAnyPermission && mounted) {
      debugPrint('⚠️  User Management: No permissions - not loading users');
      setState(() {
        _isLoading = false;
        _users = [];
      });
      return;
    }
    
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await UserService.getUsers();
      if (!mounted) return;
      
      Map<String, Map<String, dynamic>> walletLookup = {};
      String? walletError;

      try {
        final walletResult = await WalletService.getAllWallets();
        if (!mounted) return;
        
        if (walletResult['success'] == true) {
          final wallets = walletResult['wallets'] as List<dynamic>? ?? [];
          for (final wallet in wallets) {
            final user = wallet['userId'];
            final userId = user is Map<String, dynamic>
                ? (user['_id'] ?? user['id'])?.toString()
                : wallet['userId']?.toString();
            if (userId == null || userId.isEmpty) continue;

            walletLookup[userId] = {
              'balance': _parseAmount(wallet['totalBalance']),
              'cashIn': _parseAmount(
                wallet['totalCashIn'] ?? wallet['cashIn'] ?? wallet['totalDeposits'],
              ),
              'cashOut': _parseAmount(
                wallet['totalCashOut'] ?? wallet['cashOut'] ?? wallet['totalWithdrawals'],
              ),
            };
          }
        } else {
          walletError = (walletResult['message'] ?? 'Failed to load wallet data').toString();
        }
      } catch (e) {
        walletError = e.toString().replaceFirst('Exception: ', '');
      }

      if (!mounted) return;

      if (result['success'] == true) {
        final users = result['users'] as List<dynamic>? ?? [];
        
        // Safe debug logging (avoid Flutter web errors)
        try {
          debugPrint('👥 User Management: Loaded ${users.length} users from API');
          debugPrint('   API Response success: ${result['success']}');
          debugPrint('   Users count: ${users.length}');
        } catch (e) {
          // Ignore debug print errors on web
        }
        
        // Log admin@examples.com if present (safe for web)
        try {
          dynamic adminUser;
          try {
            adminUser = users.firstWhere(
              (u) {
                final email = (u is Map ? u['email'] : null)?.toString().toLowerCase() ?? '';
                return email == 'admin@examples.com';
              },
            );
          } catch (e) {
            adminUser = null;
          }
          
          if (adminUser != null && adminUser is Map) {
            final name = adminUser['name']?.toString() ?? 'Unknown';
            final role = adminUser['role']?.toString() ?? 'Unknown';
            debugPrint('✅ Found admin@examples.com in user management: $name, role: $role');
          } else {
            debugPrint('⚠️  admin@examples.com user not found in user management API response');
          }
        } catch (e) {
          // Ignore debug errors
        }
        
        if (mounted) {
          setState(() {
            _users = users.map((u) {
              final rawUser = _normalizeUserMap(u);
              final dynamic rawId = rawUser['_id'] ?? rawUser['id'];
              final idKey = rawId?.toString() ?? '';
              final contactNumber = _extractContactNumber(rawUser);

              final userMap = <String, dynamic>{
                'id': rawId,
                'name': rawUser['name'] ?? 'Unknown',
                'email': rawUser['email'] ?? '',
                'role': rawUser['role'] ?? 'Staff',
                'status': rawUser['isVerified'] == true ? 'Active' : 'Inactive',
                'isVerified': rawUser['isVerified'] ?? false,
                // Include isNonWalletUser field (important for EditUserDialog)
                if (rawUser.containsKey('isNonWalletUser')) 'isNonWalletUser': rawUser['isNonWalletUser'],
                if (contactNumber.isNotEmpty) 'contactNumber': contactNumber,
                if (rawUser.containsKey('phone')) 'phone': rawUser['phone'],
                if (rawUser.containsKey('phoneNumber')) 'phoneNumber': rawUser['phoneNumber'],
                if (rawUser.containsKey('mobile')) 'mobile': rawUser['mobile'],
                if (rawUser.containsKey('mobileNumber')) 'mobileNumber': rawUser['mobileNumber'],
                // Include address fields for EditUserDialog
                if (rawUser.containsKey('address')) 'address': rawUser['address'],
                if (rawUser.containsKey('addressLine2')) 'addressLine2': rawUser['addressLine2'],
                if (rawUser.containsKey('state')) 'state': rawUser['state'],
                if (rawUser.containsKey('pinCode')) 'pinCode': rawUser['pinCode'],
                if (rawUser.containsKey('countryCode')) 'countryCode': rawUser['countryCode'],
                if (rawUser.containsKey('dateOfBirth')) 'dateOfBirth': rawUser['dateOfBirth'],
                // Include profileImage and other profile-related fields
                if (rawUser.containsKey('profileImage')) 'profileImage': rawUser['profileImage'],
                if (rawUser.containsKey('profileUrl')) 'profileUrl': rawUser['profileUrl'],
                if (rawUser.containsKey('avatar')) 'avatar': rawUser['avatar'],
                if (rawUser.containsKey('avatarUrl')) 'avatarUrl': rawUser['avatarUrl'],
                if (rawUser.containsKey('photo')) 'photo': rawUser['photo'],
                if (rawUser.containsKey('profilePic')) 'profilePic': rawUser['profilePic'],
                if (rawUser.containsKey('image')) 'image': rawUser['image'],
                if (rawUser.containsKey('profilePhoto')) 'profilePhoto': rawUser['profilePhoto'],
                if (rawUser.containsKey('profileImageUrl')) 'profileImageUrl': rawUser['profileImageUrl'],
                'wallet': walletLookup[idKey] ??
                    {
                      'balance': 0.0,
                      'cashIn': 0.0,
                      'cashOut': 0.0,
                    },
              };
              
              // Debug: Check if profileImage was included (safe for web)
              try {
                if (rawUser.containsKey('profileImage') && rawUser['profileImage'] != null) {
                  final userName = userMap['name']?.toString() ?? 'Unknown';
                  debugPrint('✅ [USER MAP] Included profileImage for $userName');
                }
              } catch (e) {
                // Ignore debug errors
              }
              
              return userMap;
            }).toList();
            _isLoading = false;
          });
          
          // Safe debug logging
          try {
            debugPrint('✅ User Management: Set ${_users.length} users in state');
            debugPrint('   Filtered users count: ${_filteredUsers.length}');
            debugPrint('   Selected filter: $_selectedFilter');
            debugPrint('   Selected status: $_selectedPlanStatus');
            debugPrint('   Search query: "$_searchQuery"');
          } catch (e) {
            // Ignore debug errors
          }
          
          // Force rebuild to ensure UI updates
          if (mounted) {
            setState(() {
              // Trigger rebuild to show users
            });
          }

          if (walletError != null && walletError!.isNotEmpty && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(walletError!),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      } else {
        final errorMessage = result['message'] ?? 'Failed to load users';
        print('❌ User Management: API returned error: $errorMessage');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _users = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ User Management: Exception loading users: $e');
      print('   Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _users = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    Iterable<Map<String, dynamic>> filtered = _users;
    
    final initialCount = filtered.length;
    if (initialCount > 0) {
      print('🔍 User Management: Filtering users - Initial count: $initialCount');
    }

    if (_selectedFilter != 'All') {
      final beforeCount = filtered.length;
      filtered = filtered.where(
        (user) => _roleMatchesFilter(user['role']?.toString()),
      );
      if (beforeCount > 0) {
        print('   After role filter ($_selectedFilter): ${filtered.length} (was $beforeCount)');
      }
    }

    if (_selectedPlanStatus != 'All') {
      final beforeCount = filtered.length;
      filtered = filtered.where(_matchesSelectedStatus);
      if (beforeCount > 0) {
        print('   After status filter ($_selectedPlanStatus): ${filtered.length} (was $beforeCount)');
      }
    }

    if (_searchQuery.trim().isNotEmpty) {
      final beforeCount = filtered.length;
      filtered = filtered.where(_matchesSearchQuery);
      if (beforeCount > 0) {
        print('   After search filter ("$_searchQuery"): ${filtered.length} (was $beforeCount)');
      }
    }

    final finalCount = filtered.length;
    if (initialCount > 0 && finalCount != initialCount) {
      print('   Final filtered count: $finalCount (from $initialCount)');
    }
    
    return filtered.toList();
  }

  bool _roleMatchesFilter(String? role) {
    if (_selectedFilter == 'All') {
      return true;
    }

    final normalizedRole = _normalizeFilterValue(role);
    final normalizedFilter = _normalizeFilterValue(_selectedFilter);

    if (normalizedRole.isEmpty) {
      return false;
    }

    return normalizedRole == normalizedFilter;
  }

  bool _matchesSelectedStatus(Map<String, dynamic> user) {
    final normalizedFilter = _normalizeFilterValue(_selectedPlanStatus);
    if (normalizedFilter.isEmpty || normalizedFilter == 'all') {
      return true;
    }

    final directStatus = _normalizeFilterValue(user['status']?.toString());
    if (directStatus.isNotEmpty) {
      return _statusMatchesFilterValue(directStatus, normalizedFilter);
    }

    final bool? isVerified = user['isVerified'] as bool?;
    if (isVerified != null) {
      final normalized = isVerified ? 'active' : 'inactive';
      return _statusMatchesFilterValue(normalized, normalizedFilter);
    }

    final resolvedStatus = _resolvePlanStatus(user);
    if (resolvedStatus != null) {
      final normalizedResolved = _normalizeFilterValue(resolvedStatus);
      if (normalizedResolved.isNotEmpty) {
        return _statusMatchesFilterValue(normalizedResolved, normalizedFilter);
      }
    }

    return false;
  }

  bool _statusMatchesFilterValue(String normalizedStatus, String normalizedFilter) {
    if (normalizedStatus.isEmpty || normalizedFilter.isEmpty) {
      return false;
    }

    if (normalizedStatus == normalizedFilter) {
      return true;
    }

    if (normalizedFilter == 'active') {
      return normalizedStatus == 'true' ||
          normalizedStatus.contains('active') ||
          normalizedStatus.contains('verified') ||
          normalizedStatus.contains('enable') ||
          normalizedStatus.contains('approve');
    }

    if (normalizedFilter == 'inactive') {
      return normalizedStatus == 'false' ||
          normalizedStatus.contains('inactive') ||
          normalizedStatus.contains('pending') ||
          normalizedStatus.contains('disable') ||
          normalizedStatus.contains('suspend');
    }

    return false;
  }

  String _normalizeFilterValue(String? value) {
    return value == null
        ? ''
        : value
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  bool _matchesSearchQuery(Map<String, dynamic> user) {
    final normalizedQuery = _normalizeFilterValue(_searchQuery);
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final valuesToSearch = <String?>[
      user['name']?.toString(),
      user['email']?.toString(),
      _extractContactNumber(user),
      user['phone']?.toString(),
      user['mobile']?.toString(),
      user['mobileNumber']?.toString(),
    ];

    for (final value in valuesToSearch) {
      final normalizedCandidate = _normalizeFilterValue(value);
      if (normalizedCandidate.contains(normalizedQuery)) {
        return true;
      }
    }

    return false;
  }

  void _clearSearch() {
    if (_searchQuery.isEmpty || !mounted) return;
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _clearAllFilters() {
    final hasChanges = _selectedFilter != 'All' ||
        _selectedPlanStatus != 'Active' ||
        _searchQuery.trim().isNotEmpty;

    if (!hasChanges || !mounted) {
      return;
    }

    setState(() {
      _selectedFilter = 'All';
      _selectedPlanStatus = 'Active';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.3)),
              ),
            ),
            child: isMobile
                ? // Mobile: Stack vertically
                Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Filter icon and title row
                      Row(
                        children: [
                          Icon(
                            Icons.filter_list,
                            size: 20,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Filters',
                            style: AppTheme.labelMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Role filter row
                      Row(
                        children: [
                          Text(
                            'Role:',
                            style: AppTheme.labelMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.borderColor.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedFilter,
                                underline: const SizedBox(),
                                isDense: true,
                                isExpanded: true,
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                items: _filters.map((String filter) {
                                  return DropdownMenuItem<String>(
                                    value: filter,
                                    child: Text(filter),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null && mounted) {
                                    setState(() {
                                      _selectedFilter = newValue;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Status filter row
                      Row(
                        children: [
                          Text(
                            'Status:',
                            style: AppTheme.labelMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.borderColor.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedPlanStatus,
                                underline: const SizedBox(),
                                isDense: true,
                                isExpanded: true,
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                items: _planStatusFilters.map((String filter) {
                                  return DropdownMenuItem<String>(
                                    value: filter,
                                    child: Text(filter),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null && mounted) {
                                    setState(() {
                                      _selectedPlanStatus = newValue;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Search field - full width
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.borderColor.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) {
                                  if (mounted) {
                                    setState(() {
                                      _searchQuery = value;
                                    });
                                  }
                                },
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: 'Search name, email, phone',
                                  hintStyle: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            if (_searchQuery.trim().isNotEmpty)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                splashRadius: 18,
                                icon: Icon(
                                  Icons.clear_rounded,
                                  size: 18,
                                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                                ),
                                onPressed: _clearSearch,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Clear All button - full width on mobile
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _clearAllFilters,
                          icon: Icon(Icons.refresh_outlined, size: 18),
                          label: Text(
                            'Clear All',
                            style: AppTheme.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      // Add User button - full width on mobile
                      if (_canCreate) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _onAddUser,
                            icon: Icon(Icons.person_add_outlined, size: 18),
                            label: Text(
                              'Add User',
                              style: AppTheme.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.6)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : // Desktop: Keep horizontal layout
                Row(
                    children: [
                      Icon(
                        Icons.filter_list,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Filter by Role:',
                        style: AppTheme.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.zero,
                          border: Border.all(
                            color: AppTheme.borderColor.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedFilter,
                          underline: const SizedBox(),
                          isDense: true,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          items: _filters.map((String filter) {
                            return DropdownMenuItem<String>(
                              value: filter,
                              child: Text(filter),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null && mounted) {
                              setState(() {
                                _selectedFilter = newValue;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Filter by Status:',
                        style: AppTheme.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.zero,
                          border: Border.all(
                            color: AppTheme.borderColor.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedPlanStatus,
                          underline: const SizedBox(),
                          isDense: true,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          items: _planStatusFilters.map((String filter) {
                            return DropdownMenuItem<String>(
                              value: filter,
                              child: Text(filter),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null && mounted) {
                              setState(() {
                                _selectedPlanStatus = newValue;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.borderColor.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (value) {
                                    if (mounted) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                    }
                                  },
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: 'Search name, email, phone',
                                    hintStyle: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.textSecondary.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ),
                              if (_searchQuery.trim().isNotEmpty)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  splashRadius: 18,
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                                  ),
                                  onPressed: _clearSearch,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _clearAllFilters,
                        icon: Icon(Icons.refresh_outlined, size: 20),
                        label: Text(
                          'Clear All',
                          style: AppTheme.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const Spacer(),
                // View Only indicator
                if (_isViewOnly)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.warningColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: isMobile ? 16 : 18,
                          color: AppTheme.warningColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'View Only',
                          style: AppTheme.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 12 : 13,
                            color: AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isViewOnly) const SizedBox(width: 12),
                // Add User button - only show if user has create permission
                if (_canCreate)
                  OutlinedButton.icon(
                    onPressed: _onAddUser,
                    icon: Icon(Icons.person_add_outlined, size: isMobile ? 18 : 20),
                    label: Text(
                      'Add User',
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.6)),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: isMobile ? 8 : 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                  reverseCurve: Curves.easeIn,
                );
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(-0.04, 0),
                  end: Offset.zero,
                ).animate(curved);
                return ClipRect(
                  child: FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    ),
                  ),
                );
              },
              child: _isLoading
                  ? const Center(
                      key: ValueKey('loading'),
                      child: CircularProgressIndicator(),
                    )
                  : _filteredUsers.isEmpty
                      ? Center(
                          key: const ValueKey('empty'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: AppTheme.textSecondary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _users.isEmpty
                                    ? 'No users available'
                                    : _filteredUsers.isEmpty
                                        ? 'No users match your filters'
                                        : 'No users found',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              if (_users.isNotEmpty && _filteredUsers.isEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _clearAllFilters,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Clear filters'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          key: ValueKey(
                            'grid-${_filteredUsers.length}-${_selectedFilter}-${_selectedPlanStatus}',
                          ),
                          builder: (context, constraints) {
                            final gridConfig = _calculateGridConfiguration(
                              maxWidth: constraints.maxWidth,
                              isMobile: isMobile,
                            );
                            return GridView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 16 : 24,
                                vertical: isMobile ? 12 : 20,
                              ),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridConfig.crossAxisCount,
                                crossAxisSpacing: _gridSpacing,
                                mainAxisSpacing: _gridSpacing,
                                childAspectRatio: gridConfig.childAspectRatio,
                              ),
                              itemCount: _filteredUsers.length,
                              itemBuilder: (context, index) => _buildUserCard(
                                context,
                                _filteredUsers[index],
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, Map<String, dynamic> user) {
    final isMobileView = Responsive.isMobile(context);
    final isActive = user['status'] == 'Active';
    final roleColor = _getRoleColor(user['role']);
    final contactNumber = _extractContactNumber(user);
    final displayContactNumber =
        contactNumber.isEmpty ? _defaultContactNumber : contactNumber;
    final planDetails = _extractPlanDetails(user);
    final roleText = user['role']?.toString() ?? '';
    final userEmail = user['email']?.toString() ?? '';
    final isProtected = userEmail == 'admin@examples.com'; // Check if user is protected

    final bannerMessage = isActive ? 'ACTIVE' : 'INACTIVE';
    final bannerColor = isActive ? AppTheme.secondaryColor : AppTheme.errorColor;
    final EdgeInsets cardPadding = isMobileView
        ? const EdgeInsets.fromLTRB(18, 10, 18, 10)
        : const EdgeInsets.fromLTRB(18, 8, 18, 8);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (isProtected || !_canEdit) ? null : () => _onEditUser(user), // Disable tap for protected user or if no edit permission
            borderRadius: BorderRadius.circular(20),
              child: Banner(
              message: bannerMessage,
              location: BannerLocation.topEnd,
              color: bannerColor,
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
              child: Container(
                  padding: cardPadding,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.borderColor.withValues(alpha: 0.35),
                    width: 0.9,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            _buildProfilePreview(
                              name: user['name']?.toString() ?? '',
                              imageUrl: _extractProfileImage(user),
                              roleColor: roleColor,
                            ),
                            if (isProtected)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.lock,
                                    size: isMobileView ? 12 : 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          user['name']?.toString() ?? '',
                                          style: AppTheme.headingSmall.copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        _buildContactLine(
                                          icon: null,
                                          label: user['email']?.toString() ?? '',
                                        ),
                                        const SizedBox(height: 4),
                                        _buildContactLine(
                                          icon: Icons.phone_outlined,
                                          label: displayContactNumber,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isMobileView ? 6 : 2),
                              if (roleText.isNotEmpty)
                                Text(
                                  roleText,
                                  style: AppTheme.bodySmall.copyWith(
                                    color: roleColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              if (planDetails != null)
                                Padding(
                                  padding: EdgeInsets.only(top: isMobileView ? 12 : 8),
                                  child: _buildPlanSection(planDetails),
                                ),
                              SizedBox(height: isMobileView ? 2 : 0),
                              Align(
                                alignment: Alignment.centerRight,
                                child: isProtected
                                    ? _buildProtectedBadge(isMobileView)
                                    : _canEdit
                                        ? _buildEditButton(
                                            onTap: () => _onEditUser(user),
                                            isMobileView: isMobileView,
                                          )
                                        : _isViewOnly
                                            ? _buildViewOnlyBadge(isMobileView)
                                            : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePreview({
    required String name,
    required String? imageUrl,
    required Color roleColor,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 104),
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: roleColor.withValues(alpha: 0.14),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('❌ [PROFILE IMAGE] Failed to load image: $imageUrl');
                      print('   Error: $error');
                      return _ProfileInitials(
                        name: name,
                        roleColor: roleColor,
                      );
                    },
                  )
                : _ProfileInitials(
                    name: name,
                    roleColor: roleColor,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactLine({
    IconData? icon,
    required String label,
  }) {
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 14,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildViewOnlyBadge(bool isMobileView) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobileView ? 10 : 12,
        vertical: isMobileView ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.warningColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_outlined,
            size: isMobileView ? 14 : 16,
            color: AppTheme.warningColor,
          ),
          const SizedBox(width: 4),
          Text(
            'View Only',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.warningColor,
              fontWeight: FontWeight.w600,
              fontSize: isMobileView ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectedBadge(bool isMobileView) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobileView ? 12 : 14,
        vertical: isMobileView ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock,
            size: isMobileView ? 14 : 16,
            color: Colors.amber.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            'Protected',
            style: AppTheme.bodySmall.copyWith(
              color: Colors.amber.shade700,
              fontWeight: FontWeight.w600,
              fontSize: isMobileView ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditButton({
    required VoidCallback onTap,
    required bool isMobileView,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: isMobileView ? 2 : 0),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          padding: EdgeInsets.all(isMobileView ? 8 : 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobileView ? 10 : 8),
          ),
          minimumSize: Size(isMobileView ? 36 : 34, isMobileView ? 36 : 34),
        ),
        child: const Icon(Icons.edit_outlined, size: 16),
      ),
    );
  }

  Widget _buildPlanSection(_PlanDetails planDetails) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planDetails.name,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (planDetails.status != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    planDetails.status!,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (planDetails.actions.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: planDetails.actions.map((action) {
                return OutlinedButton(
                  onPressed: action.onTap,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(action.label),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  String _extractContactNumber(Map<String, dynamic> user) {
    final possibleKeys = [
      'phone',
      'phoneNumber',
      'mobile',
      'mobileNumber',
      'contact',
      'contactNumber',
      'telephone',
    ];

    for (final key in possibleKeys) {
      final value = user[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  Map<String, dynamic> _normalizeUserMap(dynamic user) {
    if (user is Map<String, dynamic>) {
      return Map<String, dynamic>.from(user);
    }
    if (user is Map) {
      final normalized = <String, dynamic>{};
      user.forEach((key, value) {
        final normalizedKey = key is String ? key : key?.toString() ?? '';
        if (normalizedKey.isNotEmpty) {
          normalized[normalizedKey] = value;
        }
      });
      return normalized;
    }
    return <String, dynamic>{};
  }

  String? _extractProfileImage(Map<String, dynamic> user) {
    final imageUrl = ProfileImageHelper.extractImageUrl(user);
    // Debug logging
    if (imageUrl != null) {
      print('📸 [PROFILE IMAGE] Found profileImage for ${user['name']}: $imageUrl');
    } else {
      print('⚠️ [PROFILE IMAGE] No profileImage found for ${user['name']}. Available keys: ${user.keys.toList()}');
      // Check if profileImage exists but is null/empty
      if (user.containsKey('profileImage')) {
        print('   profileImage field exists but value is: ${user['profileImage']}');
      }
    }
    return imageUrl;
  }

  _PlanDetails? _extractPlanDetails(Map<String, dynamic> user) {
    dynamic rawPlan = user['plan'] ?? user['planDetails'] ?? user['planInfo'];
    rawPlan ??= user['subscription'] ?? user['subscriptionPlan'] ?? user['membership'];

    if (rawPlan == null) {
      final fallbackName = user['planName'] ?? user['subscriptionName'];
      if (fallbackName != null && fallbackName.toString().trim().isNotEmpty) {
        return _PlanDetails(
          name: fallbackName.toString(),
          status: user['planStatus']?.toString(),
          actions: const <_PlanAction>[],
        );
      }
      return null;
    }

    if (rawPlan is String) {
      if (rawPlan.trim().isEmpty) return null;
      return _PlanDetails(
        name: rawPlan,
        status: user['planStatus']?.toString(),
        actions: const <_PlanAction>[],
      );
    }

    if (rawPlan is Map<String, dynamic>) {
      final name = rawPlan['name'] ?? rawPlan['planName'] ?? rawPlan['title'];
      if (name == null || name.toString().trim().isEmpty) {
        return null;
      }

      final status = rawPlan['status'] ?? rawPlan['state'] ?? user['planStatus'];
      final actions = <_PlanAction>[];

      final actionList = rawPlan['actions'];
      if (actionList is List) {
        for (final action in actionList) {
          if (action is Map<String, dynamic>) {
            final label = action['label'] ?? action['name'];
            final callback = action['onTap'];
            if (label != null &&
                label.toString().trim().isNotEmpty &&
                callback is VoidCallback) {
              actions.add(
                _PlanAction(
                  label: label.toString(),
                  onTap: callback,
                ),
              );
            }
          }
        }
      }

      return _PlanDetails(
        name: name.toString(),
        status: status?.toString(),
        actions: actions,
      );
    }

    return null;
  }

  String? _resolvePlanStatus(Map<String, dynamic> user) {
    final directStatusKeys = [
      'planStatus',
      'subscriptionStatus',
      'membershipStatus',
    ];

    for (final key in directStatusKeys) {
      final value = user[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    final planSources = [
      user['plan'],
      user['planDetails'],
      user['planInfo'],
      user['subscription'],
      user['subscriptionPlan'],
      user['membership'],
    ];

    for (final plan in planSources) {
      if (plan is Map<String, dynamic>) {
        final planStatusKeys = ['status', 'state', 'planStatus'];
        for (final statusKey in planStatusKeys) {
          final value = plan[statusKey];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString();
          }
        }
      }
    }

    final planDetails = _extractPlanDetails(user);
    return planDetails?.status;
  }
  _GridConfiguration _calculateGridConfiguration({
    required double maxWidth,
    required bool isMobile,
  }) {
    final targetCardWidth = isMobile ? _mobileCardWidth : _desktopCardWidth;
    int crossAxisCount = (maxWidth / targetCardWidth).floor();
    if (crossAxisCount < 1) {
      crossAxisCount = 1;
    }
    if (!isMobile) {
      crossAxisCount = crossAxisCount.clamp(1, _maxDesktopCardsPerRow);
    }
    final effectiveSpacing = _gridSpacing * (crossAxisCount - 1);
    final availableWidth = maxWidth - effectiveSpacing;
    final cardWidth = availableWidth > 0 ? availableWidth / crossAxisCount : targetCardWidth;
    final estimatedHeight =
        isMobile ? _mobileCardHeightEstimate : _desktopCardHeightEstimate;
    final childAspectRatio = cardWidth / estimatedHeight;
    return _GridConfiguration(
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio > 0 ? childAspectRatio : 1,
    );
  }
  Color _getRoleColor(String role) {
    switch (role) {
      case 'Super Admin':
      case 'SuperAdmin':
        return AppTheme.primaryColor;
      case 'Admin':
        return AppTheme.warningColor;
      case 'Staff':
        return AppTheme.secondaryColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _onAddUser() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: AddUserDialog(),
        );
      },
    );

    if (!mounted) return;

    // Handle null result case
    if (result == null) {
      return;
    }

    if (result is Map<String, dynamic>) {
      final event = result['event'];
      if (event == 'created') {
        // Refresh user list to show newly created user
        if (mounted) {
          await _loadUsers();
        }
        if (!mounted) return;
        
        // Check if should navigate to Roles screen
        final shouldNavigateToRoles = result['navigateToRoles'] == true;
        final roleName = result['roleName']?.toString();
        
        // Navigate to Roles screen if callback is provided
        if (shouldNavigateToRoles && roleName != null && roleName.isNotEmpty) {
          // Call callback to navigate to Roles screen
          widget.onNavigateToRoles?.call(roleName);
        }
        
        final message = result['message']?.toString() ?? 'User created successfully';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppTheme.secondaryColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else if (event == 'sendInvite') {
        final email = result['email']?.toString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                email != null && email.isNotEmpty
                    ? 'Invite queued for $email'
                    : 'Invite request sent',
              ),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _onEditUser(Map<String, dynamic> user) async {
    // Check if user has edit permission
    if (!_canEdit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You do not have permission to edit users.'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Prevent editing protected user
    final userEmail = user['email']?.toString() ?? '';
    if (userEmail == 'admin@examples.com') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot edit admin@examples.com. This user is protected.'),
          backgroundColor: Colors.amber.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: EditUserDialog(
            user: Map<String, dynamic>.from(user),
          ),
        );
      },
    );

    if (!mounted) return;

    if (result is Map<String, dynamic>) {
      final event = result['event'];

      if (event == 'updated') {
        final updatedUser = result['user'];
        if (updatedUser is Map<String, dynamic> && mounted) {
          setState(() {
            final targetId = updatedUser['id'] ?? updatedUser['_id'];
            final index = _users.indexWhere(
              (element) =>
                  element['id'] == targetId ||
                  element['_id'] == targetId,
            );
            if (index != -1) {
              _users[index] = {
                ..._users[index],
                ...updatedUser,
              };
            }
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('User updated'),
                backgroundColor: AppTheme.secondaryColor,
              ),
            );
          }
        }
      } else if (event == 'deleted') {
        final userId = result['userId'];
        if (userId != null && mounted) {
          // Convert userId to string for comparison
          final userIdStr = userId.toString();
          
          // Remove user from local list immediately
          setState(() {
            _users.removeWhere(
              (element) {
                final elementId = element['id']?.toString() ?? element['_id']?.toString();
                return elementId == userIdStr;
              },
            );
          });
          
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('User deleted successfully'),
                backgroundColor: AppTheme.secondaryColor,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          
          // Reload users to ensure consistency with backend
          if (mounted) {
            _loadUsers();
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('User ID not found'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }
}

class _ProfileInitials extends StatelessWidget {
  const _ProfileInitials({
    required this.name,
    required this.roleColor,
  });

  final String name;
  final Color roleColor;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part.substring(0, 1).toUpperCase())
            .join();

    return Container(
      color: roleColor.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTheme.headingMedium.copyWith(
          color: roleColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlanDetails {
  const _PlanDetails({
    required this.name,
    this.status,
    required this.actions,
  });

  final String name;
  final String? status;
  final List<_PlanAction> actions;
}

class _PlanAction {
  const _PlanAction({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;
}

class _GridConfiguration {
  const _GridConfiguration({
    required this.crossAxisCount,
    required this.childAspectRatio,
  });

  final int crossAxisCount;
  final double childAspectRatio;
}




