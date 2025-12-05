import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RoleSelectorField extends StatelessWidget {
  const RoleSelectorField({
    super.key,
    required this.isLoading,
    required this.roles,
    required this.selectedRole,
    required this.onRoleChanged,
    this.enabled = true,
    this.helperText,
  });

  final bool isLoading;
  final List<String> roles;
  final String? selectedRole;
  final ValueChanged<String?> onRoleChanged;
  final bool enabled;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return TextFormField(
        decoration: const InputDecoration(
          labelText: 'Role',
          hintText: 'Loading roles...',
          suffixIcon: Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        enabled: false,
      );
    }

    if (roles.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Role',
              hintText: 'No roles available',
              errorText: 'Please create roles first in the Roles screen',
            ),
            enabled: false,
          ),
          const SizedBox(height: 8),
          Text(
            'No roles found. Please create roles in the Roles screen first.',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.errorColor,
            ),
          ),
        ],
      );
    }

    return FormField<String>(
      initialValue: selectedRole,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a role.';
        }
        if (value.toLowerCase() == 'superadmin') {
          return 'SuperAdmin role cannot be assigned.';
        }
        return null;
      },
      builder: (field) {
        final theme = Theme.of(context);
        final Color borderColor =
            field.hasError ? AppTheme.errorColor : AppTheme.borderColor;
        final List<String> roleOptions = List<String>.from(roles);
        final String? currentValue = field.value;
        if (currentValue != null &&
            currentValue.isNotEmpty &&
            !roleOptions.contains(currentValue)) {
          roleOptions.insert(0, currentValue);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Role',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: currentValue?.isNotEmpty == true ? currentValue : null,
                    hint: Text(
                      'Select role',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: AppTheme.textSecondary),
                    borderRadius: BorderRadius.circular(16),
                    dropdownColor: Colors.white,
                    underline: const SizedBox.shrink(),
                    items: roleOptions.map((role) {
                      return DropdownMenuItem<String>(
                        value: role,
                        child: Row(
                          children: [
                            Icon(
                              Icons.badge_outlined,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                role,
                                style: AppTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: !enabled
                        ? null
                        : (value) {
                            field.didChange(value);
                            onRoleChanged(value);
                          },
                    menuMaxHeight: 280,
                    style: AppTheme.bodyMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              helperText ?? 'Select an existing role created in the Roles screen.',
              style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ) ??
                  AppTheme.bodySmall.copyWith(color: AppTheme.textMuted),
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  field.errorText ?? '',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.errorColor,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

