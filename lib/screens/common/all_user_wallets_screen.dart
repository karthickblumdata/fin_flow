import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../services/wallet_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/user_action_bottom_sheet.dart';
import '../../widgets/add_amount_dialog.dart';
import '../../widgets/add_collection_dialog.dart';
import '../../widgets/add_expense_dialog.dart';
import '../../widgets/add_transaction_dialog.dart';

const double _walletCardMobileWidth = 260;
const double _walletCardTabletWidth = 272;
const double _walletCardDesktopWidth = 280;
const double _walletCardHeight = 224;
const double _walletCardVerticalSpacing = 14;
const double _walletCardHorizontalSpacing = 12;
const double _walletCardAvatarBaseSize = 72;
const double _walletCardAvatarCompactFactor = 0.88;

enum WalletStatusFilter { all, active, inactive }

class AllUserWalletsScreen extends StatefulWidget {
  const AllUserWalletsScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<AllUserWalletsScreen> createState() => _AllUserWalletsScreenState();
}

class _AllUserWalletsScreenState extends State<AllUserWalletsScreen> {
  List<dynamic> _wallets = [];
  List<dynamic> _filteredWallets = [];
  bool _isLoading = true;
  bool _isDrawerOpen = false;
  final TextEditingController _searchController = TextEditingController();
  WalletStatusFilter _statusFilter = WalletStatusFilter.active;
  
  // Auto-refresh configuration
  Timer? _autoRefreshTimer;
  static const Duration _autoRefreshInterval = Duration(seconds: 30); // Refresh every 30 seconds
  static const Duration _debounceRefreshDelay = Duration(seconds: 2); // Debounce to prevent rapid refreshes
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterWallets);
    _loadWallets();
    
    // Initialize socket for real-time updates
    _initializeSocketListeners();
    
    // Start auto-refresh timer
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _cleanupSocketListeners();
    _searchController.dispose();
    super.dispose();
  }

  void _filterWallets() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredWallets = _wallets.where((wallet) {
        final user = wallet['userId'];
        
        // Handle wallets without user data
        if (user == null) {
          // If there's a search query, skip wallets without user data
          if (query.isNotEmpty) return false;
          // Otherwise include them (they'll show as "Unknown" user)
          // But still apply status filter
          bool matchesStatus = true;
          if (_statusFilter == WalletStatusFilter.active) {
            matchesStatus = _isWalletActive(wallet);
          } else if (_statusFilter == WalletStatusFilter.inactive) {
            matchesStatus = !_isWalletActive(wallet);
          }
          return matchesStatus;
        }

        final userName = (user['name'] ?? '').toLowerCase();
        final userEmail = (user['email'] ?? '').toLowerCase();
        final userRole = (user['role'] ?? '').toLowerCase();

        // Search filter
        final matchesSearch = query.isEmpty ||
            userName.contains(query) ||
            userEmail.contains(query) ||
            userRole.contains(query);

        bool matchesStatus = true;
        if (_statusFilter == WalletStatusFilter.active) {
          matchesStatus = _isWalletActive(wallet);
        } else if (_statusFilter == WalletStatusFilter.inactive) {
          matchesStatus = !_isWalletActive(wallet);
        }

        return matchesSearch && matchesStatus;
      }).toList();
      
      print('🔍 [ALL USER WALLETS] Filtered: ${_filteredWallets.length} wallets (from ${_wallets.length} total)');
      print('   Status filter: $_statusFilter');
      print('   Search query: "$query"');
    });
  }

  bool _isWalletActive(dynamic wallet) {
    final balance = _parseAmount(wallet['totalBalance']);
    final statusValue = wallet['status']?.toString().toLowerCase();
    final bool isActive = (wallet['isActive'] == true) ||
        (statusValue == 'active') ||
        balance > 0;
    return isActive;
  }

  /// Auto-refresh method with debouncing to prevent excessive API calls
  /// This method ensures wallet data is refreshed when changes occur
  void _autoRefreshWallets() {
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
    
    // Refresh wallets data silently (without showing loading state initially)
    _loadWallets();
  }

  /// Start the auto-refresh timer
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _autoRefreshWallets();
    });
  }

  /// Stop the auto-refresh timer
  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  /// Initialize socket listeners for real-time wallet updates
  void _initializeSocketListeners() {
    try {
      // Initialize socket service
      SocketService.initialize().then((_) {
        if (!mounted) return;
        
        // Listen to amount updates (wallet changes)
        SocketService.onAmountUpdate((data) {
          if (mounted) {
            // Refresh wallets when any wallet amount changes
            _autoRefreshWallets();
          }
        });
        
        // Listen to dashboard updates (general updates)
        SocketService.onDashboardUpdate((data) {
          if (mounted) {
            // Refresh wallets when dashboard data updates
            _autoRefreshWallets();
          }
        });
      });
    } catch (e) {
      print('❌ [ALL USER WALLETS] Error initializing socket listeners: $e');
    }
  }

  /// Clean up socket listeners
  void _cleanupSocketListeners() {
    try {
      // Socket listeners are automatically cleaned up when socket disconnects
      // No explicit cleanup needed as SocketService manages its own lifecycle
    } catch (e) {
      print('❌ [ALL USER WALLETS] Error cleaning up socket listeners: $e');
    }
  }

  Future<void> _loadWallets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await WalletService.getAllWallets();
      if (result['success'] == true && mounted) {
        final wallets = result['wallets'] ?? [];
        print('🔍 [ALL USER WALLETS] Loaded ${wallets.length} wallets from API');
        
        // Debug: Check user roles distribution
        final roleCounts = <String, int>{};
        int nullUserCount = 0;
        for (final wallet in wallets) {
          final user = wallet['userId'];
          if (user == null) {
            nullUserCount++;
          } else {
            final role = user['role']?.toString() ?? 'Unknown';
            roleCounts[role] = (roleCounts[role] ?? 0) + 1;
          }
        }
        print('   Role distribution: $roleCounts');
        if (nullUserCount > 0) {
          print('   Wallets without user data: $nullUserCount');
        }
        
        setState(() {
          _wallets = wallets;
          _isLoading = false;
        });
        _filterWallets();
        print('   After filtering: ${_filteredWallets.length} wallets shown');
      } else {
        final errorMessage = result['message'] ?? 'Failed to load wallets';
        print('❌ [ALL USER WALLETS] Failed to load wallets: $errorMessage');
        
        // Show error message to user if it's a permission error
        if (mounted && errorMessage.toLowerCase().contains('permission')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Permission denied: $errorMessage'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        
        if (mounted) {
          setState(() {
            _wallets = [];
            _isLoading = false;
          });
          _filterWallets();
        }
      }
    } catch (e) {
      print('❌ [ALL USER WALLETS] Error loading wallets: $e');
      if (mounted) {
        setState(() {
          _wallets = [];
          _isLoading = false;
        });
        _filterWallets();
      }
    }
  }

  Widget _buildStatusLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildLegendEntry(
          icon: Icons.flag_outlined,
          label: 'Flagged',
          color: AppTheme.errorColor,
        ),
        _buildLegendEntry(
          icon: Icons.rule_folder_outlined,
          label: 'Unapproved',
          color: AppTheme.warningColor,
        ),
      ],
    );
  }

  Widget _buildLegendEntry({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 14,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
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
              // Search and Filter Section
              Container(
                padding: EdgeInsets.all(
                  isMobile ? 12 : (isTablet ? 20 : 24),
                ),
                color: AppTheme.surfaceColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    SizedBox(height: isMobile ? 12 : 16),
                    // Filter Chips - wrap on mobile, row on larger screens
                    isMobile
                        ? Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _buildFilterChips(isMobile),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 12,
                                  children: _buildFilterChips(isMobile),
                                ),
                              ),
                            ],
                          ),
                    SizedBox(height: isMobile ? 10 : 12),
                    _buildStatusLegend(),
                  ],
                ),
              ),
              // Wallet List
              Expanded(
                child: _filteredWallets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: isMobile ? 56 : (isTablet ? 64 : 72),
                              color: AppTheme.textSecondary.withValues(alpha: 0.5),
                            ),
                            SizedBox(height: isMobile ? 12 : 16),
                            Text(
                              'No wallets found',
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
                            final double maxWidth = constraints.maxWidth;
                            final double cardSpacing = _walletCardHorizontalSpacing;
                            
                            // Calculate optimal card width based on screen size
                            double targetWidth;
                            int maxColumns;
                            
                            if (isMobile) {
                              targetWidth = _walletCardMobileWidth;
                              maxColumns = 2;
                            } else if (isTablet) {
                              targetWidth = _walletCardTabletWidth;
                              maxColumns = 3;
                            } else {
                              targetWidth = _walletCardDesktopWidth;
                              maxColumns = 4;
                            }

                            // Calculate columns based on available width
                            int crossAxisCount = ((maxWidth + cardSpacing) / 
                                (targetWidth + cardSpacing)).floor();
                            crossAxisCount = crossAxisCount.clamp(1, maxColumns);

                            // Responsive padding
                            final double horizontalPadding = isMobile ? 12 : 
                                (isTablet ? 16 : 20);
                            final double verticalPadding = isMobile ? 12 : 
                                (isTablet ? 16 : 20);

                            return GridView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding,
                                vertical: verticalPadding,
                              ),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: cardSpacing,
                                mainAxisSpacing: _walletCardVerticalSpacing,
                                mainAxisExtent: _walletCardHeight,
                              ),
                              itemCount: _filteredWallets.length,
                              itemBuilder: (context, index) {
                                final wallet = _filteredWallets[index];
                                return _buildWalletCard(wallet);
                              },
                            );
                          },
                        ),
              ),
            ],
          );

    if (!widget.showAppBar) {
      return content;
    }

    // Build responsive AppBar
    PreferredSizeWidget? appBar;
    if (isMobile) {
      appBar = AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => setState(() => _isDrawerOpen = !_isDrawerOpen),
          tooltip: 'Menu',
        ),
        title: Text(
          'All User Wallets',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWallets,
            tooltip: 'Refresh',
          ),
        ],
      );
    } else {
      appBar = AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          'All User Wallets',
          style: TextStyle(
            fontSize: isTablet ? 20 : 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWallets,
            tooltip: 'Refresh',
          ),
        ],
      );
    }

    return Scaffold(
      appBar: appBar,
      body: Stack(
        children: [
          content,
          if (isMobile && _isDrawerOpen)
            GestureDetector(
              onTap: () => setState(() => _isDrawerOpen = false),
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          if (isMobile && _isDrawerOpen)
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: _buildDrawer(),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildFilterChips(bool isMobile) {
    return WalletStatusFilter.values.map((filter) {
      final isSelected = _statusFilter == filter;
      String label = 'All';
      if (filter == WalletStatusFilter.active) {
        label = 'Active';
      } else if (filter == WalletStatusFilter.inactive) {
        label = 'Inactive';
      }
      return ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isMobile ? 13 : 14,
            color: isSelected
                ? Colors.white
                : AppTheme.textSecondary,
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
          _filterWallets();
        },
      );
    }).toList();
  }

  Widget _buildDrawer() {
    return Material(
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'All User Wallets',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(
                  icon: Icons.dashboard_outlined,
                  title: 'Dashboard',
                  onTap: () {
                    setState(() => _isDrawerOpen = false);
                    context.go('/dashboard');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'My Wallet',
                  onTap: () {
                    setState(() => _isDrawerOpen = false);
                    context.push('/wallet');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.payment_outlined,
                  title: 'Collections',
                  onTap: () {
                    setState(() => _isDrawerOpen = false);
                    context.push('/collections');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.assessment_outlined,
                  title: 'Reports',
                  onTap: () {
                    setState(() => _isDrawerOpen = false);
                    context.push('/reports');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.people_outlined,
                  title: 'Manage Users',
                  onTap: () {
                    setState(() => _isDrawerOpen = false);
                    context.push('/manage-users');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.payment,
                  title: 'Payment Modes',
                  onTap: () {
                    setState(() => _isDrawerOpen = false);
                    context.push('/payment-modes');
                  },
                ),
                const Divider(height: 32),
                _buildDrawerItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () {
                    setState(() => _isDrawerOpen = false);
                    Navigator.of(context).pushNamed('/super-admin-settings');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: () {
                    setState(() => _isDrawerOpen = false);
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppTheme.errorColor : AppTheme.textPrimary;
    
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildWalletCard(dynamic wallet) {
    final user = wallet['userId'];
    if (user == null) return const SizedBox.shrink();

    final userId = user['_id'] ?? user['id'] ?? '';
    final userName = user['name'] ?? 'Unknown';
    final userEmail = user['email'] ?? '';
    final userRole = user['role'] ?? 'Staff';
    final balance = _parseAmount(wallet['totalBalance']);
    final unapprovedCount = _resolveCount(
      wallet,
      primaryKeys: const [
        'unapprovedCount',
        'pendingCount',
        'pendingTransactions',
        'pendingApprovals',
        'unapproved',
        'unapprovedTransactions',
        'unapprovedExpenses',
      ],
      fallbackContainers: const [
        {'container': 'statusCounts', 'keys': ['unapproved', 'pending']},
        {'container': 'statusSummary', 'keys': ['unapproved', 'pending']},
      ],
    );
    final flaggedCount = _resolveCount(
      wallet,
      primaryKeys: const [
        'flaggedCount',
        'flagged',
        'flaggedTransactions',
        'flaggedExpenses',
      ],
      fallbackContainers: const [
        {'container': 'statusCounts', 'keys': ['flagged']},
        {'container': 'statusSummary', 'keys': ['flagged']},
      ],
    );
    final isActive = (wallet['isActive'] == true) ||
        (wallet['status']?.toString().toLowerCase() == 'active') ||
        balance > 0;

    return UserProfileCard(
      userName: userName,
      userEmail: userEmail,
      userRole: userRole,
      balance: balance,
      unapprovedCount: unapprovedCount,
      flaggedCount: flaggedCount,
      isActive: isActive,
      formatCurrency: _formatCurrency,
      onTap: () {
        _showUserActionMenu(
          context: context,
          userId: userId,
          userName: userName,
          userEmail: userEmail,
        );
      },
    );
  }

  void _showUserActionMenu({
    required BuildContext context,
    required String userId,
    required String userName,
    required String userEmail,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return UserActionBottomSheet(
          userId: userId,
          userName: userName,
          userEmail: userEmail,
          onAddAmount: () {
            _handleAddAmount(context, userId, userName);
          },
          onAddCollection: () {
            _handleAddCollection(context, userId, userName);
          },
          onAddExpense: () {
            _handleAddExpense(context, userId, userName);
          },
          onAddTransaction: () {
            _handleAddTransaction(context, userId, userName);
          },
        );
      },
    );
  }

  void _handleAddAmount(BuildContext context, String userId, String userName) {
    // Show Add Amount dialog using root navigator to ensure it works after bottom sheet closes
    showDialog(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AddAmountDialog(
          userId: userId,
          userName: userName,
          onSuccess: () {
            // Refresh wallets after successful amount addition
            _loadWallets();
          },
        );
      },
    );
  }

  void _handleAddCollection(BuildContext context, String userId, String userName) {
    // Show Add Collection dialog using root navigator to ensure it works after bottom sheet closes
    showDialog(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AddCollectionDialog(
          selectedUserId: userId,
          selectedUserName: userName,
          onSuccess: () {
            // Refresh wallets after successful collection creation
            _loadWallets();
          },
        );
      },
    );
  }

  void _handleAddExpense(BuildContext context, String userId, String userName) {
    // Show Add Expense dialog using root navigator to ensure it works after bottom sheet closes
    showDialog(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AddExpenseDialog(
          userId: userId,
          userName: userName,
          onSuccess: () {
            _loadWallets();
          },
        );
      },
    );
  }

  void _handleAddTransaction(BuildContext context, String userId, String userName) {
    // Show Add Transaction dialog using root navigator to ensure it works after bottom sheet closes
    showDialog(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AddTransactionDialog(
          preSelectedReceiverId: userId,
          preSelectedReceiverName: userName,
          onSuccess: () {
            _loadWallets();
          },
        );
      },
    );
  }

  double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

int _resolveCount(
  dynamic source, {
  required List<String> primaryKeys,
  List<Map<String, dynamic>> fallbackContainers = const [],
}) {
  if (source is Map) {
    for (final key in primaryKeys) {
      if (!source.containsKey(key)) continue;
      final parsed = _parseCount(source[key]);
      if (parsed != null) {
        return parsed;
      }
    }

    for (final containerConfig in fallbackContainers) {
      final containerKey = containerConfig['container'];
      final keys = containerConfig['keys'] as List<String>? ?? const [];
      if (containerKey is String && source[containerKey] is Map) {
        final nestedMap = source[containerKey] as Map;
        for (final key in keys) {
          if (!nestedMap.containsKey(key)) continue;
          final parsed = _parseCount(nestedMap[key]);
          if (parsed != null) {
            return parsed;
          }
        }
      }
    }
  }
  return 0;
}

int? _parseCount(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value);
  if (value is List) return value.length;
  return null;
}

  String _formatCurrency(double value) {
    final double absValue = value.abs();
    final NumberFormat numberFormat = NumberFormat('#,##0.##');
    return '₹${numberFormat.format(value)}';
  }

}


// UserProfileCard start
class UserProfileCard extends StatelessWidget {
  UserProfileCard({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    required this.balance,
    required this.unapprovedCount,
    required this.flaggedCount,
    required this.isActive,
    required this.formatCurrency,
    this.onTap,
  });

  final String userName;
  final String userEmail;
  final String userRole;
  final double balance;
  final int unapprovedCount;
  final int flaggedCount;
  final bool isActive;
  final String Function(double) formatCurrency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardRadius = BorderRadius.circular(14);
    final initials = _computeInitials(userName);
    final Color activeBannerColor = AppTheme.secondaryColor;
    final String bannerMessage = isActive ? 'ACTIVE' : 'INACTIVE';
    final Color bannerColor = isActive ? activeBannerColor : AppTheme.errorColor;
    final String balanceText = formatCurrency(balance);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: cardRadius,
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.zero,
          constraints: const BoxConstraints(minHeight: _walletCardHeight),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: cardRadius,
            border: Border.all(
              color: AppTheme.borderColor.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: cardRadius,
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isCompactLayout = constraints.maxWidth <= (_walletCardTabletWidth + 16);
                  final EdgeInsets contentPadding = isCompactLayout
                      ? const EdgeInsets.fromLTRB(14, 16, 14, 18)
                      : const EdgeInsets.fromLTRB(16, 18, 16, 20);
                  final Widget content = isCompactLayout
                      ? _buildCompactContent(
                          theme: theme,
                          initials: initials,
                          userName: userName,
                          userEmail: userEmail,
                          userRole: userRole,
                          balanceText: balanceText,
                          balanceValue: balance,
                          unapprovedCount: unapprovedCount,
                          flaggedCount: flaggedCount,
                        )
                      : _buildStandardContent(
                          theme: theme,
                          initials: initials,
                          userName: userName,
                          userEmail: userEmail,
                          userRole: userRole,
                          balanceText: balanceText,
                          balanceValue: balance,
                          unapprovedCount: unapprovedCount,
                          flaggedCount: flaggedCount,
                        );

                  return Padding(
                    padding: contentPadding,
                    child: content,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandardContent({
    required ThemeData theme,
    required String initials,
    required String userName,
    required String userEmail,
    required String userRole,
    required String balanceText,
    required double balanceValue,
    required int unapprovedCount,
    required int flaggedCount,
  }) {
    return _buildCardContent(
      theme: theme,
      initials: initials,
      userName: userName,
      userEmail: userEmail,
      userRole: userRole,
      balanceText: balanceText,
      balanceValue: balanceValue,
      unapprovedCount: unapprovedCount,
      flaggedCount: flaggedCount,
      compact: false,
    );
  }

  Widget _buildCompactContent({
    required ThemeData theme,
    required String initials,
    required String userName,
    required String userEmail,
    required String userRole,
    required String balanceText,
    required double balanceValue,
    required int unapprovedCount,
    required int flaggedCount,
  }) {
    return _buildCardContent(
      theme: theme,
      initials: initials,
      userName: userName,
      userEmail: userEmail,
      userRole: userRole,
      balanceText: balanceText,
      balanceValue: balanceValue,
      unapprovedCount: unapprovedCount,
      flaggedCount: flaggedCount,
      compact: true,
    );
  }

  Widget _buildCardContent({
    required ThemeData theme,
    required String initials,
    required String userName,
    required String userEmail,
    required String userRole,
    required String balanceText,
    required double balanceValue,
    required int unapprovedCount,
    required int flaggedCount,
    bool compact = false,
  }) {
    final double avatarSize = compact
        ? _walletCardAvatarBaseSize * _walletCardAvatarCompactFactor
        : _walletCardAvatarBaseSize;
    final double nameFontSize = compact ? 16 : 18;
    final double emailFontSize = compact ? 12 : 13;
    final double headerSpacing = compact ? 10 : 12;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildAvatar(initials, size: avatarSize),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ) ??
                        TextStyle(
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: emailFontSize,
                          color: AppTheme.textSecondary,
                        ) ??
                        TextStyle(
                          fontSize: emailFontSize,
                          color: AppTheme.textSecondary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  _buildRoleChip(theme, userRole, compact: compact),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: headerSpacing - (compact ? 2 : 4)),
        _buildMetricsRow(
          theme: theme,
          balanceText: balanceText,
          balanceValue: balanceValue,
          unapprovedCount: unapprovedCount,
          flaggedCount: flaggedCount,
          compact: compact,
        ),
      ],
    );
  }

  Widget _buildMetricsRow({
    required ThemeData theme,
    required String balanceText,
    required double balanceValue,
    required int unapprovedCount,
    required int flaggedCount,
    bool compact = false,
  }) {
    return _buildMetricsContent(
      theme: theme,
      balanceText: balanceText,
      balanceValue: balanceValue,
      flaggedCount: flaggedCount,
      unapprovedCount: unapprovedCount,
      compact: compact,
    );
  }

  Widget _buildBalanceColumn(
    ThemeData theme,
    String balanceText, {
    required double balanceValue,
    bool compact = false,
  }) {
    final EdgeInsets padding = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 14);

    final Color amountColor = balanceValue > 0
        ? const Color(0xFF1F9D4D)
        : (balanceValue < 0 ? AppTheme.errorColor : AppTheme.textPrimary);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EDFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Balance',
            style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: AppTheme.textSecondary,
                ) ??
                TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: AppTheme.textSecondary,
                ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            balanceText,
            style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ) ??
                TextStyle(
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSummaryBox({
    required ThemeData theme,
    required int flaggedCount,
    required int unapprovedCount,
    required bool compact,
  }) {
    final TextStyle countStyle = theme.textTheme.titleMedium?.copyWith(
          fontSize: compact ? 13 : 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ) ??
        TextStyle(
          fontSize: compact ? 13 : 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EDFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 10 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatusSummaryRow(
            icon: Icons.flag_outlined,
            color: AppTheme.errorColor,
            count: flaggedCount,
            countStyle: countStyle,
            compact: compact,
          ),
          SizedBox(height: compact ? 8 : 9),
          _buildStatusSummaryRow(
            icon: Icons.rule_folder_outlined,
            color: AppTheme.warningColor,
            count: unapprovedCount,
            countStyle: countStyle,
            compact: compact,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSummaryRow({
    required IconData icon,
    required Color color,
    required int count,
    required TextStyle countStyle,
    required bool compact,
  }) {
    final double iconBoxSize = compact ? 22 : 24;
    final double iconSize = compact ? 11.5 : 13;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: iconBoxSize,
          height: iconBoxSize,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: iconSize, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          count.toString(),
          style: countStyle.copyWith(color: color),
        ),
      ],
    );
  }

  Widget _buildMetricsContent({
    required ThemeData theme,
    required String balanceText,
    required double balanceValue,
    required int flaggedCount,
    required int unapprovedCount,
    required bool compact,
  }) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatusSummaryBox(
            theme: theme,
            flaggedCount: flaggedCount,
            unapprovedCount: unapprovedCount,
            compact: compact,
          ),
          const SizedBox(height: 12),
          _buildBalanceColumn(
            theme,
            balanceText,
            balanceValue: balanceValue,
            compact: compact,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusSummaryBox(
          theme: theme,
          flaggedCount: flaggedCount,
          unapprovedCount: unapprovedCount,
          compact: compact,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBalanceColumn(
            theme,
            balanceText,
            balanceValue: balanceValue,
            compact: compact,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleChip(ThemeData theme, String userRole, {bool compact = false}) {
    final EdgeInsets padding = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    final double fontSize = compact ? 10 : 11;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        userRole,
        style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ) ??
            TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
      ),
    );
  }

  Widget _buildAvatar(String initials, {double size = 56, bool stretchVertically = false}) {
    final BorderRadius borderRadius = BorderRadius.circular(size * 0.28);
    final BoxDecoration decoration = const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
    final TextStyle textStyle = TextStyle(
      color: Colors.white,
      fontSize: size * 0.36,
      fontWeight: FontWeight.w700,
    );

    if (!stretchVertically) {
      return Container(
        width: size,
        height: size,
        decoration: decoration.copyWith(borderRadius: borderRadius),
        alignment: Alignment.center,
        child: Text(initials, style: textStyle),
      );
    }

    return SizedBox(
      width: size,
      child: Container(
        height: double.infinity,
        decoration: decoration.copyWith(borderRadius: borderRadius),
        alignment: Alignment.center,
        child: Text(initials, style: textStyle),
      ),
    );
  }

  String _computeInitials(String name) {
    if (name.trim().isEmpty) return '--';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final word = parts.first;
      final length = word.length;
      if (length >= 2) {
        return word.substring(0, 2).toUpperCase();
      }
      return word.substring(0, 1).toUpperCase();
    }
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}
// UserProfileCard end