import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../services/expense_service.dart';
import '../services/expense_type_service.dart';
import '../services/payment_mode_service.dart';

class AddExpenseDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final VoidCallback? onSuccess;

  const AddExpenseDialog({
    super.key,
    required this.userId,
    required this.userName,
    this.onSuccess,
  });

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _remarkController = TextEditingController();
  
  int _currentStep = 1; // Step 1: Type Selection, Step 2: Details
  String? _selectedMode;
  bool _isLoading = false;
  bool _isLoadingExpenseTypes = true;
  bool _isLoadingModes = true;
  bool _isSubmitting = false;
  
  Map<String, dynamic>? _selectedExpenseType;
  List<Map<String, dynamic>> _expenseTypes = [];
  XFile? _selectedProofImage;
  
  List<Map<String, dynamic>> _paymentModes = [];
  String? _selectedPaymentModeId;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExpenseTypes();
    _loadPaymentModes();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenseTypes() async {
    setState(() {
      _isLoadingExpenseTypes = true;
    });

    try {
      final result = await ExpenseTypeService.getActiveExpenseTypes();
      
      if (result['success'] == true) {
        final expenseTypes = result['expenseTypes'] as List<dynamic>? ?? [];
        setState(() {
          _expenseTypes = expenseTypes
              .map((et) => <String, dynamic>{
                    'name': et['name']?.toString() ?? '',
                    'imageUrl': et['imageUrl']?.toString(),
                    'proofRequired': et['proofRequired'] == true || et['isProofRequired'] == true,
                  })
              .where((et) => (et['name'] as String).isNotEmpty)
              .toList();
          
          // If no types from API, use default list
          if (_expenseTypes.isEmpty) {
            _expenseTypes = [
              {'name': 'Office', 'imageUrl': null, 'proofRequired': false},
              {'name': 'Travel', 'imageUrl': null, 'proofRequired': false},
              {'name': 'Marketing', 'imageUrl': null, 'proofRequired': false},
              {'name': 'Maintenance', 'imageUrl': null, 'proofRequired': false},
              {'name': 'Misc', 'imageUrl': null, 'proofRequired': false},
            ];
          }
        });
      }
    } catch (e) {
      // Use default categories on error
      setState(() {
        _expenseTypes = [
          {'name': 'Office', 'imageUrl': null, 'proofRequired': false},
          {'name': 'Travel', 'imageUrl': null, 'proofRequired': false},
          {'name': 'Marketing', 'imageUrl': null, 'proofRequired': false},
          {'name': 'Maintenance', 'imageUrl': null, 'proofRequired': false},
          {'name': 'Misc', 'imageUrl': null, 'proofRequired': false},
        ];
      });
    } finally {
      setState(() {
        _isLoadingExpenseTypes = false;
      });
    }
  }

  Future<void> _loadPaymentModes() async {
    print('🔍 [AddExpenseDialog] _loadPaymentModes() called');
    setState(() {
      _isLoadingModes = true;
    });

    try {
      print('🔍 [AddExpenseDialog] Calling getPaymentModes with displayType: Expenses');
      final result = await PaymentModeService.getPaymentModes(displayType: 'Expenses');
      print('🔍 [AddExpenseDialog] getPaymentModes response: success=${result['success']}, count=${result['paymentModes']?.length ?? 0}');
      
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

  bool _isProofRequired() {
    return _selectedExpenseType?['proofRequired'] == true;
  }

  String? _getExpenseTypeImageUrl(String typeName) {
    if (_selectedExpenseType != null && _selectedExpenseType!['imageUrl'] != null) {
      final imageUrl = _selectedExpenseType!['imageUrl']?.toString();
      if (imageUrl != null && imageUrl.isNotEmpty) {
        return imageUrl;
      }
    }
    
    // Fallback to default images
    final normalizedType = typeName.trim().toLowerCase();
    if (normalizedType.contains('office')) {
      return 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400&h=400&fit=crop';
    }
    if (normalizedType.contains('travel')) {
      return 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=400&h=400&fit=crop';
    }
    if (normalizedType.contains('marketing')) {
      return 'https://images.unsplash.com/photo-1552664730-d307ca884978?w=400&h=400&fit=crop';
    }
    if (normalizedType.contains('maintenance')) {
      return 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=400&h=400&fit=crop';
    }
    if (normalizedType.contains('misc')) {
      return 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=400&h=400&fit=crop';
    }
    return null;
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate proof requirement
    if (_isProofRequired() && _selectedProofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proof image is mandatory for this expense type. Please upload a proof image.'),
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      final description = _descriptionController.text.trim();
      final remark = _remarkController.text.trim();
      final category = _selectedExpenseType?['name']?.toString() ?? 'Misc';
      
      // Upload proof image if selected
      String? proofUrl;
      if (_selectedProofImage != null) {
        final uploadResult = await ExpenseService.uploadProofImage(_selectedProofImage!);
        
        if (uploadResult['success'] == true) {
          proofUrl = uploadResult['imageUrl']?.toString();
        } else {
          setState(() {
            _isSubmitting = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(uploadResult['message']?.toString() ?? 'Failed to upload proof image'),
                backgroundColor: AppTheme.errorColor,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
      
      // Create expense
      final result = await ExpenseService.createExpense(
        userId: widget.userId,
        category: category,
        amount: amount,
        mode: _selectedMode ?? 'Cash',
        description: description.isNotEmpty ? description : null,
        remarks: remark.isNotEmpty ? remark : null,
        proofUrl: proofUrl,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        if (result['success'] == true) {
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Expense added successfully'),
              backgroundColor: AppTheme.secondaryColor,
              duration: const Duration(seconds: 3),
            ),
          );

          widget.onSuccess?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to add expense'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : (isTablet ? 700 : 800),
          maxHeight: MediaQuery.of(context).size.height * (isMobile ? 0.95 : 0.85),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.zero,
        child: _currentStep == 1
            ? _buildExpenseTypeSelectionStep(isMobile: isMobile, isTablet: isTablet)
            : _buildExpenseDetailsStep(isMobile: isMobile, isTablet: isTablet),
      ),
    );
  }

  Widget _buildExpenseTypeSelectionStep({required bool isMobile, required bool isTablet}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: AppTheme.warningColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Select Expense Type',
                            style: AppTheme.headingMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
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
                    if (widget.userName.isNotEmpty) ...[
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
                    ],
                  ],
                )
              : Row(
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select Expense Type',
                        style: AppTheme.headingMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (widget.userName.isNotEmpty)
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
        
        // Scrollable Content
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose an expense category',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Expense Type Grid
                _isLoadingExpenseTypes
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          childAspectRatio: 0.95,
                        ),
                        itemCount: _expenseTypes.length,
                        itemBuilder: (context, index) {
                          final expenseType = _expenseTypes[index];
                          final typeName = expenseType['name']?.toString() ?? '';
                          final imageUrl = expenseType['imageUrl']?.toString();
                          final isSelected = _selectedExpenseType != null &&
                              _selectedExpenseType!['name'] == typeName;
                          final displayImageUrl = imageUrl ?? _getExpenseTypeImageUrl(typeName);

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedExpenseType = expenseType;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.warningColor.withOpacity(0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.warningColor
                                      : AppTheme.borderColor,
                                  width: isSelected ? 1.5 : 0.5,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Image
                                    Expanded(
                                      flex: 3,
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: AppTheme.borderColor.withOpacity(0.3),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: displayImageUrl != null
                                              ? Image.network(
                                                  displayImageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Icon(
                                                      Icons.category_outlined,
                                                      size: 18,
                                                      color: AppTheme.textSecondary,
                                                    );
                                                  },
                                                )
                                              : Icon(
                                                  Icons.category_outlined,
                                                  size: 18,
                                                  color: AppTheme.textSecondary,
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // Name
                                    Expanded(
                                      flex: 1,
                                      child: Center(
                                        child: Text(
                                          typeName,
                                          style: AppTheme.bodyMedium.copyWith(
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            fontSize: 9,
                                            color: isSelected
                                                ? AppTheme.warningColor
                                                : AppTheme.textPrimary,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
        
        // Continue Button
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedExpenseType == null
                  ? null
                  : () {
                      setState(() {
                        _currentStep = 2;
                      });
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                backgroundColor: AppTheme.warningColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.borderColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseDetailsStep({required bool isMobile, required bool isTablet}) {
    final typeName = _selectedExpenseType?['name']?.toString() ?? 'Unknown';
    final imageUrl = _getExpenseTypeImageUrl(typeName);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: EdgeInsets.all(isMobile ? 10 : 20),
          decoration: BoxDecoration(
            color: AppTheme.warningColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              // Selected expense type image
              Container(
                width: isMobile ? 32 : 40,
                height: isMobile ? 32 : 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.category_outlined,
                              size: isMobile ? 18 : 24,
                              color: Colors.white,
                            );
                          },
                        )
                      : Icon(
                          Icons.category_outlined,
                          size: isMobile ? 18 : 24,
                          color: Colors.white,
                        ),
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add Expense',
                      style: AppTheme.headingMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 16 : null,
                      ),
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(
                      typeName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.userName.isNotEmpty && !isMobile)
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
            ],
          ),
        ),

        // Form Content
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  
                  // Mode Dropdown
                  _isLoadingModes
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
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
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a payment mode';
                                }
                                return null;
                              },
                            ),
                  SizedBox(height: isMobile ? 16 : 20),
                  
                  // Description Input (Optional)
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Enter description',
                      prefixIcon: const Icon(Icons.description),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 16 : 20),
                  
                  // Remark Input (Optional)
                  TextFormField(
                    controller: _remarkController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Remark (Optional)',
                      hintText: 'Enter remark',
                      prefixIcon: const Icon(Icons.note_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 16 : 20),
                  
                  // Proof Image Upload
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Proof:',
                            style: AppTheme.labelMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _isProofRequired()
                                  ? AppTheme.errorColor.withOpacity(0.1)
                                  : AppTheme.secondaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _isProofRequired()
                                    ? AppTheme.errorColor.withOpacity(0.3)
                                    : AppTheme.secondaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _isProofRequired() ? 'Mandatory' : 'Optional',
                              style: AppTheme.bodySmall.copyWith(
                                color: _isProofRequired()
                                    ? AppTheme.errorColor
                                    : AppTheme.secondaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _isSubmitting
                            ? null
                            : () async {
                                try {
                                  final XFile? image =
                                      await _imagePicker.pickImage(
                                    source: ImageSource.gallery,
                                  );
                                  if (image != null) {
                                    setState(() {
                                      _selectedProofImage = image;
                                    });
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Error picking image: ${e.toString()}'),
                                        backgroundColor: AppTheme.errorColor,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: Container(
                          height: isMobile ? 100 : 120,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.borderColor,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _selectedProofImage != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: kIsWeb
                                          ? FutureBuilder<Uint8List>(
                                              future: _selectedProofImage!.readAsBytes(),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const Center(
                                                    child: CircularProgressIndicator(
                                                        strokeWidth: 2),
                                                  );
                                                }
                                                if (snapshot.hasData) {
                                                  return Image.memory(
                                                    snapshot.data!,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    fit: BoxFit.cover,
                                                  );
                                                }
                                                return const Center(
                                                  child: Icon(
                                                    Icons.error_outline,
                                                    size: 20,
                                                  ),
                                                );
                                              },
                                            )
                                          : FutureBuilder<Uint8List>(
                                              future: _selectedProofImage!.readAsBytes(),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const Center(
                                                    child: CircularProgressIndicator(
                                                        strokeWidth: 2),
                                                  );
                                                }
                                                if (snapshot.hasData) {
                                                  return Image.memory(
                                                    snapshot.data!,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    fit: BoxFit.cover,
                                                  );
                                                }
                                                return const Center(
                                                  child: Icon(
                                                    Icons.error_outline,
                                                    size: 20,
                                                  ),
                                                );
                                              },
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
                                        onPressed: _isSubmitting
                                            ? null
                                            : () {
                                                setState(() {
                                                  _selectedProofImage = null;
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
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          const Icon(
                                            Icons.add_photo_alternate_outlined,
                                            size: 40,
                                            color: AppTheme.textSecondary,
                                          ),
                                          Positioned(
                                            top: -8,
                                            right: -8,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: AppTheme.textSecondary,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.add,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
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
                ],
              ),
            ),
          ),
        ),
        
        // Action Buttons
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.borderColor),
            ),
          ),
          child: isMobile
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isSubmitting || (_isProofRequired() && _selectedProofImage == null))
                            ? null
                            : _submitExpense,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                          backgroundColor: AppTheme.warningColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppTheme.borderColor,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Submit',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _currentStep = 1;
                                });
                              },
                        child: Text(
                          'Previous',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: isMobile ? 14 : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _currentStep = 1;
                                });
                              },
                        child: Text(
                          'Previous',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: isMobile ? 14 : null,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Flexible(
                      child: ElevatedButton(
                        onPressed: (_isSubmitting || (_isProofRequired() && _selectedProofImage == null))
                            ? null
                            : _submitExpense,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 16),
                          backgroundColor: AppTheme.warningColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppTheme.borderColor,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

