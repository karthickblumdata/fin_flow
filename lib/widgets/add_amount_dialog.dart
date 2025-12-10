import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../services/wallet_service.dart';
import '../services/payment_mode_service.dart';

class AddAmountDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final VoidCallback? onSuccess;

  const AddAmountDialog({
    super.key,
    required this.userId,
    required this.userName,
    this.onSuccess,
  });

  @override
  State<AddAmountDialog> createState() => _AddAmountDialogState();
}

class _AddAmountDialogState extends State<AddAmountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarkController = TextEditingController();
  
  String? _selectedMode;
  bool _isLoading = false;
  bool _isLoadingModes = true;
  List<Map<String, dynamic>> _paymentModes = [];
  String? _selectedPaymentModeId;

  @override
  void initState() {
    super.initState();
    _loadPaymentModes();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentModes() async {
    setState(() {
      _isLoadingModes = true;
    });

    try {
      final result = await PaymentModeService.getPaymentModes();
      
      if (mounted) {
        if (result['success'] == true) {
          final paymentModes = result['paymentModes'] as List<dynamic>? ?? [];
          
          // Store all active PaymentModes directly
          setState(() {
            _paymentModes = paymentModes
                .where((pm) => pm['isActive'] == true)
                .map((pm) => Map<String, dynamic>.from(pm))
                .toList();
            _isLoadingModes = false;
            // Set default selected payment mode to first available
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
          setState(() {
            _paymentModes = [];
            _isLoadingModes = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _paymentModes = [];
          _isLoadingModes = false;
        });
      }
    }
  }

  Future<void> _submitAmount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_selectedMode == null || _selectedPaymentModeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a payment mode'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      final amount = double.parse(_amountController.text);
      final remark = _remarkController.text.trim();

      final result = await WalletService.addAmount(
        mode: _selectedMode!,
        amount: amount,
        notes: remark.isEmpty ? null : remark,
        userId: widget.userId,
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
              content: Text(result['message'] ?? 'Amount added successfully'),
              backgroundColor: AppTheme.secondaryColor,
              duration: const Duration(seconds: 3),
            ),
          );

          widget.onSuccess?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to add amount'),
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
        width: isMobile ? double.infinity : 500,
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
                      Icons.add_circle_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Add Amount',
                        style: AppTheme.headingMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // User name
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
                            widget.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
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
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Payment Mode Selection
                      _isLoadingModes
                          ? Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: isMobile ? 16 : 14,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.borderColor),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Loading payment modes...',
                                    style: TextStyle(
                                      fontSize: isMobile ? 16 : 15,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _paymentModes.isEmpty
                              ? Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: isMobile ? 16 : 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppTheme.errorColor),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline, 
                                        color: AppTheme.errorColor, size: 20),
                                      const SizedBox(width: 12),
                                      Text(
                                        'No active payment modes available',
                                        style: TextStyle(
                                          fontSize: isMobile ? 16 : 15,
                                          color: AppTheme.errorColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : DropdownButtonFormField<String>(
                                  value: _selectedPaymentModeId,
                                  decoration: InputDecoration(
                                    labelText: 'Payment Mode',
                                    prefixIcon: const Icon(Icons.payment),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: isMobile ? 16 : 14,
                                    ),
                                    suffixIcon: _isLoadingModes
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
                                  style: TextStyle(
                                    fontSize: isMobile ? 16 : 15,
                                  ),
                                  items: _paymentModes.map((pm) {
                                    final modeName = pm['modeName']?.toString() ?? 'Unknown';
                                    final modeId = pm['_id']?.toString() ?? pm['id']?.toString();
                                    final description = pm['description']?.toString() ?? '';
                                    final parsed = PaymentModeService.parseDescription(description);
                                    final mode = parsed['mode']?.toString() ?? 'Cash';
                                    
                                    IconData icon;
                                    if (mode == 'Cash') {
                                      icon = Icons.money;
                                    } else if (mode == 'UPI') {
                                      icon = Icons.qr_code;
                                    } else {
                                      icon = Icons.account_balance;
                                    }

                                    return DropdownMenuItem<String>(
                                      value: modeId,
                                      child: Row(
                                        children: [
                                          Icon(icon, size: 20, color: AppTheme.primaryColor),
                                          const SizedBox(width: 12),
                                          Text(modeName),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      final selectedPM = _paymentModes.firstWhere(
                                        (pm) => (pm['_id']?.toString() ?? pm['id']?.toString()) == value,
                                        orElse: () => {},
                                      );
                                      if (selectedPM.isNotEmpty) {
                                        final description = selectedPM['description']?.toString() ?? '';
                                        final parsed = PaymentModeService.parseDescription(description);
                                        final mode = parsed['mode']?.toString() ?? 'Cash';
                                        
                                        setState(() {
                                          _selectedPaymentModeId = value;
                                          _selectedMode = mode;
                                        });
                                      }
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a payment mode';
                                    }
                                    return null;
                                  },
                                ),
                      SizedBox(height: isMobile ? 16 : 20),

                      // Amount Input
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
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
                      SizedBox(height: isMobile ? 16 : 20),

                      // Remark Input
                      TextFormField(
                        controller: _remarkController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Remark',
                          hintText: 'Enter remark (optional)',
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
                      onPressed: _isLoading ? null : _submitAmount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
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

