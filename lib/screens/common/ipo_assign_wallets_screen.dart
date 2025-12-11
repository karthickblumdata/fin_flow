import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/wallet_service.dart';
import '../../services/collection_service.dart';
import '../../utils/responsive.dart';
import '../../utils/profile_image_helper.dart';

enum UserStatusFilter { active, inactive, all }

class IpoAssignWalletsScreen extends StatefulWidget {
  final bool embedInDashboard;
  
  const IpoAssignWalletsScreen({
    super.key,
    this.embedInDashboard = false,
  });

  @override
  State<IpoAssignWalletsScreen> createState() => _IpoAssignWalletsScreenState();
}

class _IpoAssignWalletsScreenState extends State<IpoAssignWalletsScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  UserStatusFilter _statusFilter = UserStatusFilter.active; // Default: Active
  
  // Card dimensions
  static const double _cardWidth = 280;
  static const double _cardHeight = 200;
  static const double _cardSpacing = 16;
  static const int _maxCardsPerRow = 4;
  static const String _defaultContactNumber = '000-000-0000';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterUsers);
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await UserService.getUsers();
      if (result['success'] == true && mounted) {
        final users = (result['users'] as List<dynamic>?)
            ?.map((u) => u as Map<String, dynamic>)
            .toList() ?? [];
        
        // Check wallet status and assignment counts for each user
        for (var user in users) {
          final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
          if (userId.isNotEmpty) {
            final hasWallet = await WalletService.hasWallet(userId: userId);
            user['hasWallet'] = hasWallet;
            
            // Get assignment counts
            final assignmentCounts = await _getAssignmentCounts(userId);
            user['assignedToCount'] = assignmentCounts['assignedTo'] ?? 0;
            user['assignedForCount'] = assignmentCounts['assignedFor'] ?? 0;
          } else {
            // Default to 0 if no userId
            user['assignedToCount'] = 0;
            user['assignedForCount'] = 0;
          }
        }
        
        setState(() {
          _users = users;
          _isLoading = false;
        });
        _filterUsers();
      } else {
        if (mounted) {
          setState(() {
            _users = [];
            _isLoading = false;
          });
          _filterUsers();
        }
      }
    } catch (e) {
      print('❌ [ASSIGN WALLETS] Error loading users: $e');
      if (mounted) {
        setState(() {
          _users = [];
          _isLoading = false;
        });
        _filterUsers();
      }
    }
  }

  Future<Map<String, int>> _getAssignmentCounts(String userId) async {
    try {
      // Get collections where user is assigned receiver (assigned to)
      final assignedToResult = await CollectionService.getCollections(
        assignedReceiver: userId,
      );
      final assignedToCount = (assignedToResult['collections'] as List<dynamic>?)?.length ?? 0;
      
      // Get collections where user is collector (assigned for)
      final assignedForResult = await CollectionService.getCollections(
        collectedBy: userId,
      );
      final assignedForCount = (assignedForResult['collections'] as List<dynamic>?)?.length ?? 0;
      
      return {
        'assignedTo': assignedToCount,
        'assignedFor': assignedForCount,
      };
    } catch (e) {
      print('❌ [ASSIGN WALLETS] Error fetching assignment counts for user $userId: $e');
      // Return default values on error
      return {
        'assignedTo': 0,
        'assignedFor': 0,
      };
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        // Search filter
        final name = (user['name'] ?? '').toLowerCase();
        final email = (user['email'] ?? '').toLowerCase();
        final role = (user['role'] ?? '').toLowerCase();
        
        final matchesSearch = query.isEmpty ||
            name.contains(query) ||
            email.contains(query) ||
            role.contains(query);

        // Status filter
        bool matchesStatus = true;
        final isVerified = user['isVerified'] == true;
        
        if (_statusFilter == UserStatusFilter.active) {
          matchesStatus = isVerified;
        } else if (_statusFilter == UserStatusFilter.inactive) {
          matchesStatus = !isVerified;
        }
        // 'all' - no status filter

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  bool _isUserActive(Map<String, dynamic> user) {
    return user['isVerified'] == true;
  }

  Future<void> _assignWallet(String userId, String userName) async {
    try {
      // Check if user already has a wallet
      final hasWallet = await WalletService.hasWallet(userId: userId);
      
      if (hasWallet) {
        // User already has wallet
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userName already has a wallet assigned'),
              backgroundColor: AppTheme.warningColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Create wallet by adding a minimal amount (0.01) - this triggers wallet creation
      // SuperAdmin can add amount to any user's wallet
      final result = await WalletService.addAmount(
        mode: 'Cash',
        amount: 0.01,
        notes: 'Wallet assignment - initial setup',
        userId: userId,
      );
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Wallet assigned successfully to $userName'),
              backgroundColor: AppTheme.secondaryColor,
              duration: const Duration(seconds: 3),
            ),
          );
          // Refresh users list
          _loadUsers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to assign wallet'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [ASSIGN WALLETS] Error assigning wallet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  List<Widget> _buildFilterChips(bool isMobile) {
    return UserStatusFilter.values.map((filter) {
      final isSelected = _statusFilter == filter;
      String label = 'All';
      if (filter == UserStatusFilter.active) {
        label = 'Active';
      } else if (filter == UserStatusFilter.inactive) {
        label = 'Inactive';
      }
      
      return ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isMobile ? 13 : 14,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
        selected: isSelected,
        selectedColor: AppTheme.primaryColor,
        backgroundColor: Colors.white,
        showCheckmark: false,
        side: BorderSide(
          color: isSelected
              ? AppTheme.primaryColor
              : AppTheme.borderColor.withValues(alpha: 0.4),
        ),
        onSelected: (selected) {
          if (!selected) return;
          setState(() {
            _statusFilter = filter;
          });
          _filterUsers();
        },
      );
    }).toList();
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

  Widget _buildProfilePreview({
    required String name,
    required String? imageUrl,
    required Color roleColor,
    bool isMobile = false,
  }) {
    final maxSize = isMobile ? 80.0 : 104.0;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxSize),
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

  String? _extractProfileImage(Map<String, dynamic> user) {
    return ProfileImageHelper.extractImageUrl(user);
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool isMobile) {
    final userName = user['name']?.toString() ?? 'Unknown';
    final userEmail = user['email']?.toString() ?? '';
    final userRole = user['role']?.toString() ?? '';
    final isActive = _isUserActive(user);
    final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
    final roleColor = _getRoleColor(userRole);
    final contactNumber = _extractContactNumber(user);
    final displayContactNumber = contactNumber.isEmpty ? _defaultContactNumber : contactNumber;
    final imageUrl = _extractProfileImage(user);

    final bannerMessage = isActive ? 'ACTIVE' : 'INACTIVE';
    final bannerColor = isActive ? AppTheme.secondaryColor : AppTheme.errorColor;
    final EdgeInsets cardPadding = isMobile
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
            onTap: () => _showAssignmentDialog(context, user, userName, userEmail, userRole, roleColor, imageUrl),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfilePreview(
                            name: userName,
                            imageUrl: imageUrl,
                            roleColor: roleColor,
                            isMobile: isMobile,
                          ),
                        ],
                      ),
                      SizedBox(width: isMobile ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              userName,
                              style: AppTheme.headingSmall.copyWith(
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            _buildContactLine(
                              icon: null,
                              label: userEmail,
                            ),
                            const SizedBox(height: 4),
                            if (userRole.isNotEmpty)
                              Text(
                                userRole,
                                style: AppTheme.bodySmall.copyWith(
                                  color: roleColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: isMobile ? 12 : 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildContactLine(
                                icon: Icons.person_outline,
                                label: 'Assigned to: ${user['assignedToCount'] ?? 0}',
                              ),
                              const SizedBox(height: 4),
                              _buildContactLine(
                                icon: Icons.badge_outlined,
                                label: 'Assigned for: ${user['assignedForCount'] ?? 0}',
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: _buildContactLine(
                                  icon: Icons.person_outline,
                                  label: 'Assigned to: ${user['assignedToCount'] ?? 0}',
                                ),
                              ),
                              Flexible(
                                child: _buildContactLine(
                                  icon: Icons.badge_outlined,
                                  label: 'Assigned for: ${user['assignedForCount'] ?? 0}',
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

  void _showAssignmentDialog(
    BuildContext context,
    Map<String, dynamic> user,
    String userName,
    String userEmail,
    String userRole,
    Color roleColor,
    String? imageUrl,
  ) {
    final isMobile = Responsive.isMobile(context);
    
    showDialog(
      context: context,
      builder: (context) => _AssignmentDialogContent(
        initialUser: user,
        initialUserName: userName,
        initialUserEmail: userEmail,
        initialUserRole: userRole,
        initialRoleColor: roleColor,
        initialImageUrl: imageUrl,
        allUsers: _users,
        isMobile: isMobile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final isDesktop = Responsive.isDesktop(context);

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Search and Filter Section - Same Line
              Container(
                padding: EdgeInsets.all(
                  isMobile ? 12 : (isTablet ? 20 : 24),
                ),
                color: AppTheme.surfaceColor,
                child: isMobile
                    ? // Mobile: Stack vertically
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Search Field
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by name, email, or role...',
                              hintStyle: TextStyle(
                                fontSize: isMobile ? 14 : 16,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                size: isMobile ? 20 : 24,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        size: isMobile ? 20 : 24,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 16 : 20,
                                vertical: isMobile ? 14 : 16,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Filter Chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _buildFilterChips(isMobile),
                          ),
                        ],
                      )
                    : // Desktop/Tablet: Same Line
                    Row(
                        children: [
                          // Search Bar (Expanded)
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search by name, email, or role...',
                                hintStyle: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  size: isMobile ? 20 : 24,
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          size: isMobile ? 20 : 24,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 16 : 20,
                                  vertical: isMobile ? 14 : 16,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 16,
                              ),
                            ),
                          ),
                          // Spacing
                          const SizedBox(width: 12),
                          // Filter Chips (Right Side)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: _buildFilterChips(isMobile),
                          ),
                        ],
                      ),
              ),
              // User Cards Grid
              Expanded(
                child: _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: isMobile ? 56 : (isTablet ? 64 : 72),
                              color: AppTheme.textSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No users found',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: isMobile ? 14 : 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final availableWidth = constraints.maxWidth;
                          final horizontalPadding = isMobile ? 16.0 : (isTablet ? 20.0 : 24.0);
                          final effectiveWidth = availableWidth - (horizontalPadding * 2);
                          final cardsPerRow = isMobile
                              ? 1
                              : isTablet
                                  ? 2
                                  : (effectiveWidth / (_cardWidth + _cardSpacing)).floor().clamp(1, _maxCardsPerRow);
                          final cardWidth = cardsPerRow > 0
                              ? (effectiveWidth - (_cardSpacing * (cardsPerRow - 1))) / cardsPerRow
                              : _cardWidth;

                          // Calculate aspect ratio based on card content (avatar 104px + padding)
                          // Approximate card height: avatar (104) + top/bottom padding (20) = ~124px minimum
                          // With content, button, and spacing, typically around 160-180px
                          final estimatedCardHeight = isMobile ? 170.0 : 160.0;
                          final aspectRatio = cardWidth / estimatedCardHeight;

                          return GridView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: isMobile ? 12.0 : 20.0,
                            ),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cardsPerRow,
                              crossAxisSpacing: _cardSpacing,
                              mainAxisSpacing: _cardSpacing,
                              childAspectRatio: aspectRatio > 0 ? aspectRatio : 1.75,
                            ),
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              return _buildUserCard(_filteredUsers[index], isMobile);
                            },
                          );
                        },
                      ),
              ),
            ],
          );

    // When embedded in dashboard, don't show AppBar (dashboard handles it)
    if (widget.embedInDashboard) {
      return content;
    }

    // When standalone, show full Scaffold with AppBar
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go('/users');
            }
          },
          tooltip: 'Back',
        ),
        title: const Text('Assign Wallets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: content,
    );
  }
}

class _AssignmentDialogContent extends StatefulWidget {
  final Map<String, dynamic> initialUser;
  final String initialUserName;
  final String initialUserEmail;
  final String initialUserRole;
  final Color initialRoleColor;
  final String? initialImageUrl;
  final List<Map<String, dynamic>> allUsers;
  final bool isMobile;

  const _AssignmentDialogContent({
    required this.initialUser,
    required this.initialUserName,
    required this.initialUserEmail,
    required this.initialUserRole,
    required this.initialRoleColor,
    required this.initialImageUrl,
    required this.allUsers,
    required this.isMobile,
  });

  @override
  State<_AssignmentDialogContent> createState() => _AssignmentDialogContentState();
}

class _AssignmentDialogContentState extends State<_AssignmentDialogContent> {
  late Map<String, dynamic> _selectedUser;
  late String _selectedUserName;
  late String _selectedUserEmail;
  late String _selectedUserRole;
  late Color _selectedRoleColor;
  late String? _selectedImageUrl;
  final TextEditingController _assignedForSearchController = TextEditingController();
  List<Map<String, dynamic>> _filteredAssignedForUsers = [];
  List<Map<String, dynamic>> _activeUsers = [];
  final GlobalKey _dropdownButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedUser = widget.initialUser;
    _selectedUserName = widget.initialUserName;
    _selectedUserEmail = widget.initialUserEmail;
    _selectedUserRole = widget.initialUserRole;
    _selectedRoleColor = widget.initialRoleColor;
    _selectedImageUrl = widget.initialImageUrl;
    _assignedForSearchController.addListener(_filterAssignedForUsers);
    _loadActiveUsers();
  }

  @override
  void dispose() {
    _assignedForSearchController.dispose();
    super.dispose();
  }

  void _loadActiveUsers() {
    setState(() {
      final selectedUserId = _selectedUser['_id']?.toString() ?? _selectedUser['id']?.toString() ?? '';
      _activeUsers = widget.allUsers.where((user) {
        final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
        // Exclude the selected user from assigned for list
        return user['isVerified'] == true && userId != selectedUserId;
      }).toList();
      _filteredAssignedForUsers = _activeUsers;
    });
  }

  void _filterAssignedForUsers() {
    final query = _assignedForSearchController.text.toLowerCase();
    setState(() {
      _filteredAssignedForUsers = _activeUsers.where((user) {
        final name = (user['name'] ?? '').toLowerCase();
        final email = (user['email'] ?? '').toLowerCase();
        final role = (user['role'] ?? '').toLowerCase();
        return query.isEmpty ||
            name.contains(query) ||
            email.contains(query) ||
            role.contains(query);
      }).toList();
    });
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

  String? _extractProfileImage(Map<String, dynamic> user) {
    return ProfileImageHelper.extractImageUrl(user);
  }

  void _onUserSelected(Map<String, dynamic> user) {
    final userName = user['name']?.toString() ?? 'Unknown';
    final userEmail = user['email']?.toString() ?? '';
    final userRole = user['role']?.toString() ?? '';
    final roleColor = _getRoleColor(userRole);
    final imageUrl = _extractProfileImage(user);
    
    setState(() {
      _selectedUser = user;
      _selectedUserName = userName;
      _selectedUserEmail = userEmail;
      _selectedUserRole = userRole;
      _selectedRoleColor = roleColor;
      _selectedImageUrl = imageUrl;
    });
    
    // Update assigned for list to exclude the selected user
    _loadActiveUsers();
    // Clear search when user changes
    _assignedForSearchController.clear();
  }

  void _showUserDropdown(BuildContext context, GlobalKey buttonKey) {
    final RenderBox? renderBox = buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    final menuHeight = (widget.allUsers.length * 60.0).clamp(0.0, 300.0);
    
    // Calculate position to open downward
    final topPosition = offset.dy + size.height;
    final bottomPosition = (topPosition + menuHeight).clamp(0.0, screenHeight);

    showMenu<Map<String, dynamic>>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        topPosition,
        offset.dx + size.width,
        bottomPosition,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      items: widget.allUsers.map((user) {
        final userName = user['name']?.toString() ?? 'Unknown';
        final userEmail = user['email']?.toString() ?? '';
        return PopupMenuItem<Map<String, dynamic>>(
          value: user,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                userName,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (userEmail.isNotEmpty)
                Text(
                  userEmail,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    ).then((selectedUser) {
      if (selectedUser != null) {
        _onUserSelected(selectedUser);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: widget.isMobile 
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
          : const EdgeInsets.all(24),
      child: Container(
        width: widget.isMobile ? screenWidth : 600,
        constraints: BoxConstraints(
          maxHeight: widget.isMobile 
              ? screenHeight * 0.9 
              : screenHeight * 0.8,
          maxWidth: widget.isMobile ? screenWidth - 32 : 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dropdown Header
            Container(
              padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: _dropdownButtonKey,
                      onTap: () => _showUserDropdown(context, _dropdownButtonKey),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.isMobile ? 12 : 16,
                          vertical: widget.isMobile ? 10 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.borderColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedUserName,
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: widget.isMobile ? 14 : 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_drop_down,
                              color: AppTheme.textSecondary,
                              size: widget.isMobile ? 20 : 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: widget.isMobile ? 8 : 12),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: widget.isMobile ? 20 : 24,
                    ),
                    padding: EdgeInsets.all(widget.isMobile ? 8 : 12),
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content - Responsive layout
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: widget.isMobile
                    ? _buildMobileLayout(context)
                    : _buildDesktopLayout(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Assigned to section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.borderColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Assigned to',
                      style: AppTheme.headingSmall.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 80,
                  alignment: Alignment.center,
                  child: Text(
                    'No assignments',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Assigned for section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Assigned for',
                      style: AppTheme.headingSmall.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search bar at the top for mobile
                TextField(
                  controller: _assignedForSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                    ),
                    suffixIcon: _assignedForSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              size: 18,
                            ),
                            onPressed: () {
                              _assignedForSearchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                // Active user list
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  child: _filteredAssignedForUsers.isEmpty
                      ? Container(
                          height: 100,
                          alignment: Alignment.center,
                          child: Text(
                            'No active users',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredAssignedForUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredAssignedForUsers[index];
                            final userName = user['name']?.toString() ?? 'Unknown';
                            final userEmail = user['email']?.toString() ?? '';
                            final userRole = user['role']?.toString() ?? '';
                            final roleColor = _getRoleColor(userRole);
                            
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: roleColor.withValues(alpha: 0.2),
                                child: Text(
                                  userName.isNotEmpty
                                      ? userName.substring(0, 1).toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: roleColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                userName,
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                userEmail,
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.25,
                                ),
                                child: Text(
                                  userRole,
                                  style: AppTheme.bodySmall.copyWith(
                                    color: roleColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // Cancel and Save buttons
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: AppTheme.borderColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Implement save functionality
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Save',
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Container(
      height: 400,
      child: Row(
        children: [
          // Left side - Assigned to
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(
                    color: AppTheme.borderColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Assigned to',
                        style: AppTheme.headingSmall.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Content for assigned to
                  Expanded(
                    child: Center(
                      child: Text(
                        'No assignments',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right side - Assigned for
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.badge_outlined,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Assigned for',
                        style: AppTheme.headingSmall.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Active user list
                  Expanded(
                    child: _filteredAssignedForUsers.isEmpty
                        ? Center(
                            child: Text(
                              'No active users',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredAssignedForUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredAssignedForUsers[index];
                              final userName = user['name']?.toString() ?? 'Unknown';
                              final userEmail = user['email']?.toString() ?? '';
                              final userRole = user['role']?.toString() ?? '';
                              final roleColor = _getRoleColor(userRole);
                              
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: roleColor.withValues(alpha: 0.2),
                                  child: Text(
                                    userName.isNotEmpty
                                        ? userName.substring(0, 1).toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: roleColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  userName,
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  userEmail,
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(
                                  userRole,
                                  style: AppTheme.bodySmall.copyWith(
                                    color: roleColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  // Search bar at the end
                  const SizedBox(height: 12),
                  TextField(
                    controller: _assignedForSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                      ),
                      suffixIcon: _assignedForSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                size: 20,
                              ),
                              onPressed: () {
                                _assignedForSearchController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                  // Cancel and Save buttons
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: AppTheme.borderColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Implement save functionality
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Save',
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
