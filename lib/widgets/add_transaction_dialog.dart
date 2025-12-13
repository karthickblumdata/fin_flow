import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../services/transaction_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/payment_mode_service.dart';
import '../utils/wallet_helper.dart';

class AddTransactionDialog extends StatefulWidget {
  final String? preSelectedReceiverId;
  final String? preSelectedReceiverName;
  final VoidCallback? onSuccess;
  // Edit mode parameters
  final String? transactionId;
  final Map<String, dynamic>? existingData;

  const AddTransactionDialog({
    super.key,
    this.preSelectedReceiverId,
    this.preSelectedReceiverName,
    this.onSuccess,
    this.transactionId,
    this.existingData,
  });

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  
  String? _selectedReceiverId;
  String? _selectedReceiverName;
  String? _selectedReceiverDisplay;
  String? _selectedMode; // Will be derived from selected PaymentMode
  bool _isLoading = false;
  bool _isLoadingUsers = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  String? _currentUserId;
  bool _showUserList = false;
  
  List<Map<String, dynamic>> _paymentModes = [];
  String? _selectedPaymentModeId;
  bool _isLoadingPaymentModes = false;

  @override
  void initState() {
    super.initState();
    
    // Load existing data if in edit mode
    if (widget.transactionId != null && widget.existingData != null) {
      final data = widget.existingData!;
      final raw = data['raw'] is Map ? Map<String, dynamic>.from(data['raw'] as Map) : <String, dynamic>{};
      
      // Pre-fill controllers with existing data
      _amountController.text = data['amountValue'] is num ? (data['amountValue'] as num).toString() : '';
      _notesController.text = raw['purpose']?.toString() ?? data['purpose']?.toString() ?? '';
      
      // Set receiver if available
      final receiverId = data['toId']?.toString();
      final receiverName = data['to']?.toString();
      if (receiverId != null && receiverName != null) {
        _selectedReceiverId = receiverId;
        _selectedReceiverName = receiverName;
        _selectedReceiverDisplay = receiverName;
        _searchController.text = receiverName;
      }
      
      // Set payment mode ID if available
      final paymentMode = raw['paymentModeId'] ?? raw['paymentMode'];
      if (paymentMode is Map) {
        _selectedPaymentModeId = (paymentMode['_id'] ?? paymentMode['id'])?.toString();
      } else if (paymentMode is String) {
        _selectedPaymentModeId = paymentMode;
      }
    } else if (widget.preSelectedReceiverId != null && widget.preSelectedReceiverName != null) {
      // Pre-select receiver if provided
      _selectedReceiverId = widget.preSelectedReceiverId;
      _selectedReceiverName = widget.preSelectedReceiverName;
      _selectedReceiverDisplay = widget.preSelectedReceiverName;
      _searchController.text = widget.preSelectedReceiverName!;
    }
    
    _loadCurrentUserId();
    _loadUsers();
    _loadPaymentModes();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await AuthService.getUserId();
    setState(() {
      _currentUserId = userId;
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    try {
      final result = await UserService.getUsers();
      if (result['success'] == true && mounted) {
        final users = result['users'] as List<dynamic>? ?? [];
        // Filter for active users only (isVerified == true) and exclude current user
        final filteredUsers = users.where((u) {
          final userId = u['_id'] ?? u['id'] ?? '';
          final isVerified = u['isVerified'] ?? false;
          return userId != _currentUserId && isVerified == true;
        }).toList();
        
        // Filter out non-wallet users (only show users with wallets for transactions)
        final usersWithWallets = await WalletHelper.filterUsersWithWallets(
          filteredUsers.map((u) {
            final name = _extractUserName(u);
            final display = _composeDisplayLabel(u);
            return {
              'id': u['_id'] ?? u['id'] ?? '',
              'name': name,
              'display': display,
              'email': u['email'] ?? '',
              'role': u['role'] ?? '',
              'isVerified': u['isVerified'] ?? false,
            };
          }).toList(),
        );
        
        setState(() {
          _users = usersWithWallets;
          _filteredUsers = _users;
          _isLoadingUsers = false;
        });
        
        // Set pre-selected receiver if provided
        if (widget.preSelectedReceiverId != null && widget.preSelectedReceiverId!.isNotEmpty) {
          try {
            final preSelectedUser = _users.firstWhere(
              (u) => u['id'] == widget.preSelectedReceiverId,
            );
            if (mounted) {
              setState(() {
                _selectedReceiverId = preSelectedUser['id'];
                _selectedReceiverName = preSelectedUser['name'];
                _selectedReceiverDisplay = preSelectedUser['display'];
                _searchController.text = preSelectedUser['display'] as String? ?? preSelectedUser['name'] as String;
              });
            }
          } catch (e) {
            // User not found in list, use provided name if available
            if (widget.preSelectedReceiverName != null && mounted) {
              setState(() {
                _selectedReceiverId = widget.preSelectedReceiverId;
                _selectedReceiverName = widget.preSelectedReceiverName;
                _selectedReceiverDisplay = widget.preSelectedReceiverName;
                _searchController.text = widget.preSelectedReceiverName!;
              });
            }
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingUsers = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    }
  }

  Future<void> _loadPaymentModes() async {
    print('🔍 [AddTransactionDialog] _loadPaymentModes() called');
    setState(() {
      _isLoadingPaymentModes = true;
    });

    try {
      print('🔍 [AddTransactionDialog] Calling getPaymentModes with displayType: Transaction');
      final result = await PaymentModeService.getPaymentModes(displayType: 'Transaction');
      print('🔍 [AddTransactionDialog] getPaymentModes response: success=${result['success']}, count=${result['paymentModes']?.length ?? 0}');
      if (result['success'] == true && mounted) {
        final paymentModes = result['paymentModes'] as List<dynamic>? ?? [];
        setState(() {
          _paymentModes = paymentModes
              .where((pm) => pm['isActive'] == true)
              .map((pm) => Map<String, dynamic>.from(pm))
              .toList();
          
          // In edit mode, preserve the selected payment mode if already set
          if (widget.transactionId != null && _selectedPaymentModeId != null) {
            // Find the matching payment mode and set the mode
            final selectedPM = _paymentModes.firstWhere(
              (pm) => (pm['_id']?.toString() ?? pm['id']?.toString()) == _selectedPaymentModeId,
              orElse: () => {},
            );
            if (selectedPM.isNotEmpty) {
              final description = selectedPM['description']?.toString() ?? '';
              final parsed = PaymentModeService.parseDescription(description);
              _selectedMode = parsed['mode']?.toString() ?? 'Cash';
            }
          } else {
            // Set default selected payment mode to first available (only if not in edit mode)
            if (_paymentModes.isNotEmpty) {
            final firstPM = _paymentModes.first;
            // Try multiple ways to get the ID
            final pmId = firstPM['_id']?.toString()?.trim() ?? 
                        firstPM['id']?.toString()?.trim() ??
                        firstPM['_id']?.toString() ??
                        firstPM['id']?.toString();
            
            if (pmId != null && pmId.isNotEmpty) {
              _selectedPaymentModeId = pmId;
              // Derive mode from selected PaymentMode description
              final description = firstPM['description']?.toString() ?? '';
              final parsed = PaymentModeService.parseDescription(description);
              _selectedMode = parsed['mode']?.toString() ?? 'Cash';
              print('🔍 [AddTransactionDialog] Auto-selected payment mode: ID=${_selectedPaymentModeId}, Mode=${_selectedMode}');
            } else {
              print('⚠️ [AddTransactionDialog] Failed to extract payment mode ID from first payment mode');
              print('   Payment mode data: ${firstPM.keys.toList()}');
              print('   _id: ${firstPM['_id']}, id: ${firstPM['id']}');
            }
          }
          }
          
          _isLoadingPaymentModes = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _paymentModes = [];
            _isLoadingPaymentModes = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _paymentModes = [];
          _isLoadingPaymentModes = false;
        });
      }
    }
  }

  String _extractUserName(dynamic rawUser) {
    final Map<String, dynamic> user = rawUser is Map ? Map<String, dynamic>.from(rawUser as Map) : {};
    for (final key in ['name', 'username', 'fullName', 'email']) {
      final value = user[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return 'Unknown User';
  }

  String? _extractUserRole(dynamic rawUser) {
    final Map<String, dynamic> user = rawUser is Map ? Map<String, dynamic>.from(rawUser as Map) : {};
    for (final key in ['role', 'userRole', 'user_role', 'designation', 'department']) {
      final value = user[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  String _composeDisplayLabel(dynamic rawUser) {
    final role = _extractUserRole(rawUser);
    final name = _extractUserName(rawUser);
    if (role != null && role.isNotEmpty) {
      return '$role - $name';
    }
    return name;
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
        _showUserList = false;
      } else {
        _filteredUsers = _users.where((user) {
          final name = (user['name'] ?? '').toString().toLowerCase();
          final email = (user['email'] ?? '').toString().toLowerCase();
          final display = (user['display'] ?? '').toString().toLowerCase();
          final searchQuery = query.toLowerCase();
          return name.contains(searchQuery) || 
                 email.contains(searchQuery) || 
                 display.contains(searchQuery);
        }).toList();
        _showUserList = true;
      }
    });
  }

  void _selectUser(Map<String, dynamic> user) {
    setState(() {
      _selectedReceiverId = user['id'] as String;
      _selectedReceiverName = user['name'] as String;
      _selectedReceiverDisplay = user['display'] as String? ?? _selectedReceiverName;
      _searchController.text = user['display'] as String? ?? user['name'] as String;
      _showUserList = false;
    });
  }

  Future<void> _handleTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get current user. Please login again.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedReceiverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a receiver'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_currentUserId == _selectedReceiverId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot transfer to yourself'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      final purpose = _notesController.text.trim();
      
      if (_selectedMode == null || _selectedPaymentModeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a payment mode'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Debug: Verify paymentModeId before sending
      print('🔍 [AddTransactionDialog] Creating transaction with:');
      print('   sender: $_currentUserId');
      print('   receiver: $_selectedReceiverId');
      print('   amount: $amount');
      print('   mode: $_selectedMode');
      print('   paymentModeId: $_selectedPaymentModeId');
      print('   paymentModeId type: ${_selectedPaymentModeId.runtimeType}');
      print('   paymentModeId isEmpty: ${_selectedPaymentModeId?.isEmpty ?? true}');
      
      final result = widget.transactionId != null
          ? await TransactionService.editTransaction(
              widget.transactionId!,
              amount: amount,
              mode: _selectedMode!,
              purpose: purpose.isEmpty ? null : purpose,
            )
          : await TransactionService.createTransaction(
              sender: _currentUserId!,
              receiver: _selectedReceiverId!,
              amount: amount,
              mode: _selectedMode!,
              purpose: purpose.isEmpty ? null : purpose,
              paymentModeId: _selectedPaymentModeId,
            );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? (widget.transactionId != null ? 'Transaction updated successfully' : '₹${_amountController.text} transferred to $_selectedReceiverName successfully')),
              backgroundColor: AppTheme.secondaryColor,
              duration: const Duration(seconds: 3),
            ),
          );

          widget.onSuccess?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to transfer amount'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: isMobile ? double.infinity : (isTablet ? 600 : 700),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          minHeight: 400,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.swap_horiz,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.transactionId != null ? 'Edit Transaction' : 'Add Transaction',
                        style: AppTheme.headingMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // User name (current user - Super Admin)
                    FutureBuilder<String?>(
                      future: AuthService.getUserName(),
                      builder: (context, snapshot) {
                        final userName = snapshot.data ?? 'Super Admin';
                        return Row(
                          children: [
                            const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // Close button
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      tooltip: 'Close',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Form Content
              Flexible(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showUserList = false;
                    });
                  },
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      // Transfer To field
                      Text('Transfer To', style: AppTheme.labelMedium),
                      const SizedBox(height: 8),
                      if (_isLoadingUsers)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        Stack(
                          children: [
                            TextFormField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Transfer To',
                                prefixIcon: const Icon(Icons.person_outline),
                                suffixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: isMobile ? 16 : 14,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: isMobile ? 16 : 15,
                              ),
                              onChanged: _filterUsers,
                              onTap: () {
                                if (_searchController.text.isEmpty) {
                                  setState(() {
                                    _filteredUsers = _users;
                                    _showUserList = true;
                                  });
                                }
                              },
                              validator: (value) {
                                if (_selectedReceiverId == null || _selectedReceiverId!.isEmpty) {
                                  return 'Please select a receiver';
                                }
                                return null;
                              },
                            ),
                            if (_showUserList && _filteredUsers.isNotEmpty)
                              Positioned(
                                top: 60,
                                left: 0,
                                right: 0,
                                child: Container(
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.borderColor),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _filteredUsers.length,
                                    itemBuilder: (context, index) {
                                      final user = _filteredUsers[index];
                                      return ListTile(
                                        leading: const Icon(Icons.person_outline),
                                        title: Text(
                                          (user['display'] ?? user['name'] ?? 'Unknown').toString(),
                                        ),
                                        onTap: () => _selectUser(user),
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 20),

                      // Amount field
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          hintText: 'Enter amount',
                          prefixIcon: const Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: isMobile ? 16 : 14,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 15,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Payment Mode
                      Text('Payment Mode', style: AppTheme.labelMedium),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          // Get selected payment mode display text
                          String displayText = 'Select Payment Mode';
                          IconData? displayIcon;
                          if (_selectedPaymentModeId != null) {
                            final selectedPM = _paymentModes.firstWhere(
                              (pm) => (pm['_id']?.toString() ?? pm['id']?.toString()) == _selectedPaymentModeId,
                              orElse: () => {},
                            );
                            if (selectedPM.isNotEmpty) {
                              final modeName = selectedPM['modeName']?.toString() ?? 'Unknown';
                              final description = selectedPM['description']?.toString() ?? '';
                              final parsed = PaymentModeService.parseDescription(description);
                              final mode = parsed['mode']?.toString() ?? 'Cash';
                              
                              displayText = modeName;
                              displayIcon = mode == 'Cash'
                                  ? Icons.money
                                  : mode == 'UPI'
                                      ? Icons.qr_code
                                      : Icons.account_balance;
                            }
                          }
                          
                          // Calculate button height for proper menu offset
                          final double buttonHeight = isMobile ? 48.0 : 56.0;
                          final Offset menuOffset = Offset(0, buttonHeight + 4);
                          
                          return Material(
                            elevation: 8,
                            color: Colors.transparent,
                            shadowColor: Colors.transparent,
                            child: PopupMenuButton<String>(
                              offset: menuOffset, // Position menu at bottom of button
                              elevation: 8,
                              shadowColor: Colors.black.withOpacity(0.08),
                              surfaceTintColor: Colors.transparent,
                              color: Colors.white,
                              constraints: BoxConstraints(
                                minWidth: isMobile ? double.infinity : 300,
                                maxWidth: isMobile ? double.infinity : 400,
                                maxHeight: 300,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onSelected: (String? newValue) {
                                if (newValue != null) {
                                  final selectedPM = _paymentModes.firstWhere(
                                    (pm) => (pm['_id']?.toString() ?? pm['id']?.toString()) == newValue,
                                    orElse: () => {},
                                  );
                                  if (selectedPM.isNotEmpty) {
                                    final description = selectedPM['description']?.toString() ?? '';
                                    final parsed = PaymentModeService.parseDescription(description);
                                    final mode = parsed['mode']?.toString() ?? 'Cash';
                                    
                                    setState(() {
                                      _selectedPaymentModeId = newValue;
                                      _selectedMode = mode;
                                    });
                                  }
                                }
                              },
                              itemBuilder: (context) {
                                return _paymentModes.map<PopupMenuEntry<String>>((pm) {
                                  final modeName = pm['modeName']?.toString() ?? 'Unknown';
                                  // Extract modeId with better null handling
                                  final modeId = (pm['_id']?.toString()?.trim() ?? 
                                                 pm['id']?.toString()?.trim() ??
                                                 pm['_id']?.toString() ??
                                                 pm['id']?.toString());
                                  if (modeId == null || modeId.isEmpty) {
                                    print('⚠️ [AddTransactionDialog] Payment mode has no valid ID: $modeName');
                                    return const PopupMenuItem<String>(
                                      enabled: false,
                                      child: Text('Invalid payment mode'),
                                    );
                                  }
                                  final description = pm['description']?.toString() ?? '';
                                  final parsed = PaymentModeService.parseDescription(description);
                                  final mode = parsed['mode']?.toString() ?? 'Cash';
                                  final isSelected = modeId == _selectedPaymentModeId;
                                  
                                  IconData modeIcon = mode == 'Cash'
                                      ? Icons.money
                                      : mode == 'UPI'
                                          ? Icons.qr_code
                                          : Icons.account_balance;
                                  
                                  return PopupMenuItem<String>(
                                    value: modeId,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        if (isSelected)
                                          Icon(
                                            Icons.check,
                                            size: 18,
                                            color: AppTheme.primaryColor,
                                          )
                                        else
                                          const SizedBox(width: 18),
                                        if (isSelected) const SizedBox(width: 8),
                                        Icon(
                                          modeIcon,
                                          color: AppTheme.primaryColor,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            modeName,
                                            style: TextStyle(
                                              color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList();
                              },
                              // Child: Button that looks exactly like DropdownButtonFormField
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.borderColor),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                child: Row(
                                  children: [
                                    if (displayIcon != null) ...[
                                      Icon(
                                        displayIcon,
                                        color: AppTheme.primaryColor,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                    ] else if (_isLoadingPaymentModes) ...[
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Text(
                                        displayText,
                                        style: TextStyle(
                                          fontSize: isMobile ? 16 : 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.keyboard_arrow_down),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Purpose/Notes field
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Purpose / Notes (Optional)',
                          hintText: 'Add purpose or notes for this transfer...',
                          prefixIcon: const Icon(Icons.note_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: isMobile ? 16 : 14,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 15,
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
              ),

              // Action Buttons
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppTheme.borderColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: isMobile ? 15 : 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleTransaction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 24 : 32,
                          vertical: isMobile ? 12 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Submit',
                              style: TextStyle(
                                fontSize: isMobile ? 15 : 16,
                                fontWeight: FontWeight.w600,
                              ),
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
  }
}

