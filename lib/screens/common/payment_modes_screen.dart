import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../services/payment_mode_service.dart';
import '../../services/user_service.dart';
import '../../services/socket_service.dart';

class PaymentModesScreen extends StatelessWidget {
  final bool showAppBar;
  final VoidCallback? onBackPressed;
  
  const PaymentModesScreen({
    super.key, 
    this.showAppBar = true,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _PaymentModesScreenContent(
      showAppBar: showAppBar,
      onBackPressed: onBackPressed,
    );
  }
}

class _PaymentModesScreenContent extends StatefulWidget {
  final bool showAppBar;
  final VoidCallback? onBackPressed;
  
  const _PaymentModesScreenContent({
    required this.showAppBar,
    this.onBackPressed,
  });

  @override
  State<_PaymentModesScreenContent> createState() => _PaymentModesScreenContentState();
}

class _PaymentModesScreenContentState extends State<_PaymentModesScreenContent> {
  List<Map<String, dynamic>> _paymentModes = [];
  bool _isLoading = true;
  
  // Auto-refresh configuration
  Timer? _autoRefreshTimer;
  static const Duration _autoRefreshInterval = Duration(seconds: 30); // Refresh every 30 seconds
  static const Duration _debounceRefreshDelay = Duration(seconds: 2); // Debounce to prevent rapid refreshes
  DateTime? _lastRefreshTime;
  
  @override
  void initState() {
    super.initState();
    _loadPaymentModes();
    
    // Start auto-refresh timer
    _startAutoRefresh();
    
    // Setup socket listeners
    _setupSocketListeners();
  }

  Future<void> _loadPaymentModes() async {
    setState(() {
      _isLoading = true;
    });

    final result = await PaymentModeService.getPaymentModes();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          final backendModes = result['paymentModes'] as List<dynamic>? ?? [];
          _paymentModes = backendModes.map((mode) {
            // Parse description to extract additional fields
            final parsed = PaymentModeService.parseDescription(mode['description']);
            final assignedReceiver = mode['assignedReceiver'];
            String? receiverName;
            if (assignedReceiver is Map) {
              receiverName = assignedReceiver['name'] as String?;
            }
            
            return {
              'id': mode['_id'] ?? mode['id'],
              'name': mode['modeName'] ?? '',
              'description': parsed['description'] ?? mode['description'] ?? '',
              'autoPay': mode['autoPay'] ?? false,
              'isActive': mode['isActive'] ?? true,
              'receiver': receiverName ?? 'Admin 1',
              'mode': parsed['mode'] ?? 'UPI',
              'display': parsed['display'] ?? ['Collection'],
              'upiId': parsed['upiId'],
              'assignedReceiver': mode['assignedReceiver'] is Map 
                  ? mode['assignedReceiver']['_id'] 
                  : mode['assignedReceiver'],
              'autoTransactionCreation': mode['autoPay'] ?? false,
              'assignedUser': receiverName,
            };
          }).toList();
        } else {
          // Show error message with details
          final errorMessage = result['message'] ?? 'Failed to load payment modes';
          final statusCode = result['statusCode'];
          final fullMessage = statusCode != null 
              ? 'Error $statusCode: $errorMessage' 
              : errorMessage;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(fullMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          
          // Log error for debugging
          print('Payment modes load error: $result');
        }
      });
    }
  }

  /// Setup socket listeners for real-time updates
  void _setupSocketListeners() {
    // Listen to dashboard updates (general updates)
    SocketService.onDashboardUpdate((data) {
      if (mounted) {
        _autoRefreshPaymentModes();
      }
    });
    
    // Listen to amount updates (wallet/transaction updates that might affect payment modes)
    SocketService.onAmountUpdate((data) {
      if (mounted) {
        _autoRefreshPaymentModes();
      }
    });
  }

  /// Auto-refresh method with debouncing to prevent excessive API calls
  /// This method ensures payment modes data is refreshed when changes occur
  void _autoRefreshPaymentModes() {
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
    
    // Refresh payment modes data silently
    _loadPaymentModes();
  }

  /// Start the auto-refresh timer
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _autoRefreshPaymentModes();
    });
  }

  /// Stop the auto-refresh timer
  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {  
    final isMobile = Responsive.isMobile(context);

    if (_isLoading) {
      return Scaffold(
        appBar: widget.showAppBar ? AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (widget.onBackPressed != null) {
                widget.onBackPressed!();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            color: AppTheme.textPrimary,
            tooltip: 'Back',
          ),
          automaticallyImplyLeading: false,
          title: const Text(
            'Add payment modes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ) : null,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.onBackPressed != null) {
              widget.onBackPressed!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          color: AppTheme.textPrimary,
          tooltip: 'Back',
        ),
        automaticallyImplyLeading: false,
        title: const Text(
          'Add payment modes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 56,
        iconTheme: const IconThemeData(
          color: AppTheme.textPrimary,
          size: 24,
        ),
        actions: [
          // Quick Actions Button
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement Quick Actions functionality
            },
            icon: const Icon(Icons.bolt, size: 18),
            label: const Text('Quick Actions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Notification Icon
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Implement notification functionality
            },
            color: AppTheme.textPrimary,
          ),
          // Refresh Icon
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // TODO: Implement refresh functionality
            },
            color: AppTheme.textPrimary,
          ),
          // Logout Icon
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // TODO: Implement logout functionality
            },
            color: AppTheme.textPrimary,
          ),
          const SizedBox(width: 8),
        ],
      ) : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = Responsive.isTablet(context);
          final double maxWidth = constraints.maxWidth;
          final double targetWidth = isMobile ? 260 : (isTablet ? 272 : 280);
          
          int crossAxisCount = (maxWidth / (targetWidth + 12)).floor();
          crossAxisCount = crossAxisCount.clamp(1, 4).toInt();
          
          if (isMobile && crossAxisCount > 2) {
            crossAxisCount = 2;
          }
          
          final double horizontalPadding = isMobile ? 12 : 20;
          final double verticalPadding = isMobile ? 16 : 20;
          
          return Column(
            children: [
              // Add New Payment Mode Button
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  12,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _showAddPaymentModeDialog,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text(
                      'Add New Payment Mode',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
              // Payment Modes Grid
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 190,
                  ),
                  itemCount: _paymentModes.length,
                  itemBuilder: (context, index) {
                    final mode = _paymentModes[index];
                    return PaymentModeCard(
                      modeName: mode['name'] as String? ?? '',
                      description: mode['description'] as String? ?? '',
                      modeType: mode['mode'] as String? ?? 'UPI',
                      receiver: mode['receiver'] as String? ?? '',
                      autoPay: mode['autoPay'] == true,
                      isActive: mode['isActive'] != false,
                      modeId: mode['id'] as String?,
                      onEdit: () => _showEditPaymentModeDialog(mode, index),
                      onToggleActive: (String? modeId, bool newStatus) async {
                        if (modeId != null) {
                          await _togglePaymentModeStatus(modeId, newStatus);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }


  void _showAddPaymentModeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _AddPaymentModeDialog(
          onSave: (paymentMode) async {
            Navigator.pop(context);
            await _savePaymentMode(paymentMode);
          },
          showUserAssignmentDialog: (BuildContext dialogContext, String? currentUserId, Function(String?, String?) onSave) {
            _showUserAssignmentDialog(dialogContext, currentUserId, onSave);
          },
        );
      },
    );
  }

  Future<void> _savePaymentMode(Map<String, dynamic> paymentMode) async {
    setState(() {
      _isLoading = true;
    });

    final result = await PaymentModeService.createPaymentMode(
      modeName: paymentMode['name'],
      description: paymentMode['description'],
      autoPay: paymentMode['autoTransactionCreation'] ?? false,
      assignedReceiver: paymentMode['assignedReceiver'],
      isActive: paymentMode['isActive'] ?? true,
      mode: paymentMode['mode'],
      display: paymentMode['display'],
      upiId: paymentMode['upiId'],
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        await _loadPaymentModes();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment mode added successfully'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to add payment mode'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updatePaymentMode(String id, Map<String, dynamic> paymentMode) async {
    setState(() {
      _isLoading = true;
    });

    final result = await PaymentModeService.updatePaymentMode(
      id,
      modeName: paymentMode['name'],
      description: paymentMode['description'],
      autoPay: paymentMode['autoTransactionCreation'] ?? false,
      assignedReceiver: paymentMode['assignedReceiver'],
      isActive: paymentMode['isActive'] ?? true,
      mode: paymentMode['mode'],
      display: paymentMode['display'],
      upiId: paymentMode['upiId'],
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        await _loadPaymentModes();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment mode updated successfully'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update payment mode'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePaymentModeStatus(String modeId, bool newStatus) async {
    setState(() {
      _isLoading = true;
    });

    // Find the mode to get all its data
    final mode = _paymentModes.firstWhere(
      (m) => m['id'] == modeId,
      orElse: () => {},
    );

    if (mode.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final result = await PaymentModeService.updatePaymentMode(
      modeId,
      modeName: mode['name'],
      description: mode['description'],
      autoPay: mode['autoPay'] ?? false,
      assignedReceiver: mode['assignedReceiver'],
      isActive: newStatus,
      mode: mode['mode'],
      display: mode['display'],
      upiId: mode['upiId'],
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        await _loadPaymentModes();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Payment mode activated' : 'Payment mode deactivated'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update payment mode status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditPaymentModeDialog(Map<String, dynamic> mode, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return _EditPaymentModeDialog(
          mode: mode,
          onSave: (paymentMode) async {
            Navigator.pop(context);
            final id = mode['id'] as String?;
            if (id != null) {
              await _updatePaymentMode(id, paymentMode);
            }
          },
          showUserAssignmentDialog: (BuildContext dialogContext, String? currentUserId, Function(String?, String?) onSave) {
            _showUserAssignmentDialog(dialogContext, currentUserId, onSave);
          },
        );
      },
    );
  }

  Future<void> _deletePaymentMode(int index) async {
    final mode = _paymentModes[index];
    final modeId = mode['id'] as String?;
    
    if (modeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete: Payment mode ID not found'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Mode'),
        content: Text('Are you sure you want to delete "${mode['name']}"?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    final result = await PaymentModeService.deletePaymentMode(modeId);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        await _loadPaymentModes();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment mode deleted successfully'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to delete payment mode'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showUserAssignmentDialog(
    BuildContext context,
    String? currentUserId,
    Function(String?, String?) onSave, // userId, userName
  ) async {
    // Fetch real users from backend
    final result = await UserService.getUsers();
    List<Map<String, dynamic>> allUsers = [];
    
    if (result['success'] == true) {
      final users = result['users'] as List<dynamic>? ?? [];
      allUsers = users.map((u) {
        final userId = u['_id'] ?? u['id'];
        final userName = u['name'] ?? 'Unknown User';
        return <String, dynamic>{
          'id': userId.toString(),
          'name': userName.toString(),
        };
      }).toList();
    } else {
      // Fallback to empty list if fetch fails
      allUsers = [];
    }
    
    String? selectedUserId = currentUserId; // Store ID instead of name
    String? selectedUserName;
    
    // Find current user name if ID is provided
    if (currentUserId != null && currentUserId.isNotEmpty) {
      final currentUser = allUsers.firstWhere(
        (u) => u['id'] == currentUserId,
        orElse: () => <String, dynamic>{
          'id': currentUserId!,
          'name': 'Unknown User',
        },
      );
      selectedUserName = currentUser['name'] as String;
    }
    final searchController = TextEditingController();
    String searchQuery = '';

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Filter users based on search query
            final List<Map<String, dynamic>> filteredUsers = searchQuery.isEmpty
                ? allUsers
                : allUsers.where((user) =>
                    (user['name'] as String).toLowerCase().contains(searchQuery.toLowerCase())).toList();

            return WillPopScope(
              onWillPop: () async {
                searchController.dispose();
                return true;
              },
              child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people_outline, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Assign Users',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Select a user who will be assigned to this payment mode',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search bar
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search users...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  searchController.clear();
                                  setDialogState(() {
                                    searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // User list with checkboxes
                    if (filteredUsers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No users found',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else if (filteredUsers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No users found',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else
                      ...filteredUsers.map((user) {
                    final userId = user['id'] as String;
                    final userName = user['name'] as String;
                    final isSelected = selectedUserId == userId;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor.withOpacity(0.3)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: RadioListTile<String>(
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.grey.shade300,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                size: 16,
                                color: isSelected ? Colors.white : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                userName,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        value: userId,
                        groupValue: selectedUserId,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedUserId = value;
                            if (value != null) {
                              final user = allUsers.firstWhere(
                                (u) => u['id'] == value,
                                orElse: () => <String, dynamic>{
                                  'id': value!,
                                  'name': 'Unknown User',
                                },
                              );
                              selectedUserName = user['name'] as String;
                            }
                          });
                        },
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                searchController.dispose();
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedUserId?.isNotEmpty ?? false) {
                  final selectedUser = allUsers.firstWhere(
                    (u) => u['id'] == selectedUserId,
                    orElse: () => <String, dynamic>{
                      'id': selectedUserId!,
                      'name': 'Unknown User',
                    },
                  );
                  searchController.dispose();
                  onSave(selectedUserId, selectedUser['name'] as String); // Save user ID and name
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
              ),
            );
          },
        );
      },
    );
  }
}

// Dialog widget that properly manages TextEditingControllers
class _AddPaymentModeDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final Function(BuildContext, String?, Function(String?, String?)) showUserAssignmentDialog;

  const _AddPaymentModeDialog({
    required this.onSave,
    required this.showUserAssignmentDialog,
  });

  @override
  State<_AddPaymentModeDialog> createState() => _AddPaymentModeDialogState();
}

class _AddPaymentModeDialogState extends State<_AddPaymentModeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _upiIdCtrl;
  
  String _modeType = 'UPI';
  List<String> _display = ['Collection'];
  bool _autoTransactionCreation = false;
  String? _assignedUserId; // Store user ID for backend
  String? _assignedUserName; // Store user name for display
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _upiIdCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _upiIdCtrl.dispose();
    super.dispose();
  }

  void _showUserAssignmentDialog(Function(String?, String?) onSave) {
    if (!mounted) return;
    widget.showUserAssignmentDialog(context, _assignedUserId, (userId, userName) {
      if (mounted) {
        setState(() {
          _assignedUserId = userId;
          _assignedUserName = userName;
        });
      }
      onSave(userId, userName);
    });
  }

  @override
  Widget build(BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.payment, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  'Add Payment Mode',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Payment Mode
                      TextFormField(
                        controller: _nameCtrl,
                        maxLength: 50,
                        decoration: InputDecoration(
                          labelText: 'Payment Mode',
                          prefixIcon: const Icon(Icons.label_outline, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          counterText: '',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      // 2. Description
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 2,
                        maxLength: 100,
                        decoration: InputDecoration(
                          labelText: 'Description (optional)',
                          prefixIcon: const Icon(Icons.description_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: Colors.grey.shade200, height: 1, thickness: 1),
                      const SizedBox(height: 16),
                      // 3. Payment Method (Cash/UPI/Bank)
                      DropdownButtonFormField<String>(
                        value: _modeType,
                        decoration: InputDecoration(
                          labelText: 'Payment Method',
                          prefixIcon: const Icon(Icons.category_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                          DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                        ],
                        onChanged: (v) => setState(() => _modeType = v ?? 'UPI'),
                      ),
                      if (_modeType == 'UPI') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _upiIdCtrl,
                          decoration: InputDecoration(
                            labelText: 'UPI ID',
                            hintText: 'e.g., yourname@bank',
                            prefixIcon: const Icon(Icons.qr_code, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Display',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDisplayButtonWidget(
                                  label: 'Collection',
                                  isSelected: _display.contains('Collection'),
                                  onTap: () {
                                    setState(() {
                                      if (_display.contains('Collection')) {
                                        _display.remove('Collection');
                                      } else {
                                        _display.add('Collection');
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDisplayButtonWidget(
                                  label: 'Transaction',
                                  isSelected: _display.contains('Transaction'),
                                  onTap: () {
                                    setState(() {
                                      if (_display.contains('Transaction')) {
                                        _display.remove('Transaction');
                                      } else {
                                        _display.add('Transaction');
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDisplayButtonWidget(
                                  label: 'Expenses',
                                  isSelected: _display.contains('Expenses'),
                                  onTap: () {
                                    setState(() {
                                      if (_display.contains('Expenses')) {
                                        _display.remove('Expenses');
                                      } else {
                                        _display.add('Expenses');
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActiveToggleButtonWidget(
                                  isActive: _isActive,
                                  onTap: () => setState(() => _isActive = !_isActive),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: Colors.grey.shade200, height: 1, thickness: 1),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.sync_alt, size: 18, color: AppTheme.primaryColor.withOpacity(0.7)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Auto Transaction Creation for Collection',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Contact the admin',
                                child: Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: AppTheme.primaryColor.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () async {
                                        setState(() {
                                          _autoTransactionCreation = true;
                                        });
                                        // Show user selection dialog immediately
                                        _showUserAssignmentDialog((userId, userName) {
                                          setState(() {
                                            _assignedUserId = userId;
                                            _assignedUserName = userName;
                                          });
                                        });
                                      },
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(10),
                                        bottomLeft: Radius.circular(10),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                                        decoration: BoxDecoration(
                                          color: _autoTransactionCreation
                                              ? AppTheme.primaryColor
                                              : Colors.transparent,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(10),
                                            bottomLeft: Radius.circular(10),
                                          ),
                                        ),
                                        child: Text(
                                          'Yes',
                                          style: TextStyle(
                                            color: _autoTransactionCreation
                                                ? Colors.white
                                                : AppTheme.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => setState(() {
                                        _autoTransactionCreation = false;
                                        _assignedUserId = null;
                                        _assignedUserName = null;
                                      }),
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(10),
                                        bottomRight: Radius.circular(10),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                                        decoration: BoxDecoration(
                                          color: !_autoTransactionCreation
                                              ? AppTheme.primaryColor
                                              : Colors.transparent,
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(10),
                                            bottomRight: Radius.circular(10),
                                          ),
                                        ),
                                        child: Text(
                                          'No',
                                          style: TextStyle(
                                            color: !_autoTransactionCreation
                                                ? Colors.white
                                                : AppTheme.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      if (_autoTransactionCreation && _assignedUserId != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person_outline, size: 16, color: AppTheme.primaryColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Assigned User',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Chip(
                                label: Text(_assignedUserName ?? 'Unknown User', style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  _showUserAssignmentDialog((userId, userName) {
                                    setState(() {
                                      _assignedUserId = userId;
                                      _assignedUserName = userName;
                                    });
                                  });
                                },
                                icon: const Icon(Icons.edit, size: 14),
                                label: const Text('Edit User', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final newMode = {
              'name': _nameCtrl.text.trim(),
              'description': _descCtrl.text.trim(),
              'mode': _modeType,
              'display': List<String>.from(_display),
              'autoTransactionCreation': _autoTransactionCreation,
              'assignedUser': _assignedUserName, // For display
              'assignedReceiver': _assignedUserId, // For backend - send ID
              'isActive': _isActive,
            };
            if (_modeType == 'UPI' && _upiIdCtrl.text.trim().isNotEmpty) {
              newMode['upiId'] = _upiIdCtrl.text.trim();
            }
            widget.onSave(newMode);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildDisplayButtonWidget({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentBlue : AppTheme.accentBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.accentBlue : AppTheme.accentBlue.withOpacity(0.3),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.accentBlue.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.cancel_outlined,
                size: 18,
                color: isSelected ? Colors.white : AppTheme.accentBlue,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.accentBlue,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveToggleButtonWidget({
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final Color inactiveColor = const Color(0xFFFF6B6B).withOpacity(0.9);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.secondaryColor : inactiveColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? AppTheme.secondaryColor : inactiveColor,
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.secondaryColor.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: inactiveColor.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: Icon(
                  isActive ? Icons.check_circle : Icons.cancel_outlined,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isActive ? 'Active' : 'Inactive',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditPaymentModeDialog extends StatefulWidget {
  final Map<String, dynamic> mode;
  final Function(Map<String, dynamic>) onSave;
  final Function(BuildContext, String?, Function(String?, String?)) showUserAssignmentDialog;

  const _EditPaymentModeDialog({
    required this.mode,
    required this.onSave,
    required this.showUserAssignmentDialog,
  });

  @override
  State<_EditPaymentModeDialog> createState() => _EditPaymentModeDialogState();
}

class _EditPaymentModeDialogState extends State<_EditPaymentModeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _upiIdCtrl;
  
  late String _modeType;
  late List<String> _display;
  late bool _autoTransactionCreation;
  late String? _assignedUserId; // Store user ID for backend
  late String? _assignedUserName; // Store user name for display
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _modeType = widget.mode['mode'] as String? ?? 'UPI';
    final displayValue = widget.mode['display'];
    if (displayValue is List) {
      _display = List<String>.from(displayValue);
    } else if (displayValue is String) {
      _display = [displayValue];
    } else {
      _display = ['Collection'];
    }
    _autoTransactionCreation = widget.mode['autoTransactionCreation'] == true || widget.mode['autoPay'] == true;
    // Get assigned receiver - could be ID or name
    final assignedReceiver = widget.mode['assignedReceiver'];
    if (assignedReceiver is String && assignedReceiver.isNotEmpty) {
      _assignedUserId = assignedReceiver;
      _assignedUserName = widget.mode['assignedUser'] as String? ?? widget.mode['receiver'] as String?;
    } else {
      _assignedUserId = null;
      _assignedUserName = widget.mode['assignedUser'] as String? ?? widget.mode['receiver'] as String?;
    }
    _isActive = widget.mode['isActive'] != false;
    _nameCtrl = TextEditingController(text: widget.mode['name'] as String? ?? '');
    _descCtrl = TextEditingController(text: widget.mode['description'] as String? ?? '');
    _upiIdCtrl = TextEditingController(text: widget.mode['upiId'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _upiIdCtrl.dispose();
    super.dispose();
  }

  void _showUserAssignmentDialog(Function(String?, String?) onSave) {
    if (!mounted) return;
    widget.showUserAssignmentDialog(context, _assignedUserId, (userId, userName) {
      if (mounted) {
        setState(() {
          _assignedUserId = userId;
          _assignedUserName = userName;
        });
      }
      onSave(userId, userName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    
    return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20,
                vertical: isMobile ? 16 : 24,
              ),
              titlePadding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
                isMobile ? 8 : 8,
              ),
              contentPadding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                isMobile ? 4 : 4,
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
              ),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.payment,
                      color: AppTheme.primaryColor,
                      size: isMobile ? 18 : 20,
                    ),
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Flexible(
                    child: Text(
                      'Edit Payment Mode',
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: isMobile ? MediaQuery.of(context).size.width - 24 : 480,
                child: Form(
                  key: _formKey,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.85 : 0.75),
                    ),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Payment Mode
                          TextFormField(
                            controller: _nameCtrl,
                            maxLength: 50,
                            style: TextStyle(fontSize: isMobile ? 14 : 16),
                            decoration: InputDecoration(
                              labelText: 'Payment Mode',
                              labelStyle: TextStyle(fontSize: isMobile ? 14 : 16),
                              prefixIcon: Icon(Icons.label_outline, size: isMobile ? 18 : 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 16,
                                vertical: isMobile ? 12 : 16,
                              ),
                              counterText: '',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                          SizedBox(height: isMobile ? 12 : 16),
                          // 2. Description
                          TextFormField(
                            controller: _descCtrl,
                            maxLines: 2,
                            maxLength: 100,
                            style: TextStyle(fontSize: isMobile ? 14 : 16),
                            decoration: InputDecoration(
                              labelText: 'Description (optional)',
                              labelStyle: TextStyle(fontSize: isMobile ? 14 : 16),
                              prefixIcon: Icon(Icons.description_outlined, size: isMobile ? 18 : 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 16,
                                vertical: isMobile ? 12 : 16,
                              ),
                              counterText: '',
                            ),
                          ),
                          SizedBox(height: isMobile ? 12 : 16),
                          // Divider
                          Divider(color: Colors.grey.shade200, height: 1, thickness: 1),
                          SizedBox(height: isMobile ? 12 : 16),
                          // 3. Payment Method (Cash/UPI/Bank)
                          DropdownButtonFormField<String>(
                            value: _modeType,
                            style: TextStyle(fontSize: isMobile ? 14 : 16),
                            decoration: InputDecoration(
                              labelText: 'Payment Method',
                              labelStyle: TextStyle(fontSize: isMobile ? 14 : 16),
                              prefixIcon: Icon(Icons.category_outlined, size: isMobile ? 18 : 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 16,
                                vertical: isMobile ? 12 : 16,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                              DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                              DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                            ],
                            onChanged: (v) => setState(() => _modeType = v ?? 'UPI'),
                          ),
                          // Show UPI ID field if UPI is selected
                          if (_modeType == 'UPI') ...[
                            SizedBox(height: isMobile ? 12 : 16),
                            TextFormField(
                              controller: _upiIdCtrl,
                              style: TextStyle(fontSize: isMobile ? 14 : 16),
                              decoration: InputDecoration(
                                labelText: 'UPI ID',
                                labelStyle: TextStyle(fontSize: isMobile ? 14 : 16),
                                hintText: 'e.g., yourname@bank',
                                hintStyle: TextStyle(fontSize: isMobile ? 13 : 14),
                                prefixIcon: Icon(Icons.qr_code, size: isMobile ? 18 : 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 12 : 16,
                                  vertical: isMobile ? 12 : 16,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          // 4. Display (Collection/Expenses/Transaction) and Active - Button Layout
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Display',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: isMobile ? 10 : 12),
                              // Row 1: Collection and Transaction
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDisplayButtonWidget(
                                      label: 'Collection',
                                      isSelected: _display.contains('Collection'),
                                      onTap: () {
                                        setState(() {
                                          if (_display.contains('Collection')) {
                                            _display.remove('Collection');
                                          } else {
                                            _display.add('Collection');
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(width: isMobile ? 8 : 12),
                                  Expanded(
                                    child: _buildDisplayButtonWidget(
                                      label: 'Transaction',
                                      isSelected: _display.contains('Transaction'),
                                      onTap: () {
                                        setState(() {
                                          if (_display.contains('Transaction')) {
                                            _display.remove('Transaction');
                                          } else {
                                            _display.add('Transaction');
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isMobile ? 10 : 12),
                              // Row 2: Expenses and Active
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDisplayButtonWidget(
                                      label: 'Expenses',
                                      isSelected: _display.contains('Expenses'),
                                      onTap: () {
                                        setState(() {
                                          if (_display.contains('Expenses')) {
                                            _display.remove('Expenses');
                                          } else {
                                            _display.add('Expenses');
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(width: isMobile ? 8 : 12),
                                  Expanded(
                                    child: _buildActiveToggleButtonWidget(
                                      isActive: _isActive,
                                      onTap: () {
                                        setState(() {
                                          _isActive = !_isActive;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: isMobile ? 12 : 16),
                          // Divider
                          Divider(color: Colors.grey.shade200, height: 1, thickness: 1),
                          SizedBox(height: isMobile ? 12 : 16),
                          // 5. Auto Transaction Creation for Collection
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isMobile)
                                // Mobile: Stack vertically
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.sync_alt,
                                              size: 16,
                                              color: AppTheme.primaryColor.withOpacity(0.7),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Auto Transaction Creation',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                            ),
                                            Tooltip(
                                              message: 'Contact the admin',
                                              child: Icon(
                                                Icons.info_outline,
                                                size: 14,
                                                color: AppTheme.primaryColor.withOpacity(0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Toggle buttons for mobile
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.grey.shade300, width: 1),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _autoTransactionCreation = true;
                                                    });
                                                    Future.delayed(const Duration(milliseconds: 100), () {
                                                      _showUserAssignmentDialog((userId, userName) {
                                                        setState(() {
                                                          _assignedUserId = userId;
                                                          _assignedUserName = userName;
                                                        });
                                                      });
                                                    });
                                                  },
                                                  borderRadius: const BorderRadius.only(
                                                    topLeft: Radius.circular(10),
                                                    bottomLeft: Radius.circular(10),
                                                  ),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                                    decoration: BoxDecoration(
                                                      color: _autoTransactionCreation
                                                          ? AppTheme.primaryColor
                                                          : Colors.transparent,
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(10),
                                                        bottomLeft: Radius.circular(10),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'Yes',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        color: _autoTransactionCreation
                                                            ? Colors.white
                                                            : AppTheme.textPrimary,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () => setState(() {
                                                    _autoTransactionCreation = false;
                                                    _assignedUserId = null;
                                                    _assignedUserName = null;
                                                  }),
                                                  borderRadius: const BorderRadius.only(
                                                    topRight: Radius.circular(10),
                                                    bottomRight: Radius.circular(10),
                                                  ),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                                    decoration: BoxDecoration(
                                                      color: !_autoTransactionCreation
                                                          ? AppTheme.primaryColor
                                                          : Colors.transparent,
                                                      borderRadius: const BorderRadius.only(
                                                        topRight: Radius.circular(10),
                                                        bottomRight: Radius.circular(10),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'No',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        color: !_autoTransactionCreation
                                                            ? Colors.white
                                                            : AppTheme.textPrimary,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                  ],
                                ),
                              if (!isMobile)
                                // Desktop: Keep horizontal layout
                                Row(
                                  children: [
                                        Icon(
                                          Icons.sync_alt,
                                          size: 18,
                                          color: AppTheme.primaryColor.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Auto Transaction Creation for Collection',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Tooltip(
                                          message: 'Contact the admin',
                                          child: Icon(
                                            Icons.info_outline,
                                            size: 16,
                                            color: AppTheme.primaryColor.withOpacity(0.7),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.grey.shade300, width: 1),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _autoTransactionCreation = true;
                                                  });
                                                  Future.delayed(const Duration(milliseconds: 100), () {
                                                    _showUserAssignmentDialog((userId, userName) {
                                                      setState(() {
                                                        _assignedUserId = userId;
                                                        _assignedUserName = userName;
                                                      });
                                                    });
                                                  });
                                                },
                                                borderRadius: const BorderRadius.only(
                                                  topLeft: Radius.circular(10),
                                                  bottomLeft: Radius.circular(10),
                                                ),
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: isMobile ? 16 : 24,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _autoTransactionCreation
                                                        ? AppTheme.primaryColor
                                                        : Colors.transparent,
                                                    borderRadius: const BorderRadius.only(
                                                      topLeft: Radius.circular(10),
                                                      bottomLeft: Radius.circular(10),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Yes',
                                                    style: TextStyle(
                                                      color: _autoTransactionCreation
                                                          ? Colors.white
                                                          : AppTheme.textPrimary,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: isMobile ? 12 : 13,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () => setState(() {
                                                  _autoTransactionCreation = false;
                                                  _assignedUserId = null;
                                                  _assignedUserName = null;
                                                }),
                                                borderRadius: const BorderRadius.only(
                                                  topRight: Radius.circular(10),
                                                  bottomRight: Radius.circular(10),
                                                ),
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: isMobile ? 16 : 24,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: !_autoTransactionCreation
                                                        ? AppTheme.primaryColor
                                                        : Colors.transparent,
                                                    borderRadius: const BorderRadius.only(
                                                      topRight: Radius.circular(10),
                                                      bottomRight: Radius.circular(10),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'No',
                                                    style: TextStyle(
                                                      color: !_autoTransactionCreation
                                                          ? Colors.white
                                                          : AppTheme.textPrimary,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: isMobile ? 12 : 13,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                  ],
                                ),
                              // Assigned user info (shown when auto transaction creation is enabled)
                              if (_autoTransactionCreation && _assignedUserId != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.person_outline, size: 16, color: AppTheme.primaryColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Assigned User',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Chip(
                                        label: Text(_assignedUserName ?? 'Unknown User', style: const TextStyle(fontSize: 11)),
                                        backgroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        onPressed: () {
                                          _showUserAssignmentDialog((userId, userName) {
                                            setState(() {
                                              _assignedUserId = userId;
                                              _assignedUserName = userName;
                                            });
                                          });
                                        },
                                        icon: const Icon(Icons.edit, size: 14),
                                        label: const Text('Edit User', style: TextStyle(fontSize: 12)),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: isMobile
                  ? [
                      // Mobile: Stack buttons vertically
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                if (!_formKey.currentState!.validate()) return;
                                final updatedMode = {
                                  'name': _nameCtrl.text.trim(),
                                  'description': _descCtrl.text.trim(),
                                  'mode': _modeType,
                                  'display': List<String>.from(_display),
                                  'autoTransactionCreation': _autoTransactionCreation,
                                  'assignedUser': _assignedUserName, // For display
                                  'assignedReceiver': _assignedUserId, // For backend - send ID
                                  'isActive': _isActive,
                                };
                                if (_modeType == 'UPI' && _upiIdCtrl.text.trim().isNotEmpty) {
                                  updatedMode['upiId'] = _upiIdCtrl.text.trim();
                                }
                                widget.onSave(updatedMode);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ]
                  : [
                      // Desktop: Keep horizontal layout
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;
                          final updatedMode = {
                            'name': _nameCtrl.text.trim(),
                            'description': _descCtrl.text.trim(),
                            'mode': _modeType,
                            'display': List<String>.from(_display),
                            'autoTransactionCreation': _autoTransactionCreation,
                            'assignedUser': _assignedUserName, // For display
                            'assignedReceiver': _assignedUserId, // For backend - send ID
                            'isActive': _isActive,
                          };
                          if (_modeType == 'UPI' && _upiIdCtrl.text.trim().isNotEmpty) {
                            updatedMode['upiId'] = _upiIdCtrl.text.trim();
                          }
                          widget.onSave(updatedMode);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  );
  }

  Widget _buildDisplayButtonWidget({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentBlue : AppTheme.accentBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.accentBlue : AppTheme.accentBlue.withOpacity(0.3),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.accentBlue.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.cancel_outlined,
                size: 18,
                color: isSelected ? Colors.white : AppTheme.accentBlue,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.accentBlue,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveToggleButtonWidget({
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final Color inactiveColor = const Color(0xFFFF6B6B).withOpacity(0.9);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.secondaryColor : inactiveColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? AppTheme.secondaryColor : inactiveColor,
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.secondaryColor.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: inactiveColor.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: Icon(
                  isActive ? Icons.check_circle : Icons.cancel_outlined,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isActive ? 'Active' : 'Inactive',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Display Multi-Select Dialog
class _DisplayMultiSelectDialog extends StatefulWidget {
  const _DisplayMultiSelectDialog({
    required this.selectedOptions,
    required this.options,
    required this.onSave,
  });

  final List<String> selectedOptions;
  final List<String> options;
  final Function(List<String>) onSave;

  @override
  State<_DisplayMultiSelectDialog> createState() => _DisplayMultiSelectDialogState();
}

class _DisplayMultiSelectDialogState extends State<_DisplayMultiSelectDialog> {
  late List<String> _selectedOptions;

  @override
  void initState() {
    super.initState();
    _selectedOptions = List<String>.from(widget.selectedOptions);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Display'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.options.map((option) {
            final isSelected = _selectedOptions.contains(option);
            return CheckboxListTile(
              title: Text(option),
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedOptions.add(option);
                  } else {
                    _selectedOptions.remove(option);
                  }
                });
              },
              activeColor: AppTheme.primaryColor,
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_selectedOptions);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// PaymentModeCard widget matching wallet card style
class PaymentModeCard extends StatelessWidget {
  const PaymentModeCard({
    super.key,
    required this.modeName,
    required this.description,
    required this.modeType,
    required this.receiver,
    required this.autoPay,
    required this.isActive,
    this.modeId,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
  });

  final String modeName;
  final String description;
  final String modeType;
  final String receiver;
  final bool autoPay;
  final bool isActive;
  final String? modeId;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(String?, bool)? onToggleActive;

  static const double _cardHeight = 190;
  static const double _avatarBaseSize = 72;
  static const double _avatarCompactFactor = 0.88;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardRadius = BorderRadius.circular(14);
    final initials = _computeInitials(modeName);
    // Show inactive if isActive is false
    final bool isActiveStatus = isActive;
    final Color bannerColor = isActiveStatus ? AppTheme.secondaryColor : Colors.grey.shade600;
    final String bannerMessage = isActiveStatus ? 'ACTIVE' : 'INACTIVE';
    final Color cardBackgroundColor = isActiveStatus ? Colors.white : Colors.grey.shade100;
    final Color cardBorderColor = isActiveStatus 
        ? AppTheme.borderColor.withValues(alpha: 0.3)
        : Colors.grey.shade300;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: cardRadius,
        onTap: onEdit,
        child: Container(
          margin: EdgeInsets.zero,
          constraints: const BoxConstraints(minHeight: _cardHeight),
          decoration: BoxDecoration(
            color: cardBackgroundColor,
            borderRadius: cardRadius,
            border: Border.all(
              color: cardBorderColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isActiveStatus ? 0.04 : 0.02),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: cardRadius,
            child: Stack(
              children: [
                Banner(
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
                  final bool isCompactLayout = constraints.maxWidth <= 288;
                  final EdgeInsets contentPadding = isCompactLayout
                      ? const EdgeInsets.fromLTRB(14, 16, 14, 8)
                      : const EdgeInsets.fromLTRB(16, 18, 16, 10);
                  final Widget content = isCompactLayout
                      ? _buildCompactContent(
                          theme: theme,
                          initials: initials,
                          isActiveStatus: isActiveStatus,
                        )
                      : _buildStandardContent(
                          theme: theme,
                          initials: initials,
                          isActiveStatus: isActiveStatus,
                        );

                    return Padding(
                      padding: contentPadding,
                      child: content,
                    );
                  },
                ),
                ), // Close Banner widget
                // Clickable banner overlay to toggle active status
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      if (onToggleActive != null && modeId != null) {
                        onToggleActive!(modeId, !isActive);
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandardContent({
    required ThemeData theme,
    required String initials,
    required bool isActiveStatus,
  }) {
    return _buildCardContent(
      theme: theme,
      initials: initials,
      compact: false,
      isActiveStatus: isActiveStatus,
    );
  }

  Widget _buildCompactContent({
    required ThemeData theme,
    required String initials,
    required bool isActiveStatus,
  }) {
    return _buildCardContent(
      theme: theme,
      initials: initials,
      compact: true,
      isActiveStatus: isActiveStatus,
    );
  }

  Widget _buildCardContent({
    required ThemeData theme,
    required String initials,
    bool compact = false,
    required bool isActiveStatus,
  }) {
    final double avatarSize = compact
        ? _avatarBaseSize * _avatarCompactFactor
        : _avatarBaseSize;
    final double nameFontSize = compact ? 16 : 18;
    final double descFontSize = compact ? 12 : 13;
    final double headerSpacing = compact ? 10 : 12;
    
    // Adjust colors based on active status
    final Color nameColor = isActiveStatus 
        ? AppTheme.textPrimary 
        : Colors.grey.shade600;
    final Color descColor = isActiveStatus 
        ? AppTheme.textSecondary 
        : Colors.grey.shade500;
    final Color iconColor = isActiveStatus 
        ? AppTheme.primaryColor 
        : Colors.grey.shade500;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildAvatar(initials, size: avatarSize, isActiveStatus: isActiveStatus),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modeName,
                    style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.w700,
                          color: nameColor,
                        ) ??
                        TextStyle(
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.w700,
                          color: nameColor,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: descFontSize,
                          color: descColor,
                        ) ??
                        TextStyle(
                          fontSize: descFontSize,
                          color: descColor,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  Row(
                    children: [
                      _buildModeTypeChip(theme, modeType, compact: compact, isActiveStatus: isActiveStatus),
                      const Spacer(),
                      if (onEdit != null)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: onEdit,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.edit_outlined,
                                size: compact ? 18 : 20,
                                color: iconColor,
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
        SizedBox(height: headerSpacing + (compact ? 6 : 8)),
        _buildMetricsRow(
          theme: theme,
          compact: compact,
        ),
      ],
    );
  }

  Widget _buildMetricsRow({
    required ThemeData theme,
    bool compact = false,
  }) {
    final EdgeInsets padding = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 14);

    // Determine colors based on autoPay status
    final bool isInactive = !autoPay;
    final Color boxColor = isInactive ? Colors.grey.shade100 : Colors.white;
    final Color borderColor = isInactive 
        ? Colors.grey.shade300 
        : const Color(0xFF1F9D4D); // Green border when auto pay is enabled
    final Color textColor = isInactive 
        ? Colors.grey.shade600 
        : AppTheme.textPrimary;
    final Color iconBgColor = isInactive 
        ? Colors.grey.shade200 
        : AppTheme.primaryColor.withOpacity(0.12);
    final Color iconColor = isInactive 
        ? Colors.grey.shade600 
        : AppTheme.primaryColor;
    final Color statusColor = autoPay
        ? const Color(0xFF1F9D4D)
        : Colors.grey.shade600;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isInactive ? Colors.grey.shade300 : const Color(0xFF1F9D4D),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 20,
                  color: isInactive ? Colors.grey.shade600 : AppTheme.primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isInactive ? 'Auto Pay is disabled' : receiver,
                    style: AppTheme.bodyMedium.copyWith(
                      color: isInactive ? Colors.grey.shade600 : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -10,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              color: Colors.white,
              child: Text(
                'Auto Pay Receiver',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildModeTypeChip(ThemeData theme, String modeType, {bool compact = false, bool isActiveStatus = true}) {
    final EdgeInsets padding = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    final double fontSize = compact ? 10 : 11;
    
    final Color chipBgColor = isActiveStatus 
        ? AppTheme.primaryColor.withValues(alpha: 0.08)
        : Colors.grey.shade200;
    final Color chipTextColor = isActiveStatus 
        ? AppTheme.primaryColor
        : Colors.grey.shade600;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: chipBgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        modeType,
        style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: chipTextColor,
            ) ??
            TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: chipTextColor,
            ),
      ),
    );
  }


  Widget _buildAvatar(String initials, {double size = 56, bool isActiveStatus = true}) {
    final double expandedSize = size + 2; // 1px on each side = 2px total
    final BorderRadius borderRadius = BorderRadius.circular(expandedSize * 0.28);
    
    final BoxDecoration decoration = isActiveStatus
        ? const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          )
        : BoxDecoration(
            color: Colors.grey.shade400,
          );
    
    final TextStyle textStyle = TextStyle(
      color: Colors.white,
      fontSize: expandedSize * 0.36,
      fontWeight: FontWeight.w700,
    );

    return Container(
      width: expandedSize,
      height: expandedSize,
      decoration: decoration.copyWith(borderRadius: borderRadius),
      alignment: Alignment.center,
      child: Text(initials, style: textStyle),
    );
  }

  String _computeInitials(String name) {
    if (name.trim().isEmpty) return 'PM';
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

