import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../services/transaction_service.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../services/payment_mode_service.dart';
import '../../utils/wallet_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransferScreen extends StatelessWidget {
  final bool embedInDashboard;
  final String? preSelectedReceiverId;
  final String? preSelectedReceiverName;
  
  const TransferScreen({
    super.key,
    this.embedInDashboard = false,
    this.preSelectedReceiverId,
    this.preSelectedReceiverName,
  });

  @override
  Widget build(BuildContext context) {
    // Check for route arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final receiverId = preSelectedReceiverId ?? args?['preSelectedReceiverId'];
    final receiverName = preSelectedReceiverName ?? args?['preSelectedReceiverName'];
    
    return _TransferScreenContent(
      embedInDashboard: embedInDashboard,
      preSelectedReceiverId: receiverId,
      preSelectedReceiverName: receiverName,
    );
  }
}

class _TransferScreenContent extends StatefulWidget {
  final bool embedInDashboard;
  final String? preSelectedReceiverId;
  final String? preSelectedReceiverName;
  
  const _TransferScreenContent({
    this.embedInDashboard = false,
    this.preSelectedReceiverId,
    this.preSelectedReceiverName,
  });

  @override
  State<_TransferScreenContent> createState() => _TransferScreenContentState();
}

class _TransferScreenContentState extends State<_TransferScreenContent> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedReceiverId;
  String? _selectedReceiverName;
  String? _selectedReceiverDisplay;
  String? _selectedMode; // Will be derived from selected PaymentMode
  bool _isLoading = false;
  bool _isLoadingUsers = true;
  List<Map<String, dynamic>> _users = [];
  String? _currentUserId;

  List<Map<String, dynamic>> _paymentModes = [];
  String? _selectedPaymentModeId;
  bool _isLoadingPaymentModes = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadUsers();
    _loadPaymentModes();
  }

  Future<void> _loadPaymentModes() async {
    setState(() {
      _isLoadingPaymentModes = true;
    });

    try {
      final result = await PaymentModeService.getPaymentModes();
      if (result['success'] == true && mounted) {
        final paymentModes = result['paymentModes'] as List<dynamic>? ?? [];
        setState(() {
          _paymentModes = paymentModes
              .where((pm) => pm['isActive'] == true)
              .map((pm) => Map<String, dynamic>.from(pm))
              .toList();
          _isLoadingPaymentModes = false;
          if (_paymentModes.isNotEmpty) {
            _selectedPaymentModeId = _paymentModes.first['_id']?.toString() ?? 
                                    _paymentModes.first['id']?.toString();
            // Derive mode from selected PaymentMode
            final description = _paymentModes.first['description']?.toString() ?? '';
            final parsed = PaymentModeService.parseDescription(description);
            _selectedMode = parsed['mode']?.toString() ?? 'Cash';
          }
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

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
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
        
        // Filter out non-wallet users (only show users with wallets for transfers)
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
              });
            }
          } catch (e) {
            // User not found in list, use provided name if available
            if (widget.preSelectedReceiverName != null && mounted) {
              setState(() {
                _selectedReceiverId = widget.preSelectedReceiverId;
                _selectedReceiverName = widget.preSelectedReceiverName;
                _selectedReceiverDisplay = widget.preSelectedReceiverName;
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

  Future<void> _handleTransfer() async {
    if (_formKey.currentState!.validate()) {
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
        
        final result = await TransactionService.createTransaction(
          sender: _currentUserId!,
          receiver: _selectedReceiverId!,
          amount: amount,
          mode: _selectedMode ?? 'Cash',
          purpose: purpose.isEmpty ? null : purpose,
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? '₹${_amountController.text} transferred to $_selectedReceiverName successfully'),
                backgroundColor: AppTheme.secondaryColor,
                duration: const Duration(seconds: 3),
              ),
            );
            Navigator.of(context).pop(true); // Return true to indicate success
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Failed to transfer amount'),
                backgroundColor: AppTheme.errorColor,
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: _handleTransfer,
                ),
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
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _handleTransfer,
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    
    final content = SingleChildScrollView(
        padding: widget.embedInDashboard 
            ? EdgeInsets.all(isMobile ? 8 : 12)
            : EdgeInsets.all(isMobile ? 16 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : (isTablet ? 600 : 820),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.primaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Transfer is auto-approved and processed immediately',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

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
                    DropdownButtonFormField<String>(
                      value: _selectedReceiverId,
                      decoration: const InputDecoration(
                        labelText: 'Select Receiver',
                        hintText: 'Choose a user',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: _users.map((Map<String, dynamic> user) {
                        return DropdownMenuItem<String>(
                          value: user['id'] as String,
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  (user['display'] ?? user['name'] ?? 'Unknown').toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          final user = _users.firstWhere((u) => u['id'] == newValue);
                          setState(() {
                            _selectedReceiverId = newValue;
                            _selectedReceiverName = user['name'] as String;
                            _selectedReceiverDisplay = user['display'] as String? ?? _selectedReceiverName;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a receiver';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: 'Enter amount',
                      prefixIcon: Icon(Icons.currency_rupee),
                      suffixText: '₹',
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

                  Text('Payment Mode', style: AppTheme.labelMedium),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedPaymentModeId,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        suffixIcon: _isLoadingPaymentModes
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: _paymentModes.map((pm) {
                        final modeName = pm['modeName']?.toString() ?? 'Unknown';
                        final modeId = pm['_id']?.toString() ?? pm['id']?.toString();
                        final description = pm['description']?.toString() ?? '';
                        final parsed = PaymentModeService.parseDescription(description);
                        final mode = parsed['mode']?.toString() ?? 'Cash';
                        
                        return DropdownMenuItem<String>(
                          value: modeId,
                          child: Row(
                            children: [
                              Icon(
                                mode == 'Cash'
                                    ? Icons.money
                                    : mode == 'UPI'
                                        ? Icons.qr_code
                                        : Icons.account_balance,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(modeName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
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
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Purpose / Notes (Optional)',
                      hintText: 'Add purpose or notes for this transfer...',
                      prefixIcon: Icon(Icons.note_outlined),
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleTransfer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Transfer Amount',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

    if (widget.embedInDashboard) {
      return content; // No header when embedded - dashboard handles it
    }
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Transfer Amount'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await AuthService.logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: content,
    );
  }
}