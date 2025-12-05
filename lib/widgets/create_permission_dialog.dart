import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/permission_service.dart';

class CreatePermissionDialog extends StatefulWidget {
  const CreatePermissionDialog({super.key});

  @override
  State<CreatePermissionDialog> createState() => _CreatePermissionDialogState();
}

class _CreatePermissionDialogState extends State<CreatePermissionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _permissionIdController = TextEditingController();
  final _labelController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  
  bool _isSubmitting = false;

  @override
  void dispose() {
    _permissionIdController.dispose();
    _labelController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (_isSubmitting) return;
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await PermissionService.createPermission(
        permissionId: _permissionIdController.text.trim(),
        label: _labelController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.of(context).pop({
          'success': true,
          'permission': result['permission'],
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to create permission'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating permission: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: isMobile ? double.infinity : 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Create New Permission',
                      style: AppTheme.headingMedium.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Permission ID
              TextFormField(
                controller: _permissionIdController,
                decoration: InputDecoration(
                  labelText: 'Permission ID *',
                  hintText: 'e.g., custom.feature.create',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.tag),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Permission ID is required';
                  }
                  if (!RegExp(r'^[a-z0-9._]+$').hasMatch(value.trim())) {
                    return 'Permission ID must contain only lowercase letters, numbers, dots, and underscores';
                  }
                  return null;
                },
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 16),
              
              // Label
              TextFormField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: 'Label *',
                  hintText: 'e.g., Create Custom Feature',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Label is required';
                  }
                  return null;
                },
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Permission to create custom features',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 16),
              
              // Category
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'Category *',
                  hintText: 'e.g., custom, wallet, dashboard',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Category is required';
                  }
                  return null;
                },
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting 
                        ? null 
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleCreate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Create Permission'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

