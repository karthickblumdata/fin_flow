import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/collection_service.dart';
import '../services/payment_mode_service.dart';
import '../services/custom_field_service.dart';

class AddCollectionDialog extends StatefulWidget {
  final VoidCallback? onSuccess;
  final String? selectedUserName;
  final String? selectedUserId;
  final List<Map<String, dynamic>>? selectedCustomFields;

  const AddCollectionDialog({
    super.key,
    this.onSuccess,
    this.selectedUserName,
    this.selectedUserId,
    this.selectedCustomFields,
  });

  @override
  State<AddCollectionDialog> createState() => _AddCollectionDialogState();
}

class _AddCollectionDialogState extends State<AddCollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _receiptNoController = TextEditingController();
  final _amountController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _userName;
  String? _selectedAccountId;
  String? _selectedMode;
  File? _proofImage;
  bool _isLoading = false;
  bool _isLoadingAccounts = true;
  bool _isLoadingCustomFields = true;
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _customFields = [];
  Map<String, TextEditingController> _customFieldControllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize custom fields from widget parameter
    if (widget.selectedCustomFields != null && widget.selectedCustomFields!.isNotEmpty) {
      _customFields = List.from(widget.selectedCustomFields!);
      for (var field in _customFields) {
        final fieldId = field['id']?.toString() ?? field['_id']?.toString() ?? '';
        if (fieldId.isNotEmpty) {
          _customFieldControllers[fieldId] = TextEditingController();
        }
      }
      _isLoadingCustomFields = false;
    } else {
      // Load all active custom fields that are enabled for collections
      _loadCustomFields();
    }
    // Use WidgetsBinding to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadUserInfo();
        _loadAccounts();
      }
    });
  }

  Future<void> _loadCustomFields() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingCustomFields = true;
    });

    try {
      final result = await CustomFieldService.getCustomFields();
      if (mounted) {
        if (result['success'] == true) {
          final allFields = result['customFields'] as List<dynamic>? ?? [];
          // Filter only active fields - if active, show in collection popup
          final enabledFields = allFields.where((field) {
            final isActive = field['isActive'] == true;
            return isActive; // Only check isActive, not useInCollections
          }).toList();

          setState(() {
            _customFields = enabledFields.map((field) => field as Map<String, dynamic>).toList();
            for (var field in _customFields) {
              final fieldId = field['id']?.toString() ?? field['_id']?.toString() ?? '';
              if (fieldId.isNotEmpty && !_customFieldControllers.containsKey(fieldId)) {
                _customFieldControllers[fieldId] = TextEditingController();
              }
            }
            _isLoadingCustomFields = false;
          });
        } else {
          setState(() {
            _isLoadingCustomFields = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCustomFields = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _receiptNoController.dispose();
    _amountController.dispose();
    // Dispose custom field controllers
    for (var controller in _customFieldControllers.values) {
      controller.dispose();
    }
    _customFieldControllers.clear();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    // Use selected user name if provided, otherwise use current logged-in user
    if (widget.selectedUserName != null && widget.selectedUserName!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _userName = widget.selectedUserName!;
        });
      }
    } else {
      try {
        final userName = await AuthService.getUserName();
        if (mounted) {
          setState(() {
            _userName = userName ?? 'Unknown User';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _userName = 'Unknown User';
          });
        }
      }
    }
  }

  Future<void> _loadAccounts() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingAccounts = true;
    });

    try {
      final result = await PaymentModeService.getPaymentModes(displayType: 'Collection');
      if (mounted) {
        if (result['success'] == true) {
          final paymentModes = result['paymentModes'] as List<dynamic>? ?? [];
          setState(() {
            _accounts = paymentModes.map((pm) {
              final assignedReceiver = pm['assignedReceiver'];
              final receiverName = assignedReceiver is Map
                  ? (assignedReceiver['name'] ?? 'Unknown')
                  : 'Unknown';

              return {
                'id': pm['_id'] ?? pm['id'],
                'name': pm['modeName'] ?? '',
                'description': pm['description'] ?? '',
                'mode': _extractModeFromName(pm['modeName'] ?? ''),
                'autoPay': pm['autoPay'] ?? false,
                'isActive': pm['isActive'] ?? true,
                'assignedReceiver': receiverName,
              };
            }).where((acc) => acc['isActive'] == true).toList();

            // Auto-select first account if available
            if (_accounts.isNotEmpty) {
              _selectedAccountId = _accounts.first['id'];
              _selectedMode = _accounts.first['mode'];
            }
            _isLoadingAccounts = false;
          });
        } else {
          setState(() {
            _isLoadingAccounts = false;
          });
          
          // Show error message if loading failed - use root context for snackbar
          if (result['message'] != null && context.mounted) {
            final rootContext = Navigator.of(context, rootNavigator: true).context;
            if (rootContext.mounted) {
              ScaffoldMessenger.of(rootContext).showSnackBar(
                SnackBar(
                  content: Text('Failed to load accounts: ${result['message']}'),
                  backgroundColor: AppTheme.errorColor,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAccounts = false;
        });
        
        // Use root context for snackbar
        if (context.mounted) {
          final rootContext = Navigator.of(context, rootNavigator: true).context;
          if (rootContext.mounted) {
            ScaffoldMessenger.of(rootContext).showSnackBar(
              SnackBar(
                content: Text('Error loading accounts: ${e.toString()}'),
                backgroundColor: AppTheme.errorColor,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    }
  }

  String _extractModeFromName(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('cash')) return 'Cash';
    if (lowerName.contains('upi')) return 'UPI';
    if (lowerName.contains('bank')) return 'Bank';
    return 'Cash'; // Default
  }

  IconData _getModeIcon(String mode) {
    switch (mode) {
      case 'Cash':
        return Icons.money;
      case 'UPI':
        return Icons.qr_code;
      case 'Bank':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  Future<void> _pickProofImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        setState(() {
          _proofImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted && context.mounted) {
        final rootContext = Navigator.of(context, rootNavigator: true).context;
        if (rootContext.mounted) {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            SnackBar(
              content: Text('Error picking image: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _submitCollection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate: Account must be selected if accounts are available
    // If no accounts are available, mode must be selected
    if (_accounts.isNotEmpty && _selectedAccountId == null) {
      if (context.mounted) {
        final rootContext = Navigator.of(context, rootNavigator: true).context;
        if (rootContext.mounted) {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            const SnackBar(
              content: Text('Please select an account'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
      return;
    }
    
    if (_accounts.isEmpty && _selectedMode == null) {
      if (context.mounted) {
        final rootContext = Navigator.of(context, rootNavigator: true).context;
        if (rootContext.mounted) {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            const SnackBar(
              content: Text('Please select a payment mode'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
      return;
    }
    
    // Backend requires paymentModeId, so if no accounts available, we can't proceed
    if (_accounts.isEmpty) {
      if (context.mounted) {
        final rootContext = Navigator.of(context, rootNavigator: true).context;
        if (rootContext.mounted) {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            const SnackBar(
              content: Text('No payment accounts available. Please contact administrator to set up payment accounts.'),
              backgroundColor: AppTheme.errorColor,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Upload proof image if available
      String? proofUrl;
      if (_proofImage != null) {
        // Implement image upload logic here
        // proofUrl = await uploadImage(_proofImage!);
      }

      // Determine mode: use selected mode if no account, otherwise use account's mode
      String finalMode;
      if (_selectedAccountId != null) {
        final selectedAccount = _accounts.firstWhere(
          (acc) => acc['id'] == _selectedAccountId,
        );
        finalMode = selectedAccount['mode'] ?? _selectedMode ?? 'Cash';
      } else {
        finalMode = _selectedMode ?? 'Cash';
      }

      // Collect custom field values
      final Map<String, String> customFieldsData = {};
      for (var field in _customFields) {
        final fieldId = field['id']?.toString() ?? field['_id']?.toString() ?? '';
        final controller = _customFieldControllers[fieldId];
        if (controller != null && controller.text.trim().isNotEmpty) {
          customFieldsData[fieldId] = controller.text.trim();
        }
      }

      final result = await CollectionService.createCollection(
        customerName: _customerNameController.text.trim(),
        amount: double.parse(_amountController.text),
        mode: finalMode,
        paymentModeId: _selectedAccountId,
        assignedReceiver: widget.selectedUserId,
        proofUrl: proofUrl,
        notes: _receiptNoController.text.trim().isNotEmpty
            ? 'Receipt No: ${_receiptNoController.text.trim()}'
            : null,
        customFields: customFieldsData.isNotEmpty ? customFieldsData : null,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          // Use root context for snackbar
          if (context.mounted) {
            final rootContext = Navigator.of(context, rootNavigator: true).context;
            if (rootContext.mounted) {
              ScaffoldMessenger.of(rootContext).showSnackBar(
                SnackBar(
                  content: Text(result['message'] ?? 'Collection created successfully'),
                  backgroundColor: AppTheme.secondaryColor,
                ),
              );
            }
            Navigator.of(context).pop();
          }
          if (widget.onSuccess != null) {
            widget.onSuccess!();
          }
        } else {
          // Use root context for snackbar
          final rootContext = Navigator.of(context, rootNavigator: true).context;
          if (rootContext.mounted) {
            ScaffoldMessenger.of(rootContext).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Failed to create collection'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Use root context for snackbar
        final rootContext = Navigator.of(context, rootNavigator: true).context;
        if (rootContext.mounted) {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenHeight = MediaQuery.of(context).size.height;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final keyboardHeight = viewInsets.bottom;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isMobile && keyboardHeight > 0 ? 8 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: isMobile ? double.infinity : 500,
        constraints: BoxConstraints(
          maxHeight: isMobile && keyboardHeight > 0
              ? screenHeight - keyboardHeight - 16
              : screenHeight * 0.85,
          minHeight: isMobile && keyboardHeight > 0 ? 0 : 400,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Header with User Name
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Add Collection',
                                  style: AppTheme.headingMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              // Close button - always visible
                              IconButton(
                                onPressed: () {
                                  if (mounted && context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
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
                          // User name below on mobile
                          if (_userName != null) ...[
                            const SizedBox(height: 8),
                            Row(
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
                                    _userName!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      )
                    : Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Add Collection',
                              style: AppTheme.headingMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // User name on the right (non-editable)
                          if (_userName != null)
                            Row(
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
                                    _userName!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                          // Close button - always visible
                          IconButton(
                            onPressed: () {
                              if (mounted && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
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
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: isMobile && keyboardHeight > 0
                        ? screenHeight - keyboardHeight - 200
                        : screenHeight * 0.6,
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      // Customer Name
                      TextFormField(
                        controller: _customerNameController,
                        decoration: InputDecoration(
                          labelText: 'Customer Name',
                          prefixIcon: const Icon(Icons.person_outline),
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
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter customer name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: isMobile ? 16 : 20),

                      // Receipt No
                      TextFormField(
                        controller: _receiptNoController,
                        decoration: InputDecoration(
                          labelText: 'Receipt No',
                          prefixIcon: const Icon(Icons.receipt_long),
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
                      SizedBox(height: isMobile ? 16 : 20),

                      // Amount
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Amount',
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
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: isMobile ? 16 : 20),

                      // Account Selection (Payment Mode)
                      if (_isLoadingAccounts)
                        Container(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 12),
                              Text(
                                'Loading payment modes...',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_accounts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
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
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No payment accounts available. Please contact administrator to set up payment accounts before creating collections.',
                                  style: TextStyle(
                                    color: AppTheme.errorColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedAccountId,
                          isExpanded: true,
                          menuMaxHeight: isMobile ? 300 : 400,
                          decoration: InputDecoration(
                            labelText: 'Account',
                            prefixIcon: const Icon(Icons.account_balance),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isMobile ? 10 : 14,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: isMobile ? 15 : 15,
                          ),
                          selectedItemBuilder: (BuildContext context) {
                            // Custom builder for selected item display (single line to prevent overflow)
                            return _accounts.map((account) {
                              final autoPayStatus = account['autoPay'] == true ? 'ON' : 'OFF';
                              if (isMobile) {
                                // Very compact single line display for mobile to prevent overflow
                                return Row(
                                  children: [
                                    Icon(
                                      _getModeIcon(account['mode']),
                                      size: 16,
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${account['name'] ?? 'Unknown'} • AP: $autoPayStatus',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                // Desktop: single line with all info
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getModeIcon(account['mode']),
                                      size: 20,
                                      color: AppTheme.primaryColor,
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        '${account['name'] ?? 'Unknown'} (Auto Pay: $autoPayStatus)',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );
                              }
                            }).toList();
                          },
                          items: _accounts.map((account) {
                            final autoPayStatus = account['autoPay'] == true ? 'ON' : 'OFF';
                            return DropdownMenuItem<String>(
                              value: account['id'],
                              child: isMobile
                                  ? Row(
                                      children: [
                                        Icon(
                                          _getModeIcon(account['mode']),
                                          size: 20,
                                          color: AppTheme.primaryColor,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                account['name'] ?? 'Unknown',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Auto Pay: $autoPayStatus',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getModeIcon(account['mode']),
                                          size: 20,
                                          color: AppTheme.primaryColor,
                                        ),
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: Text(
                                            '${account['name'] ?? 'Unknown'} (Auto Pay: $autoPayStatus)',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedAccountId = newValue;
                                final selectedAccount = _accounts.firstWhere(
                                  (acc) => acc['id'] == newValue,
                                );
                                _selectedMode = selectedAccount['mode'];
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select an account';
                            }
                            return null;
                          },
                        ),
                      SizedBox(height: isMobile ? 16 : 20),

                      // Custom Fields (after Account field)
                      if (_isLoadingCustomFields)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_customFields.isNotEmpty) ...[
                        ..._customFields.map((field) {
                          final fieldId = field['id']?.toString() ?? field['_id']?.toString() ?? '';
                          final fieldName = field['name']?.toString() ?? 'Custom Field';
                          final controller = _customFieldControllers[fieldId] ?? TextEditingController();
                          if (!_customFieldControllers.containsKey(fieldId)) {
                            _customFieldControllers[fieldId] = controller;
                          }
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fieldName,
                                style: AppTheme.labelMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: controller,
                                decoration: InputDecoration(
                                  hintText: 'Enter $fieldName...',
                                  prefixIcon: const Icon(Icons.text_fields),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: isMobile ? 10 : 14,
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: isMobile ? 15 : 15,
                                ),
                              ),
                              SizedBox(height: isMobile ? 16 : 20),
                            ],
                          );
                        }).toList(),
                      ],

                      // Proof Image
                      Text(
                        'Proof:',
                        style: AppTheme.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickProofImage,
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.borderColor,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _proofImage != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(
                                        _proofImage!,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: IconButton(
                                        icon: const Icon(Icons.close),
                                        color: Colors.white,
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.black54,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _proofImage = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 40,
                                        color: AppTheme.textSecondary,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap to add proof image',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                child: isMobile
                    ? Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (_isLoading || _accounts.isEmpty) ? null : _submitCollection,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryColor,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: isMobile ? 16 : 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Submit',
                                      style: TextStyle(
                                        fontSize: isMobile ? 16 : 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      if (mounted && context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: isMobile ? 16 : 12,
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: isMobile ? 16 : 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    if (mounted && context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: AppTheme.primaryColor),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: (_isLoading || _accounts.isEmpty) ? null : _submitCollection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Submit',
                                    style: TextStyle(
                                      fontSize: 16,
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
