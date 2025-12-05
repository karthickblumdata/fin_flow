import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../services/expense_type_service.dart';
import '../services/auth_service.dart';

class EditExpenseTypeDialog extends StatefulWidget {
  const EditExpenseTypeDialog({
    super.key,
    required this.expenseType,
  });

  final Map<String, dynamic> expenseType;

  @override
  State<EditExpenseTypeDialog> createState() => _EditExpenseTypeDialogState();
}

class _EditExpenseTypeDialogState extends State<EditExpenseTypeDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late bool _isActive;
  late bool _isProofRequired; // false = optional, true = mandatory
  bool _isSubmitting = false;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImagePath;
  String? _currentImageUrl;
  final ImagePicker _imagePicker = ImagePicker();
  String? _userName;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.expenseType['name']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.expenseType['description']?.toString() ?? '',
    );
    // Initialize isActive - check both possible field names and handle different data types
    final statusValue = widget.expenseType['status'];
    final isActiveValue = widget.expenseType['isActive'];
    
    if (statusValue != null && statusValue.toString().toLowerCase() == 'active') {
      _isActive = true;
    } else if (isActiveValue != null) {
      if (isActiveValue is bool) {
        _isActive = isActiveValue;
      } else if (isActiveValue is String) {
        final lowerValue = isActiveValue.toLowerCase().trim();
        _isActive = lowerValue == 'true' || lowerValue == '1' || lowerValue == 'active';
      } else if (isActiveValue is int || isActiveValue is num) {
        _isActive = isActiveValue == 1 || isActiveValue.toDouble() == 1.0;
      } else {
        _isActive = false;
      }
    } else {
      _isActive = true; // Default to true if not found
    }
    // Initialize proofRequired - check both possible field names
    // Handle boolean, string, number (1/0), and null cases
    final proofRequiredValue = widget.expenseType['proofRequired'] ?? 
        widget.expenseType['isProofRequired'];
    
    if (proofRequiredValue == null) {
      _isProofRequired = false; // Default to false if not found
    } else if (proofRequiredValue is bool) {
      _isProofRequired = proofRequiredValue;
    } else if (proofRequiredValue is String) {
      final lowerValue = proofRequiredValue.toLowerCase().trim();
      _isProofRequired = lowerValue == 'true' || lowerValue == '1';
    } else if (proofRequiredValue is int) {
      _isProofRequired = proofRequiredValue == 1;
    } else if (proofRequiredValue is num) {
      _isProofRequired = proofRequiredValue.toDouble() == 1.0;
    } else {
      // For any other type, try to convert to bool
      _isProofRequired = proofRequiredValue == true || proofRequiredValue.toString() == 'true';
    }
    _currentImageUrl = widget.expenseType['imageUrl']?.toString();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final userName = await AuthService.getUserName();
    if (mounted) {
      setState(() {
        _userName = userName;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildImagePicker(),
                      const SizedBox(height: 20),
                      _buildNameField(),
                      const SizedBox(height: 20),
                      _buildDescriptionField(),
                      const SizedBox(height: 20),
                      _buildStatusSwitch(),
                      const SizedBox(height: 20),
                      _buildProofRequirementSwitch(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final typeName = widget.expenseType['name']?.toString() ?? '';
    final typeColor = _getTypeColor(typeName);
    final imageUrl = _getTypeImageUrl(typeName);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        final typeIcon = _getTypeIcon(typeName);
                        return Icon(
                          typeIcon ?? Icons.edit_outlined,
                          color: typeColor,
                          size: 24,
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                          ),
                        );
                      },
                    )
                  : Icon(
                      _getTypeIcon(typeName) ?? Icons.edit_outlined,
                      color: typeColor,
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Expense Type',
                  style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Update expense type details.',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          // Username in top-right corner
          if (_userName != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _userName!,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  String? _getTypeImageUrl(String type) {
    // Using Unsplash images for real photos - specific and recognizable images based on name
    final normalizedType = type.trim().toLowerCase();
    
    // Office related images
    if (normalizedType.contains('office') || normalizedType.contains('coffee') || normalizedType.contains('cafe')) {
      return 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400&h=400&fit=crop';
    }
    
    // Travel related images
    if (normalizedType.contains('travel') || normalizedType.contains('bus') || normalizedType.contains('transport')) {
      return 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=400&h=400&fit=crop';
    }
    
    // Marketing related images
    if (normalizedType.contains('marketing') || normalizedType.contains('advert') || normalizedType.contains('promo')) {
      return 'https://images.unsplash.com/photo-1552664730-d307ca884978?w=400&h=400&fit=crop';
    }
    
    // Maintenance related images
    if (normalizedType.contains('maintenance') || normalizedType.contains('repair') || normalizedType.contains('tool')) {
      return 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=400&h=400&fit=crop';
    }
    
    // Food related images
    if (normalizedType.contains('food') || normalizedType.contains('meal') || normalizedType.contains('restaurant')) {
      return 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&h=400&fit=crop';
    }
    
    // Medical related images
    if (normalizedType.contains('medical') || normalizedType.contains('health') || normalizedType.contains('hospital')) {
      return 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1f?w=400&h=400&fit=crop';
    }
    
    // Fuel related images
    if (normalizedType.contains('fuel') || normalizedType.contains('petrol') || normalizedType.contains('gas')) {
      return 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400&h=400&fit=crop';
    }
    
    // Stationery related images
    if (normalizedType.contains('stationery') || normalizedType.contains('supplies') || normalizedType.contains('office supply')) {
      return 'https://images.unsplash.com/photo-1586953208448-b95a79798f07?w=400&h=400&fit=crop';
    }
    
    // Default fallback for Misc or unknown types
    return 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=400&h=400&fit=crop';
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Office':
        return Colors.blue;
      case 'Travel':
        return Colors.orange;
      case 'Marketing':
        return Colors.purple;
      case 'Maintenance':
        return Colors.green;
      case 'Misc':
        return Colors.grey;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData? _getTypeIcon(String type) {
    switch (type) {
      case 'Office':
        return Icons.business_outlined;
      case 'Travel':
        return Icons.flight_outlined;
      case 'Marketing':
        return Icons.campaign_outlined;
      case 'Maintenance':
        return Icons.build_outlined;
      case 'Misc':
        return Icons.category_outlined;
      default:
        return null;
    }
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Image (Optional)',
          style: AppTheme.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (_selectedImageBytes != null || _selectedImage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb && _selectedImageBytes != null
                      ? Image.memory(
                          _selectedImageBytes!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        )
                      : _selectedImage != null
                          ? Image.file(
                              _selectedImage!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            )
                          : const SizedBox.shrink(),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                          _selectedImageBytes = null;
                          _selectedImagePath = null;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _currentImageUrl!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: AppTheme.backgroundColor,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: AppTheme.backgroundColor,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _currentImageUrl = null;
                        });
                      },
                      tooltip: 'Remove image',
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        if (kIsWeb) {
          // For web, read as bytes
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImagePath = image.path;
            _selectedImage = null;
            _currentImageUrl = null; // Clear existing URL when new image is selected
          });
        } else {
          // For mobile/desktop, use File
          setState(() {
            _selectedImage = File(image.path);
            _selectedImagePath = image.path;
            _selectedImageBytes = null;
            _currentImageUrl = null; // Clear existing URL when new image is selected
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Name *',
          style: AppTheme.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Enter expense type name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.borderColor.withValues(alpha: 0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.borderColor.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.errorColor,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.errorColor,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: AppTheme.backgroundColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: AppTheme.bodyMedium,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Name is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: AppTheme.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter description (optional)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.borderColor.withValues(alpha: 0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.borderColor.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: AppTheme.backgroundColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: AppTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildStatusSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: AppTheme.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isActive ? 'Active' : 'Inactive',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isActive,
            onChanged: _isSubmitting ? null : (bool value) {
                setState(() {
                  _isActive = value;
                });
            },
            activeColor: AppTheme.secondaryColor,
            activeTrackColor: AppTheme.secondaryColor.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildProofRequirementSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Proof',
                  style: AppTheme.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isProofRequired ? 'Mandatory' : 'Optional',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _isSubmitting ? null : () {
              setState(() {
                _isProofRequired = !_isProofRequired;
              });
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: _isProofRequired 
                  ? AppTheme.secondaryColor.withOpacity(0.1)
                  : AppTheme.backgroundColor,
              foregroundColor: _isProofRequired 
                  ? AppTheme.secondaryColor
                  : AppTheme.textSecondary,
              side: BorderSide(
                color: _isProofRequired 
                    ? AppTheme.secondaryColor
                    : AppTheme.borderColor.withValues(alpha: 0.5),
                width: _isProofRequired ? 2 : 1,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isProofRequired ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _isProofRequired ? 'Mandatory' : 'Optional',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSubmitting
                ? null
                : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: BorderSide(
                color: AppTheme.borderColor.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cancel',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
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
                : Text(
                    'Save Changes',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: _isSubmitting ? null : _handleDelete,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
            side: BorderSide(
              color: AppTheme.errorColor.withValues(alpha: 0.5),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Icon(Icons.delete_outline, size: 20),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (_isSubmitting) return;
    final currentState = _formKey.currentState;
    if (currentState != null && !currentState.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final expenseTypeId = widget.expenseType['id'] ?? widget.expenseType['_id'];
      
      if (expenseTypeId == null) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invalid expense type ID'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      String? imageUrl;
      
      // Upload new image if selected
      if (_selectedImagePath != null) {
        final uploadResult = await ExpenseTypeService.uploadImage(
          _selectedImagePath!,
          imageBytes: _selectedImageBytes,
          fileName: 'expense-type-${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        if (uploadResult['success'] == true) {
          imageUrl = uploadResult['imageUrl']?.toString();
        } else {
          if (!mounted) return;
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(uploadResult['message'] ?? 'Failed to upload image'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }
      } else if (_currentImageUrl == null || _currentImageUrl!.isEmpty) {
        // If image was removed, set to empty string
        imageUrl = '';
      } else {
        // Keep existing image URL
        imageUrl = _currentImageUrl;
      }
      
      final result = await ExpenseTypeService.updateExpenseType(
        expenseTypeId.toString(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        isActive: _isActive,
        imageUrl: imageUrl,
        proofRequired: _isProofRequired,
      );

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      if (result['success'] == true) {
        Navigator.of(context).pop({
          'event': 'updated',
          'expenseType': result['expenseType'],
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update expense type'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating expense type: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
    if (_isSubmitting) return;

    // Show confirmation dialog
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense Type'),
        content: Text(
          'Are you sure you want to delete "${_nameController.text}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete != true) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final expenseTypeId = widget.expenseType['id'] ?? widget.expenseType['_id'];
      
      if (expenseTypeId == null) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invalid expense type ID'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      final result = await ExpenseTypeService.deleteExpenseType(expenseTypeId.toString());

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      if (result['success'] == true) {
        Navigator.of(context).pop({
          'event': 'deleted',
          'expenseType': widget.expenseType,
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to delete expense type'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting expense type: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

