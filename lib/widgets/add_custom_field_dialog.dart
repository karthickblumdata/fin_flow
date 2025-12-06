import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/custom_field_service.dart';

class AddCustomFieldDialog extends StatefulWidget {
  final VoidCallback? onSuccess;
  final Map<String, dynamic>? customField;

  const AddCustomFieldDialog({
    super.key,
    this.onSuccess,
    this.customField,
  });

  @override
  State<AddCustomFieldDialog> createState() => _AddCustomFieldDialogState();
}

class _AddCustomFieldDialogState extends State<AddCustomFieldDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fieldNameController = TextEditingController();
  bool _isSubmitting = false;
  String? _userName;
  bool _isActive = true;
  bool get _isEditMode => widget.customField != null;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    if (_isEditMode && widget.customField != null) {
      _fieldNameController.text = widget.customField!['name']?.toString() ?? '';
      _isActive = widget.customField!['isActive'] ?? true;
    }
  }

  @override
  void dispose() {
    _fieldNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    try {
      final userName = await AuthService.getUserName();
      if (mounted) {
        setState(() {
          _userName = userName;
        });
      }
    } catch (e) {
      // Ignore error
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

      try {
        Map<String, dynamic> result;
        
        if (_isEditMode && widget.customField != null) {
          final customFieldId = widget.customField!['id']?.toString() ?? '';
          result = await CustomFieldService.updateCustomField(
            customFieldId,
            name: _fieldNameController.text.trim(),
            isActive: _isActive,
          );
        } else {
          result = await CustomFieldService.createCustomField(
            name: _fieldNameController.text.trim(),
            isActive: _isActive,
          );
        }

        if (mounted) {
          if (result['success'] == true) {
            Navigator.of(context).pop();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? (_isEditMode
                    ? 'Custom field "${_fieldNameController.text}" updated successfully'
                    : 'Custom field "${_fieldNameController.text}" added successfully')),
                backgroundColor: AppTheme.secondaryColor,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );

            widget.onSuccess?.call();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Error saving custom field'),
                backgroundColor: AppTheme.errorColor,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
            setState(() {
              _isSubmitting = false;
            });
          }
        }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding custom field: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 24 : 32,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isMobile),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFieldNameField(isMobile),
                      if (_isEditMode) ...[
                        SizedBox(height: isMobile ? 20 : 24),
                        _buildActiveToggle(isMobile),
                      ],
                      SizedBox(height: isMobile ? 20 : 24),
                      _buildActionButtons(isMobile),
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

  Widget _buildHeader(bool isMobile) {
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.add_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isEditMode ? 'Edit Custom Field' : 'Add Custom Field',
                    style: AppTheme.headingSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (_userName != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
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
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.add_outlined,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Add Custom Field',
                style: AppTheme.headingSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            if (_userName != null) ...[
              Icon(
                Icons.person_outline,
                size: 14,
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
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            IconButton(
              onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFieldNameField(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Field Name *',
          style: AppTheme.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _fieldNameController,
          enabled: !_isSubmitting,
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Enter field name...',
            hintStyle: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary.withValues(alpha: 0.6),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppTheme.borderColor.withValues(alpha: 0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppTheme.borderColor.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppTheme.errorColor,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppTheme.errorColor,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isMobile ? 14 : 16,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Field name is required';
            }
            if (value.trim().length < 2) {
              return 'Field name must be at least 2 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildActiveToggle(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Active',
            style: AppTheme.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Switch(
          value: _isActive,
          onChanged: _isSubmitting ? null : (value) {
            setState(() {
              _isActive = value;
            });
          },
          activeColor: AppTheme.secondaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          _isActive ? 'Enabled' : 'Disabled',
          style: AppTheme.bodySmall.copyWith(
            color: _isActive 
                ? AppTheme.secondaryColor 
                : AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: BorderSide(
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: isMobile ? 14 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submitForm,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: isMobile ? 14 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isSubmitting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _isEditMode ? 'Update Field' : 'Add Field',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

