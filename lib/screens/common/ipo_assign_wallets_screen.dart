import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/responsive.dart';

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

  Widget _buildUserCard(Map<String, dynamic> user, bool isMobile) {
    final userName = user['name']?.toString() ?? 'Unknown';
    final userEmail = user['email']?.toString() ?? '';
    final userRole = user['role']?.toString() ?? '';
    final isActive = _isUserActive(user);
    final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';

    // Get user initials for avatar
    final initials = userName
        .split(' ')
        .take(2)
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
        .join('');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.borderColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _assignWallet(userId, userName),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          height: _cardHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar and Status Row
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initials.isNotEmpty ? initials : '?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.secondaryColor.withOpacity(0.15)
                          : AppTheme.textSecondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? AppTheme.secondaryColor
                            : AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // User Name
              Text(
                userName,
                style: AppTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Email
              Text(
                userEmail,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Role
              Text(
                userRole,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Assign Wallet Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _assignWallet(userId, userName),
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  label: const Text('Assign Wallet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(
                          isMobile ? 12 : (isTablet ? 20 : 24),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final availableWidth = constraints.maxWidth;
                            final cardsPerRow = isMobile
                                ? 1
                                : isTablet
                                    ? 2
                                    : (availableWidth / (_cardWidth + _cardSpacing)).floor().clamp(1, _maxCardsPerRow);
                            final cardWidth = (availableWidth - (_cardSpacing * (cardsPerRow - 1))) / cardsPerRow;

                            return Wrap(
                              spacing: _cardSpacing,
                              runSpacing: _cardSpacing,
                              children: _filteredUsers.map((user) {
                                return SizedBox(
                                  width: cardWidth,
                                  child: _buildUserCard(user, isMobile),
                                );
                              }).toList(),
                            );
                          },
                        ),
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
