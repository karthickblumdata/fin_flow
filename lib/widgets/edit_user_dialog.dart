import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/role_service.dart';
import '../services/api_service.dart';
import '../services/pincode_service.dart';
import '../utils/api_constants.dart';
import '../utils/profile_image_helper.dart';
import '../utils/permission_tree_builder.dart';
import '../models/permission_node.dart';
import '../widgets/hierarchical_checkbox.dart';
import '../widgets/permission_preview_widget.dart';
import 'role_selector_field.dart';
import 'dart:async';

class EditUserDialog extends StatefulWidget {
  const EditUserDialog({
    super.key,
    required this.user,
  });

  final Map<String, dynamic> user;

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _DismissDialogIntent extends Intent {
  const _DismissDialogIntent();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneNumberController;
  late final TextEditingController _countryCodeController;
  late final TextEditingController _dateOfBirthController;
  late final TextEditingController _addressController;
  late final TextEditingController _addressLine2Controller;
  late final TextEditingController _stateController;
  late final TextEditingController _placeController;
  late final TextEditingController _districtController;
  late final TextEditingController _pinCodeController;
  late final TextEditingController _roleController;
  late String _selectedRole;
  List<String> _availableRoles = [];
  bool _isLoadingRoles = false;
  late bool _isActive;
  late String _phoneFieldKey;
  late String _countryCodeFieldKey;
  late String _dobFieldKey;
  late String _addressFieldKey;
  late String _addressLine2FieldKey;
  late String _stateFieldKey;
  late String _placeFieldKey;
  late String _districtFieldKey;
  late String _pinCodeFieldKey;
  bool _isLoadingState = false;
  Timer? _pincodeDebounceTimer;
  bool _isNonWalletUser = false;
  bool _emailHasInput = false;
  bool _emailIsValid = false;
  DateTime? _selectedDateOfBirth;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  List<String> _selectedPermissions = [];
  List<String> _userCurrentPermissions = [];
  bool _isLoadingPermissions = false;

  Uint8List? _imageBytes;
  String? _imageUrl;
  bool _isSubmitting = false;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _readString(widget.user['name']));
    _emailController = TextEditingController(text: _readString(widget.user['email']));
    _emailHasInput = _emailController.text.trim().isNotEmpty;
    _emailIsValid = _isValidEmail(_emailController.text.trim());
    _emailController.addListener(_handleEmailChanged);
    final phoneResolution = _resolveField(
      widget.user,
      const ['phoneNumber', 'phone', 'contactNumber', 'mobile', 'mobileNumber'],
      fallbackKey: 'phoneNumber',
    );
    _phoneFieldKey = phoneResolution.key;
    _phoneNumberController = TextEditingController(text: phoneResolution.value);
    final countryCodeResolution = _resolveField(
      widget.user,
      const ['countryCode', 'dialCode', 'phoneCode', 'countryDialCode'],
      fallbackKey: 'countryCode',
    );
    _countryCodeFieldKey = countryCodeResolution.key;
    _countryCodeController = TextEditingController(text: countryCodeResolution.value);
    final dobResolution = _resolveField(
      widget.user,
      const ['dateOfBirth', 'dob', 'birthDate', 'birth_day'],
      fallbackKey: 'dateOfBirth',
    );
    _dobFieldKey = dobResolution.key;
    _selectedDateOfBirth = _parseDate(dobResolution.value);
    // Format date properly - if parsed successfully, use formatted date, otherwise try to show the raw value
    String dobText;
    if (_selectedDateOfBirth != null) {
      dobText = _dateFormat.format(_selectedDateOfBirth!);
    } else if (dobResolution.value.isNotEmpty) {
      // If we have a value but couldn't parse it, try one more time with different approach
      // Sometimes dates come as ISO timestamp or other formats from backend
      try {
        // Try parsing as ISO date string (most common from backend: "2004-12-20T00:00:00.000Z")
        final value = dobResolution.value.trim();
        
        // First, try DateTime.parse for ISO strings (handles full ISO format with time)
        try {
          final isoDate = DateTime.parse(value);
          _selectedDateOfBirth = isoDate;
          dobText = _dateFormat.format(isoDate);
        } catch (_) {
          // If ISO parse fails, try manual parsing for date-only formats
          if (value.contains('-') && value.length >= 8) {
            // Handle formats like "2004-12-20" or "2004-12-20T00:00:00.000Z"
            final datePart = value.split('T')[0]; // Get date part before 'T' if present
            final parts = datePart.split('-');
            if (parts.length >= 3) {
              final year = int.tryParse(parts[0]);
              final month = int.tryParse(parts[1]);
              final day = int.tryParse(parts[2]);
              if (year != null && month != null && day != null && 
                  year > 1900 && year < 2100 && 
                  month >= 1 && month <= 12 && 
                  day >= 1 && day <= 31) {
                _selectedDateOfBirth = DateTime(year, month, day);
                dobText = _dateFormat.format(_selectedDateOfBirth!);
              } else {
                dobText = value;
              }
            } else {
              dobText = value;
            }
          } else {
            dobText = value;
          }
        }
      } catch (e) {
        // If all parsing fails, show the raw value
        dobText = dobResolution.value;
      }
    } else {
      dobText = '';
    }
    _dateOfBirthController = TextEditingController(text: dobText);
    final addressResolution = _resolveField(
      widget.user,
      const ['address', 'homeAddress', 'residentialAddress', 'mailingAddress'],
      fallbackKey: 'address',
    );
    _addressFieldKey = addressResolution.key;
    _addressController = TextEditingController(text: addressResolution.value);
    final addressLine2Resolution = _resolveField(
      widget.user,
      const [
        'addressLine2',
        'address2',
        'residentialAddressLine2',
        'mailingAddressLine2',
        'streetAddressLine2',
        'apartment',
        'suite',
        'unit',
      ],
      fallbackKey: 'addressLine2',
    );
    _addressLine2FieldKey = addressLine2Resolution.key;
    _addressLine2Controller = TextEditingController(text: addressLine2Resolution.value);
    final pinCodeResolution = _resolveField(
      widget.user,
      const ['pinCode', 'postalCode', 'zipCode', 'zip', 'pincode'],
      fallbackKey: 'pinCode',
    );
    _pinCodeFieldKey = pinCodeResolution.key;
    _pinCodeController = TextEditingController(text: pinCodeResolution.value);
    // Add listener to PINCODE field to auto-load state, place, and district
    _pinCodeController.addListener(_handlePincodeChanged);
    
    final stateResolution = _resolveField(
      widget.user,
      const ['state', 'stateProvince', 'province', 'region', 'stateName'],
      fallbackKey: 'state',
    );
    _stateFieldKey = stateResolution.key;
    _stateController = TextEditingController(text: stateResolution.value);

    final placeResolution = _resolveField(
      widget.user,
      const ['place', 'city', 'town', 'postOffice'],
      fallbackKey: 'place',
    );
    _placeFieldKey = placeResolution.key;
    _placeController = TextEditingController(text: placeResolution.value);

    final districtResolution = _resolveField(
      widget.user,
      const ['district', 'dist'],
      fallbackKey: 'district',
    );
    _districtFieldKey = districtResolution.key;
    _districtController = TextEditingController(text: districtResolution.value);
    _selectedRole = _readString(widget.user['role'], fallback: 'Staff');
    _roleController = TextEditingController(text: _selectedRole);
    _isActive = _normalizeStatus(widget.user['status']) == 'active' ||
        (widget.user['isVerified'] is bool && widget.user['isVerified'] == true);
    // Check if user is non-wallet user
    // Priority: First check isNonWalletUser field (most reliable), then check wallet object
    final isNonWalletUserField = widget.user['isNonWalletUser'];
    
    // Check if field exists and has a value (safe check for Flutter web)
    final hasField = widget.user.containsKey('isNonWalletUser');
    
    if (hasField && isNonWalletUserField != null) {
      // Backend explicitly sets isNonWalletUser field
      // Handle different types: bool, String, int (1/0)
      if (isNonWalletUserField is bool) {
        _isNonWalletUser = isNonWalletUserField;
      } else if (isNonWalletUserField is String) {
        final strValue = isNonWalletUserField.toString().toLowerCase().trim();
        _isNonWalletUser = strValue == 'true' || strValue == '1';
      } else if (isNonWalletUserField is int) {
        _isNonWalletUser = isNonWalletUserField == 1;
      } else if (isNonWalletUserField is num) {
        _isNonWalletUser = isNonWalletUserField == 1 || isNonWalletUserField == 1.0;
      } else {
        // Fallback: treat as false if type is unexpected
        _isNonWalletUser = false;
      }
    } else {
      // Fallback: Check if wallet exists (for backward compatibility)
      // Wallet can be null, undefined, or wallet object might not exist
      final wallet = widget.user['wallet'];
      final hasWallet = wallet != null && 
                        wallet is Map && 
                        wallet.isNotEmpty &&
                        widget.user['hasWallet'] != false;
      _isNonWalletUser = !hasWallet;
    }
    _imageUrl = _extractImageUrl(widget.user);
    
    // Try to get permissions from user object first (if available)
    final userPermissions = widget.user['userSpecificPermissions'] as List<dynamic>?;
    if (userPermissions != null && userPermissions.isNotEmpty) {
      final permissionsList = userPermissions
          .map((p) => p.toString().trim())
          .where((p) => p.isNotEmpty && p != 'root' && p.toLowerCase() != 'root')
          .toList();
      _userCurrentPermissions = permissionsList;
      _selectedPermissions = List<String>.from(permissionsList);
      print('✅ Loaded ${permissionsList.length} permissions from user object: $permissionsList');
    }
    
    _loadUserInfo();
    _loadAvailableRoles();
    _loadUserPermissions();
  }

  Future<void> _loadUserPermissions() async {
    if (_isLoadingPermissions) return;
    
    final userId = widget.user['_id']?.toString() ?? widget.user['id']?.toString();
    if (userId == null || userId.isEmpty) {
      print('⚠️ Cannot load permissions: User ID is null or empty');
      return;
    }

    print('🔐 Loading user permissions for user ID: $userId');
    setState(() {
      _isLoadingPermissions = true;
    });

    try {
      final result = await PermissionService.getUserPermissions(userId);
      print('📥 Permission API Response: ${result['success']}');
      print('📥 Response keys: ${result.keys.toList()}');
      
      if (mounted && result['success'] == true) {
        // Get user-specific permissions (not role permissions)
        final permissionIds = result['permissionIds'];
        print('📥 permissionIds type: ${permissionIds.runtimeType}');
        print('📥 permissionIds: $permissionIds');
        
        final userSpecificPermissions = permissionIds?['userSpecificPermissions'] as List<dynamic>? ?? [];
        print('📥 Raw userSpecificPermissions: $userSpecificPermissions');
        print('📥 userSpecificPermissions count: ${userSpecificPermissions.length}');
        
        final permissionsList = userSpecificPermissions
            .map((p) => p.toString().trim())
            .where((p) => p.isNotEmpty && p != 'root' && p.toLowerCase() != 'root')
            .toList();
        
        print('✅ Processed permissions list: $permissionsList');
        print('✅ Processed permissions count: ${permissionsList.length}');
        
        setState(() {
          // Always update with API response (it's the source of truth)
          _userCurrentPermissions = permissionsList;
          _selectedPermissions = List<String>.from(permissionsList); // Initialize with current permissions
          _isLoadingPermissions = false;
        });
        
        print('✅ Permissions loaded and set in state');
        print('✅ Final _selectedPermissions: $_selectedPermissions');
        print('✅ Final _selectedPermissions count: ${_selectedPermissions.length}');
      } else {
        print('❌ Failed to load permissions: ${result['message'] ?? 'Unknown error'}');
        if (mounted) {
          setState(() {
            _isLoadingPermissions = false;
          });
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error loading user permissions: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoadingPermissions = false;
        });
      }
    }
  }

  Future<void> _loadUserInfo() async {
    final userName = await AuthService.getUserName();
    if (mounted) {
      setState(() {
        _userName = userName;
      });
    }
  }

  Future<void> _loadAvailableRoles() async {
    if (_isLoadingRoles) return;

    setState(() {
      _isLoadingRoles = true;
    });

    try {
      final result = await RoleService.getAllRoles();
      if (!mounted) return;

      if (result['success'] == true) {
        final roles = result['roles'] as List<dynamic>? ?? [];
        final roleNames = roles
            .map((role) {
              final roleName = role['roleName']?.toString().trim() ??
                  role['name']?.toString().trim() ??
                  role['role']?.toString().trim() ??
                  '';
              return roleName;
            })
            .where((name) => name.isNotEmpty)
            .where((name) => name.toLowerCase() != 'superadmin')
            .toSet()
            .toList()
          ..sort();

        setState(() {
          _availableRoles = roleNames;
          _isLoadingRoles = false;
        });
      } else {
        setState(() {
          _isLoadingRoles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRoles = false;
        });
      }
    }
  }

  void _handlePincodeChanged() {
    // Cancel previous timer
    _pincodeDebounceTimer?.cancel();
    
    final pincode = _pinCodeController.text.trim();
    
    // Only fetch if pincode is exactly 6 digits
    if (pincode.length == 6) {
      // Debounce: Wait 500ms after user stops typing
      _pincodeDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        _fetchStateFromPincode(pincode);
      });
    }
  }

  Future<void> _fetchStateFromPincode(String pincode) async {
    if (pincode.length != 6) return;
    
    setState(() {
      _isLoadingState = true;
    });

    try {
      final result = await PincodeService.getStateFromPincode(pincode);
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        final state = result['state']?.toString() ?? '';
        final place = result['place']?.toString() ?? '';
        final district = result['district']?.toString() ?? '';
        
        if (state.isNotEmpty) {
          _stateController.text = state;
        }
        if (place.isNotEmpty) {
          _placeController.text = place;
        }
        if (district.isNotEmpty) {
          _districtController.text = district;
        }
      } else {
        // Don't show error, just silently fail
        // User can manually enter state, place, and district
      }
    } catch (e) {
      // Silently handle error
      print('Error fetching state, place, and district from pincode: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingState = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.removeListener(_handleEmailChanged);
    _emailController.dispose();
    _phoneNumberController.dispose();
    _countryCodeController.dispose();
    _dateOfBirthController.dispose();
    _addressController.dispose();
    _addressLine2Controller.dispose();
    _stateController.dispose();
    _placeController.dispose();
    _districtController.dispose();
    _pincodeDebounceTimer?.cancel();
    _pinCodeController.removeListener(_handlePincodeChanged);
    _pinCodeController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): const _DismissDialogIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _DismissDialogIntent: CallbackAction<_DismissDialogIntent>(
            onInvoke: (intent) {
              _handleClose();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 760,
              maxHeight: maxHeight,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
            _buildHeader(context),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final theme = Theme.of(context);
                                  final bool isWide = constraints.maxWidth >= 600;

                                  final Widget sectionHeader = _buildSectionHeader(
                                    context,
                                    icon: Icons.badge_outlined,
                                    title: 'Basic Details',
                                    subtitle: 'Keep the user\'s profile up to date.',
                                  );

                                  final Widget narrowHeader = Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      sectionHeader,
                                    ],
                                  );

                                  final String trimmedCountryCode =
                                      _countryCodeController.text.trim().isEmpty
                                          ? '+91'
                                          : _countryCodeController.text.trim();
                                  if (_countryCodeController.text != trimmedCountryCode) {
                                    _countryCodeController.text = trimmedCountryCode;
                                  }
                                  final TextStyle? countryTextStyle =
                                      theme.textTheme.bodyMedium;

                                  final Widget countryCodeField = IgnorePointer(
                                    ignoring: _isSubmitting,
                                    child: SizedBox(
                                      height: 56,
                                      child: _CountryCodeSelectorField(
                                        countryTextStyle: countryTextStyle,
                                        controller: _countryCodeController,
                                      ),
                                    ),
                                  );

                                  final Widget phoneNumberField = TextFormField(
                                    controller: _phoneNumberController,
                                    enabled: !_isSubmitting,
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Phone Number',
                                      hintText: 'Enter phone number',
                                    ),
                                    validator: (value) {
                                      final trimmed = (value ?? '').trim();
                                      if (trimmed.isEmpty) {
                                        return 'Please enter the phone number.';
                                      }
                                      if (trimmed.length != 10) {
                                        return 'Phone number must be 10 digits.';
                                      }
                                      return null;
                                    },
                                  );

                                  final Widget roleField = Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      RoleSelectorField(
                                        isLoading: _isLoadingRoles,
                                        roles: _availableRoles,
                                        selectedRole: _selectedRole,
                                        enabled: !_isSubmitting,
                                        helperText: 'Update the user\'s role as needed.',
                                        onRoleChanged: (value) {
                                          setState(() {
                                            _selectedRole = value ?? '';
                                            _roleController.text = value ?? '';
                                            // Don't clear permissions when role changes - keep existing ones
                                            // _selectedPermissions = [];
                                          });
                                        },
                                      ),
                                      if (_selectedRole.isNotEmpty && _selectedRole.toLowerCase() != 'superadmin') ...[
                                        const SizedBox(height: 12),
                                        ElevatedButton.icon(
                                          onPressed: (_isSubmitting || _isLoadingPermissions) ? null : () async {
                                            // Wait for permissions to load if still loading
                                            while (_isLoadingPermissions && mounted) {
                                              await Future.delayed(const Duration(milliseconds: 100));
                                            }
                                            if (mounted) {
                                              await _showRolePermissionDialog(_selectedRole);
                                            }
                                          },
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          label: Text(
                                            _selectedPermissions.isNotEmpty
                                                ? 'Edit Permission (${_selectedPermissions.length} selected)'
                                                : 'Edit Permission',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  );

                                  final Widget contactInputs = isWide
                                      ? Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(width: 140, child: countryCodeField),
                                            const SizedBox(width: 12),
                                            Expanded(child: phoneNumberField),
                                          ],
                                        )
                                      : Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            countryCodeField,
                                            const SizedBox(height: 12),
                                            phoneNumberField,
                                          ],
                                        );

                                  final Widget nameField = TextFormField(
                                    controller: _nameController,
                                    textInputAction: TextInputAction.next,
                                    enabled: !_isSubmitting,
                                    decoration: const InputDecoration(
                                      labelText: 'Name',
                                      hintText: 'Enter full name',
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter the name.';
                                      }
                                      if (value.trim().length < 3) {
                                        return 'Name must be at least 3 characters.';
                                      }
                                      return null;
                                    },
                                  );

                                  final Widget emailField = TextFormField(
                                    controller: _emailController,
                                    enabled: !_isSubmitting,
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      hintText: 'Enter email address',
                                      suffixIcon: !_emailHasInput
                                          ? null
                                          : Icon(
                                              _emailIsValid ? Icons.check_circle : Icons.error_outline,
                                              color: _emailIsValid
                                                  ? AppTheme.secondaryColor
                                                  : AppTheme.errorColor,
                                            ),
                                    ),
                                    validator: (value) {
                                      final String trimmed = (value ?? '').trim();
                                      if (trimmed.isEmpty) {
                                        return 'Please enter the email address.';
                                      }
                                      if (!_isValidEmail(trimmed)) {
                                        return 'Please enter a valid email address.';
                                      }
                                      return null;
                                    },
                                  );

                                  final List<Widget> nameEmailGroup = [
                                    nameField,
                                    const SizedBox(height: 16),
                                    emailField,
                                  ];

                                  final Widget dateField = TextFormField(
                                    controller: _dateOfBirthController,
                                    enabled: !_isSubmitting,
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Date of Birth',
                                      hintText: 'Select date of birth (optional)',
                                      suffixIcon: Icon(Icons.calendar_today_outlined),
                                    ),
                                    onTap: _isSubmitting ? null : _handleDateOfBirthTap,
                                    // Date of birth is optional in edit mode
                                  );

                                  final Widget addressField = TextFormField(
                                    controller: _addressController,
                                    enabled: !_isSubmitting,
                                    textInputAction:
                                        isWide ? TextInputAction.next : TextInputAction.newline,
                                    keyboardType: TextInputType.streetAddress,
                                    maxLines: isWide ? 2 : 3,
                                    minLines: 1,
                                    decoration: const InputDecoration(
                                      labelText: 'Address Line 1',
                                      hintText: 'Enter address line 1',
                                    ),
                                  );

                                  final Widget addressLine2Field = TextFormField(
                                    controller: _addressLine2Controller,
                                    enabled: !_isSubmitting,
                                    textInputAction:
                                        isWide ? TextInputAction.next : TextInputAction.newline,
                                    keyboardType: TextInputType.streetAddress,
                                    maxLines: isWide ? 2 : 3,
                                    minLines: 1,
                                    decoration: const InputDecoration(
                                      labelText: 'Address Line 2',
                                      hintText: 'Enter address line 2',
                                    ),
                                  );

                                  final Widget pinCodeField = TextFormField(
                                    controller: _pinCodeController,
                                    enabled: !_isSubmitting,
                                    textInputAction: TextInputAction.done,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'PIN Code',
                                      hintText: 'Enter PIN code',
                                      suffixIcon: _isLoadingState
                                          ? const Padding(
                                              padding: EdgeInsets.all(12.0),
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                  );

                                  final Widget stateField = TextFormField(
                                    controller: _stateController,
                                    enabled: !_isSubmitting,
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      labelText: 'State',
                                      hintText: _isLoadingState ? 'Loading...' : 'Enter state',
                                      helperText: _pinCodeController.text.length == 6
                                          ? 'State, Place, and District will be auto-filled from PIN code'
                                          : null,
                                    ),
                                  );

                                  final Widget placeField = TextFormField(
                                    controller: _placeController,
                                    enabled: !_isSubmitting,
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      labelText: 'Place',
                                      hintText: _isLoadingState ? 'Loading...' : 'Enter place',
                                    ),
                                  );

                                  final Widget districtField = TextFormField(
                                    controller: _districtController,
                                    enabled: !_isSubmitting,
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      labelText: 'District',
                                      hintText: _isLoadingState ? 'Loading...' : 'Enter district',
                                    ),
                                  );

                                  final Widget addressGroup = Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      addressField,
                                      const SizedBox(height: 16),
                                      addressLine2Field,
                                    ],
                                  );

                                  // State moved to left column, PIN Code stays in right sidebar for desktop

                                  final Widget leftColumn = Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      ...nameEmailGroup,
                                      const SizedBox(height: 16),
                                      contactInputs,
                                      const SizedBox(height: 16),
                                      dateField,
                                      const SizedBox(height: 24),
                                      addressGroup,
                                      const SizedBox(height: 16),
                                      placeField,
                                      const SizedBox(height: 16),
                                      districtField,
                                      const SizedBox(height: 16),
                                    ],
                                  );

                                  // Desktop avatar panel (with PIN Code only)
                                  final Widget avatarPanelDesktop = Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Align(
                                        alignment: Alignment.center,
                                        child: _buildAvatarPicker(),
                                      ),
                                      const SizedBox(height: 24),
                                      roleField,
                                      const SizedBox(height: 24),
                                      _buildStatusSelector(context),
                                      const SizedBox(height: 24),
                                      _buildNonWalletUserToggle(context),
                                      const SizedBox(height: 32),
                                      pinCodeField,
                                      const SizedBox(height: 16),
                                      stateField,
                                    ],
                                  );

                                  // Mobile avatar panel (without State and PIN Code)
                                  final Widget avatarPanelMobile = Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Align(
                                        alignment: Alignment.center,
                                        child: _buildAvatarPicker(),
                                      ),
                                      const SizedBox(height: 24),
                                      roleField,
                                      const SizedBox(height: 24),
                                      _buildStatusSelector(context),
                                      const SizedBox(height: 24),
                                      _buildNonWalletUserToggle(context),
                                    ],
                                  );

                                  final Widget formPanel = Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      leftColumn,
                                    ],
                                  );

                                  if (isWide) {
                                    return Row(
                                      key: const ValueKey('edit_user_wide_layout'),
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          key: const ValueKey('edit_user_form_expanded'),
                                          flex: 3,
                                          child: Column(
                                            key: const ValueKey('edit_user_form_column'),
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              sectionHeader,
                                              const SizedBox(height: 20),
                                              formPanel,
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        SizedBox(
                                          key: const ValueKey('edit_user_avatar_container'),
                                          width: 260,
                                          child: Column(
                                            key: const ValueKey('edit_user_avatar_column'),
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              avatarPanelDesktop,
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Column(
                                    key: const ValueKey('edit_user_narrow_layout'),
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      narrowHeader,
                                      const SizedBox(height: 20),
                                      avatarPanelMobile,
                                      const SizedBox(height: 16),
                                      formPanel,
                                      const SizedBox(height: 16),
                                      pinCodeField,
                                      const SizedBox(height: 16),
                                      stateField,
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Builder(
              builder: (context) {
                final isMobile = MediaQuery.of(context).size.width < 600;
                
                if (isMobile) {
                  // Mobile: Stack buttons vertically
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Primary actions row
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isSubmitting ? null : _handleSave,
                                icon: _isSubmitting
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.save_outlined, size: 18),
                                label: Text(_isSubmitting ? 'Saving...' : 'Save'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: _isSubmitting ? null : _handleSendInvite,
                                icon: const Icon(Icons.mail_outline, size: 18),
                                label: const Text('Resend'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Secondary actions row
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: _isSubmitting ? null : _handleClose,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: _isSubmitting ? null : _handleDelete,
                                icon: const Icon(Icons.delete_outline, size: 18),
                                label: const Text('Delete'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.errorColor,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                } else {
                  // Desktop: Keep horizontal layout
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: _isSubmitting ? null : _handleClose,
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _isSubmitting ? null : _handleDelete,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.errorColor,
                          ),
                        ),
                        const Spacer(),
                        FilledButton.tonalIcon(
                          onPressed: _isSubmitting ? null : _handleSendInvite,
                          icon: const Icon(Icons.mail_outline, size: 20),
                          label: const Text('Resend invite'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _isSubmitting ? null : _handleSave,
                          icon: _isSubmitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined, size: 20),
                          label: Text(_isSubmitting ? 'Saving...' : 'Save changes'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 16 : 20, isMobile ? 8 : 24, isMobile ? 12 : 16),
      child: isMobile
          ? // Mobile: Stack vertically
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.edit_outlined, color: AppTheme.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit User',
                            style: AppTheme.headingSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Update profile details and account access.',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isSubmitting ? null : _handleClose,
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                    ),
                  ],
                ),
                // Username badge below on mobile
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
                          horizontal: 8,
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
            )
          : // Desktop: Keep horizontal layout
          Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit User',
                        style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Update profile details and account access.',
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
                  onPressed: _isSubmitting ? null : _handleClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
    );
  }

  void _handleClose() {
    if (_isSubmitting || !mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Widget _buildAvatarPicker() {
    ImageProvider? provider;
    if (_imageBytes != null) {
      provider = MemoryImage(_imageBytes!);
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      provider = NetworkImage(_imageUrl!);
    }

    final double borderRadius = 16;

    final bool isActive = _isActive;
    final String bannerMessage = isActive ? 'ACTIVE' : 'INACTIVE';
    final Color bannerColor = isActive ? AppTheme.secondaryColor : AppTheme.errorColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double available = constraints.biggest.shortestSide.isFinite
            ? constraints.biggest.shortestSide
            : 120;
        final double dimension = available.clamp(80, 160);

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 80,
              minHeight: 80,
              maxWidth: dimension,
              maxHeight: dimension,
            ),
            child: AspectRatio(
              aspectRatio: 4 / 4,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: Banner(
                      message: bannerMessage,
                      color: bannerColor,
                      location: BannerLocation.topEnd,
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          border: Border.all(
                            color: AppTheme.borderColor.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                        child: provider != null
                            ? Image(
                                image: provider,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  final roleColor = _getRoleColor(_selectedRole);
                                  final initials = _getInitials(_nameController.text);
                                  return Container(
                                    color: roleColor.withValues(alpha: 0.12),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initials,
                                      style: AppTheme.headingSmall.copyWith(
                                        color: roleColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Builder(
                                builder: (context) {
                                  final roleColor = _getRoleColor(_selectedRole);
                                  final initials = _getInitials(_nameController.text);
                                  return Container(
                                    color: roleColor.withValues(alpha: 0.12),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initials,
                                      style: AppTheme.headingSmall.copyWith(
                                        color: roleColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Material(
                      color: AppTheme.primaryColor,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isSubmitting ? null : _pickImage,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.edit, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final XFile? result = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (result == null) return;
      final bytes = await result.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageUrl = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select image: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
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
      final userId = widget.user['id'] ?? widget.user['_id'];
      if (userId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User ID is missing'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      // Upload image if provided
      String? profileImageUrl;
      if (_imageBytes != null) {
        try {
          final uploadResult = await ApiService.uploadFile(
            ApiConstants.uploadUserProfileImage,
            '',
            'image',
            fileBytes: _imageBytes,
            fileName: 'profile-image.jpg',
          );
          
          if (uploadResult['success'] == true && uploadResult['imageUrl'] != null) {
            profileImageUrl = uploadResult['imageUrl'] as String;
          }
        } catch (e) {
          print('⚠️  Error uploading image: $e');
        }
      }

      // Format date of birth as ISO string (YYYY-MM-DD) if provided
      String? formattedDateOfBirth;
      if (_selectedDateOfBirth != null) {
        formattedDateOfBirth = _selectedDateOfBirth!.toIso8601String().split('T')[0];
      } else if (_dateOfBirthController.text.trim().isNotEmpty) {
        try {
          final parsedDate = _dateFormat.parse(_dateOfBirthController.text.trim());
          formattedDateOfBirth = parsedDate.toIso8601String().split('T')[0];
        } catch (e) {
          // If parsing fails, continue without date of birth
        }
      }

      // Call backend API to update user
      final result = await UserService.updateUser(
        userId: userId.toString(),
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: _roleController.text.trim(),
        profileImage: profileImageUrl,
        dateOfBirth: formattedDateOfBirth,
        address: _addressController.text.trim(),
        state: _stateController.text.trim(),
        place: _placeController.text.trim(),
        district: _districtController.text.trim(),
        pinCode: _pinCodeController.text.trim(),
        isVerified: _isActive,
        isNonWalletUser: _isNonWalletUser,
      );

      if (!mounted) return;

      // Update user permissions if they were changed
      if (_selectedPermissions.isNotEmpty || _userCurrentPermissions.isNotEmpty) {
        // Check if permissions actually changed
        final permissionsChanged = 
            _selectedPermissions.length != _userCurrentPermissions.length ||
            !_selectedPermissions.every((p) => _userCurrentPermissions.contains(p));
        
        if (permissionsChanged) {
          final permissionsResult = await UserService.updateUserPermissions(
            userId: userId.toString(),
            permissions: _selectedPermissions,
          );
          
          if (permissionsResult['success'] != true) {
            print('⚠️ Failed to update user permissions: ${permissionsResult['message']}');
            // Don't fail the entire update, just log the error
          }
        }
      }

      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update user'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      // Merge backend response with local fields for UI compatibility
      final updatedUser = Map<String, dynamic>.from(widget.user);
      updatedUser['name'] = _nameController.text.trim();
      updatedUser['email'] = _emailController.text.trim();
      updatedUser[_phoneFieldKey] = _phoneNumberController.text.trim();
      updatedUser[_countryCodeFieldKey] = _countryCodeController.text.trim();
      updatedUser[_dobFieldKey] = _dateOfBirthController.text.trim();
      updatedUser[_addressFieldKey] = _addressController.text.trim();
      updatedUser[_addressLine2FieldKey] = _addressLine2Controller.text.trim();
      updatedUser[_stateFieldKey] = _stateController.text.trim();
      updatedUser[_placeFieldKey] = _placeController.text.trim();
      updatedUser[_districtFieldKey] = _districtController.text.trim();
      updatedUser[_pinCodeFieldKey] = _pinCodeController.text.trim();
      updatedUser['role'] = _roleController.text.trim();
      updatedUser['status'] = _isActive ? 'Active' : 'Inactive';
      updatedUser['isVerified'] = _isActive;
      updatedUser['isNonWalletUser'] = _isNonWalletUser;
      // Use uploaded image URL if available, otherwise use API response, otherwise use existing
      if (profileImageUrl != null) {
        updatedUser['profileImage'] = profileImageUrl;
      } else if (result['user'] is Map<String, dynamic> && (result['user'] as Map<String, dynamic>)['profileImage'] != null) {
        updatedUser['profileImage'] = (result['user'] as Map<String, dynamic>)['profileImage'];
      } else if (_imageUrl != null) {
        updatedUser['profileImage'] = _imageUrl;
      }

      // Merge backend response data
      if (result['user'] is Map<String, dynamic>) {
        updatedUser.addAll(result['user'] as Map<String, dynamic>);
      }

      if (!mounted) return;
      Navigator.of(context).pop({
        'event': 'updated',
        'user': updatedUser,
        if (_imageBytes != null) 'imageBytes': _imageBytes,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _handleSendInvite() {
    if (_isSubmitting) {
      return;
    }
    Navigator.of(context).pop({
      'event': 'sendInvite',
      'userId': widget.user['id'] ?? widget.user['_id'],
      'email': _emailController.text.trim(),
    });
  }

  Future<void> _handleDelete() async {
    if (_isSubmitting) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user'),
        content: const Text('Are you sure you want to delete this user? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = widget.user['id'] ?? widget.user['_id'];
      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User ID not found'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      final result = await UserService.deleteUser(userId.toString());

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      if (result['success'] == true) {
        Navigator.of(context).pop({
          'event': 'deleted',
          'userId': userId,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'User deleted successfully'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to delete user'),
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
          content: Text('Failed to delete user: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _buildStatusSelector(BuildContext context) {
    final theme = Theme.of(context);
    final Color activeColor = AppTheme.secondaryColor;
    final Color inactiveColor = AppTheme.errorColor;
    final Color statusColor = _isActive ? activeColor : inactiveColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Account status',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: _isActive,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                activeColor: Colors.white,
                activeTrackColor: activeColor,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: inactiveColor.withValues(alpha: 0.7),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNonWalletUserToggle(BuildContext context) {
    final theme = Theme.of(context);
    const activeColor = AppTheme.primaryColor;
    final inactiveColor = AppTheme.textSecondary.withOpacity(0.3);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isNonWalletUser
              ? activeColor.withOpacity(0.3)
              : inactiveColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 18,
              color: _isNonWalletUser ? activeColor : inactiveColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Non Wallet User',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: _isNonWalletUser,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _isNonWalletUser = value;
                        });
                      },
                activeColor: Colors.white,
                activeTrackColor: activeColor,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: inactiveColor.withValues(alpha: 0.7),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDateOfBirthTap() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    final DateTime now = DateTime.now();
    final DateTime initialDate = _selectedDateOfBirth ??
        DateTime(
          now.year - 21,
          now.month,
          now.day,
        );
    final DateTime firstDate = DateTime(1900);
    final DateTime lastDate = DateTime(now.year, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(lastDate) ? lastDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dateOfBirthController.text = _dateFormat.format(picked);
      });
    }
  }

  DateTime? _parseDate(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    
    // First, try parsing as ISO string (handles full ISO format with time: "2004-12-20T00:00:00.000Z")
    try {
      return DateTime.parse(trimmed);
    } catch (_) {
      // ISO parse failed, continue to format-based parsing
    }
    
    // Try format-based parsing for common date formats
    final List<DateFormat> formats = <DateFormat>[
      _dateFormat, // 'dd/MM/yyyy'
      DateFormat('yyyy-MM-dd'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('yyyy/MM/dd'),
      DateFormat('dd-MM-yyyy'),
      DateFormat('MM-dd-yyyy'),
    ];
    for (final format in formats) {
      try {
        return format.parseStrict(trimmed);
      } catch (_) {
        continue;
      }
    }
    
    // If all parsing fails, try to extract date from ISO-like strings manually
    if (trimmed.contains('-') && trimmed.length >= 8) {
      try {
        final datePart = trimmed.split('T')[0].split(' ')[0]; // Get date part
        final parts = datePart.split('-');
        if (parts.length >= 3) {
          final year = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final day = int.tryParse(parts[2]);
          if (year != null && month != null && day != null && 
              year > 1900 && year < 2100 && 
              month >= 1 && month <= 12 && 
              day >= 1 && day <= 31) {
            return DateTime(year, month, day);
          }
        }
      } catch (_) {
        // Manual parsing failed
      }
    }
    
    return null;
  }

  void _handleEmailChanged() {
    final String trimmed = _emailController.text.trim();
    final bool hasInput = trimmed.isNotEmpty;
    final bool isValid = _isValidEmail(trimmed);
    if (hasInput != _emailHasInput || isValid != _emailIsValid) {
      setState(() {
        _emailHasInput = hasInput;
        _emailIsValid = isValid;
      });
    }
  }

  bool _isValidEmail(String value) {
    if (value.isEmpty) {
      return false;
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(value);
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Color? titleColor,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: titleColor ?? AppTheme.primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.headingSmall.copyWith(
                  fontSize: 18,
                  color: titleColor ?? theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  _FieldResolution _resolveField(
    Map<String, dynamic> source,
    List<String> keys, {
    required String fallbackKey,
  }) {
    for (final key in keys) {
      if (source.containsKey(key)) {
        return _FieldResolution(key: key, value: _readString(source[key]).trim());
      }
    }
    return _FieldResolution(key: fallbackKey, value: '');
  }

  String _readString(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  String _normalizeStatus(dynamic value) {
    final status = _readString(value).trim().toLowerCase();
    if (status.isEmpty) {
      return '';
    }
    if (status == 'true' || status.contains('active') || status.contains('verified')) {
      return 'active';
    }
    if (status == 'false' ||
        status.contains('inactive') ||
        status.contains('pending') ||
        status.contains('blocked')) {
      return 'inactive';
    }
    return status;
  }

  String? _extractImageUrl(Map<String, dynamic> user) {
    return ProfileImageHelper.extractImageUrl(user);
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Super Admin':
      case 'SuperAdmin':
        return AppTheme.primaryColor;
      case 'Admin':
        return AppTheme.warningColor;
      case 'Staff':
        return AppTheme.secondaryColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) {
      return '?';
    }
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
    return parts.isEmpty ? '?' : parts;
  }

  /// Filter permission tree to only show permissions that the role has
  PermissionNode _filterPermissionTreeByRole(
    PermissionNode tree,
    List<String> rolePermissions,
  ) {
    return _filterNodeRecursive(tree, rolePermissions);
  }

  PermissionNode _filterNodeRecursive(
    PermissionNode node,
    List<String> rolePermissions,
  ) {
    // Skip root node
    if (node.id == 'root') {
      final filteredChildren = node.children
          .map((child) => _filterNodeRecursive(child, rolePermissions))
          .where((child) {
            // Keep child if it or any of its descendants are in role permissions
            final childAllIds = child.getAllPermissionIds();
            return childAllIds.any((id) => rolePermissions.contains(id) && id != 'root');
          })
          .toList();
      return node.copyWith(children: filteredChildren);
    }

    // Check if this node is in role permissions
    final nodeInRole = rolePermissions.contains(node.id);
    
    // If this node is in role permissions, keep all its children (they're implicitly included)
    if (nodeInRole) {
      // Keep all children as-is since parent is in role
      return node;
    }
    
    // Otherwise, filter children recursively
    final filteredChildren = node.children
        .map((child) => _filterNodeRecursive(child, rolePermissions))
        .where((child) {
          // Keep child if it or any of its descendants are in role permissions
          final childAllIds = child.getAllPermissionIds();
          return childAllIds.any((id) => rolePermissions.contains(id) && id != 'root');
        })
        .toList();

    // If has filtered children, keep this node with filtered children
    if (filteredChildren.isNotEmpty) {
      return node.copyWith(children: filteredChildren);
    }

    // Return empty node if not in role permissions and has no matching children
    return node.copyWith(children: []);
  }

  /// Show role permission dialog with defaults (read-only) and user-specific permissions (editable)
  Future<void> _showRolePermissionDialog(String roleName) async {
    if (!mounted) return;
    
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    // Load role default permissions
    try {
      final rolePermissionsResult = await RoleService.getRolePermissions(roleName);
      if (!mounted) return;
      
      if (rolePermissionsResult['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load role permissions: ${rolePermissionsResult['message'] ?? 'Unknown error'}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      
      final roleDefaultPermissions = List<String>.from(rolePermissionsResult['permissions'] ?? []);
      print('✅ Loaded ${roleDefaultPermissions.length} default permissions for role: $roleName');
      
      // Get existing user permissions from widget.user (already loaded)
      final existingUserPermissions = List<String>.from(_userCurrentPermissions);
      print('✅ Using ${existingUserPermissions.length} existing user-specific permissions');
      
      // Get current user's permissions to filter what can be assigned
      final currentUserPermissionsResult = await AuthService.refreshPermissions();
      if (!mounted) return;
      
      if (currentUserPermissionsResult['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load your permissions: ${currentUserPermissionsResult['message'] ?? 'Unknown error'}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      
      final currentUserPermissions = List<String>.from(currentUserPermissionsResult['permissions'] ?? []);
      final defaultTree = PermissionTreeBuilder.buildDefaultPermissionTree();
      
      // Handle SuperAdmin case
      List<String> permissionsToShow = currentUserPermissions;
      if (currentUserPermissions.contains('*')) {
        permissionsToShow = defaultTree.getAllPermissionIds().where((id) => id != 'root').toList();
      }
      
      if (permissionsToShow.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You have no permissions assigned. Cannot assign permissions to user.'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        return;
      }
      
      // Filter tree to only show permissions that the logged-in user has
      final filteredTree = _filterPermissionTreeByRole(defaultTree, permissionsToShow);
      
      if (filteredTree.children.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No matching permissions found based on your access.'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        return;
      }
      
      // Build role default permissions tree (read-only)
      final roleDefaultTree = PermissionTreeBuilder.applyPermissions(
        filteredTree,
        roleDefaultPermissions,
      );
      
      // For existing users: Use their current user-specific permissions
      final initialUserPermissions = <String>[
        ...(_selectedPermissions.isNotEmpty 
            ? _selectedPermissions 
            : (existingUserPermissions.isNotEmpty 
                ? existingUserPermissions.map((p) => p.toString()).toList() 
                : []))
      ];
      
      // Combine role defaults with user-specific permissions
      // Role defaults will be locked (non-editable)
      final allPermissions = <String>[
        ...roleDefaultPermissions,
        ...initialUserPermissions.where((p) => !roleDefaultPermissions.contains(p)),
      ].toSet().toList();
      
      // Apply permissions to tree, marking role defaults as locked
      final userPermissionsTree = PermissionTreeBuilder.applyPermissions(
        filteredTree,
        allPermissions,
        lockedPermissionIds: roleDefaultPermissions,
      );
      
      if (!mounted) return;
      
      // Track selected permissions for the dialog - only user-specific (not role defaults)
      List<String> dialogSelectedPermissions = List.from(
        initialUserPermissions.where((p) => p != 'root' && !roleDefaultPermissions.contains(p))
      );
      
      // Show dialog
      await showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.5),
        useRootNavigator: true,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              // Store reference to filteredTree and roleDefaultPermissions for use in onChanged
              final filteredTreeRef = filteredTree;
              final roleDefaultsRef = roleDefaultPermissions;
              
              // Combine role defaults (locked) with user-specific permissions (editable)
              final allSelectedPermissions = <String>[
                ...roleDefaultsRef, // Role defaults (will be locked)
                ...dialogSelectedPermissions, // User-specific permissions
              ].toSet().toList();
              
              // Rebuild user permissions tree with role defaults locked
              PermissionNode currentUserPermissionsTree = PermissionTreeBuilder.applyPermissions(
                filteredTreeRef,
                allSelectedPermissions,
                lockedPermissionIds: roleDefaultsRef,
              );
              
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 32,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  width: isMobile ? double.infinity : 800,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.security_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Edit Permissions - $roleName',
                                    style: AppTheme.headingMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'User-specific permissions',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              onPressed: () => Navigator.of(dialogContext).pop(),
                            ),
                          ],
                        ),
                      ),
                      
                      // Content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // User-Specific Permissions Section (Editable)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.secondaryColor.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.edit_outlined,
                                          color: AppTheme.secondaryColor,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'User-Specific Permissions',
                                          style: AppTheme.headingSmall.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Select permissions for this user',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildEditablePermissionTree(
                                      tree: currentUserPermissionsTree,
                                      roleDefaultPermissions: roleDefaultsRef,
                                      filteredTree: filteredTreeRef,
                                      dialogSelectedPermissions: dialogSelectedPermissions,
                                      onPermissionsChanged: (newPermissions) {
                                        setDialogState(() {
                                          // Filter out role defaults from new permissions (they should stay locked)
                                          dialogSelectedPermissions = newPermissions
                                              .where((p) => !roleDefaultsRef.contains(p) && p != 'root')
                                              .toList();
                                          
                                          // Combine role defaults (locked) with user-specific permissions
                                          final allSelectedPermissions = <String>[
                                            ...roleDefaultsRef, // Role defaults (locked)
                                            ...dialogSelectedPermissions, // User-specific permissions
                                          ].toSet().toList();
                                          
                                          // Rebuild tree with role defaults locked
                                          currentUserPermissionsTree = PermissionTreeBuilder.applyPermissions(
                                            filteredTreeRef,
                                            allSelectedPermissions,
                                            lockedPermissionIds: roleDefaultsRef,
                                          );
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Footer with buttons
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: AppTheme.borderColor.withOpacity(0.3),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedPermissions = List.from(dialogSelectedPermissions);
                                });
                                Navigator.of(dialogContext).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading permissions: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
  
  /// Build editable permission tree with role defaults locked
  Widget _buildEditablePermissionTree({
    required PermissionNode tree,
    required List<String> roleDefaultPermissions,
    required PermissionNode filteredTree,
    required List<String> dialogSelectedPermissions,
    required Function(List<String>) onPermissionsChanged,
  }) {
    return HierarchicalCheckbox(
      key: ValueKey('user_perms_${dialogSelectedPermissions.join(",")}_${tree.getSelectedPermissionIds().length}'),
      node: tree,
      onChanged: (node) {
        // Get all selected permissions from the updated tree
        final allSelected = node.getSelectedPermissionIds();
        
        // Filter out role defaults (locked permissions) - only return user-specific permissions
        final userSpecific = allSelected
            .where((p) => !roleDefaultPermissions.contains(p) && p != 'root')
            .toList();
        
        // Update permissions list (this will trigger tree rebuild in parent)
        onPermissionsChanged(userSpecific);
      },
    );
  }

  /// Build compact permission view showing "+3 more" style
  Widget _buildCompactPermissionView(List<String> userPermissions, List<String> roleDefaults) {
    // Show all user permissions (role defaults + additional)
    final allUserPermissions = userPermissions
        .where((p) => p.isNotEmpty && p != 'root')
        .toList();
    
    if (allUserPermissions.isEmpty) {
      return Text(
        'No permissions assigned.',
        style: AppTheme.bodyMedium.copyWith(
          color: AppTheme.textSecondary,
        ),
      );
    }
    
    const int maxVisible = 3;
    final visiblePermissions = allUserPermissions.take(maxVisible).toList();
    final remainingCount = allUserPermissions.length - maxVisible;
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...visiblePermissions.map((permission) => Chip(
          label: Text(
            permission,
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
          labelStyle: TextStyle(color: AppTheme.secondaryColor),
        )),
        if (remainingCount > 0)
          Chip(
            label: Text('+$remainingCount more'),
            backgroundColor: AppTheme.warningColor.withOpacity(0.1),
            labelStyle: TextStyle(color: AppTheme.warningColor),
            onDeleted: () {
              // Show full list dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('All User Screen Permissions'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: allUserPermissions.map((p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            if (roleDefaults.contains(p))
                              Icon(Icons.lock_outline, size: 16, color: AppTheme.primaryColor),
                            if (!roleDefaults.contains(p))
                              Icon(Icons.edit_outlined, size: 16, color: AppTheme.secondaryColor),
                            const SizedBox(width: 8),
                            Expanded(child: Text(p)),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  /// Show permission selection dialog for the selected role
  Future<void> _showPermissionSelectionDialog(String roleName) async {
    print('🔐 _showPermissionSelectionDialog called for role: $roleName');
    if (!mounted) {
      print('❌ Widget not mounted, returning');
      return;
    }
    
    final isMobile = MediaQuery.of(context).size.width < 600;
    print('📱 Is mobile: $isMobile');

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Loading your permissions...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Fetch logged-in user's permissions (role + user-specific combined)
    try {
      final currentUserPermissionsResult = await AuthService.refreshPermissions();
      
      if (!mounted) return;
      
      if (currentUserPermissionsResult['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load your permissions: ${currentUserPermissionsResult['message'] ?? 'Unknown error'}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      final currentUserPermissions = List<String>.from(currentUserPermissionsResult['permissions'] ?? []);
      print('✅ Loaded ${currentUserPermissions.length} permissions for logged-in user');
      
      // Build default permission tree (needed for both SuperAdmin check and filtering)
      final defaultTree = PermissionTreeBuilder.buildDefaultPermissionTree();
      
      // Handle SuperAdmin case - if user has '*' permission, they have all permissions
      // For SuperAdmin, we should show all available permissions from the tree
      List<String> permissionsToShow = currentUserPermissions;
      if (currentUserPermissions.contains('*')) {
        print('🔑 Logged-in user is SuperAdmin - will show all available permissions');
        // For SuperAdmin, get all permissions from the default tree
        permissionsToShow = defaultTree.getAllPermissionIds().where((id) => id != 'root').toList();
        print('📋 SuperAdmin can assign ${permissionsToShow.length} total permissions');
      }
      
      if (permissionsToShow.isEmpty) {
        print('⚠️ Logged-in user has no permissions');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You have no permissions assigned. Cannot assign permissions to user.'),
              backgroundColor: AppTheme.warningColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Filter tree to only show permissions that the logged-in user has
      final filteredTree = _filterPermissionTreeByRole(defaultTree, permissionsToShow);
      
      // Check if filtered tree has any children (permissions)
      print('🌳 Filtered tree has ${filteredTree.children.length} top-level children');
      if (filteredTree.children.isEmpty) {
        print('⚠️ No matching permissions found after filtering');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No matching permissions found based on your access.'),
              backgroundColor: AppTheme.warningColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Apply user's current permissions to pre-select them
      PermissionNode initialTree = filteredTree;
      print('📝 Current _selectedPermissions: $_selectedPermissions');
      print('📝 Current _selectedPermissions count: ${_selectedPermissions.length}');
      print('📝 Current _userCurrentPermissions: $_userCurrentPermissions');
      print('📝 Current _userCurrentPermissions count: ${_userCurrentPermissions.length}');
      
      // Use _selectedPermissions if available, otherwise use _userCurrentPermissions
      final permissionsToApply = _selectedPermissions.isNotEmpty 
          ? _selectedPermissions 
          : _userCurrentPermissions;
      
      print('📝 Permissions to apply: $permissionsToApply');
      print('📝 Permissions to apply count: ${permissionsToApply.length}');
      
      if (permissionsToApply.isNotEmpty) {
        // Filter permissions to only include those that exist in the filtered tree
        final allFilteredPermissionIds = filteredTree.getAllPermissionIds();
        final validPermissions = permissionsToApply
            .where((perm) => allFilteredPermissionIds.contains(perm))
            .toList();
        
        print('📝 Valid permissions (in filtered tree): $validPermissions');
        print('📝 Valid permissions count: ${validPermissions.length}');
        
        if (validPermissions.isNotEmpty) {
          print('📝 Applying ${validPermissions.length} valid permissions to tree');
          initialTree = PermissionTreeBuilder.applyPermissions(filteredTree, validPermissions);
          final selectedCount = initialTree.getSelectedPermissionIds().length;
          print('📝 After applying permissions, selected count: $selectedCount');
          print('📝 Selected permission IDs: ${initialTree.getSelectedPermissionIds()}');
        } else {
          print('⚠️ No valid permissions to apply (none match filtered tree)');
        }
      } else {
        print('⚠️ No permissions to apply - both _selectedPermissions and _userCurrentPermissions are empty');
      }

      if (!mounted) {
        print('❌ Widget not mounted before showing dialog');
        return;
      }

      print('🎯 Showing permission selection dialog');
      // Use Navigator to show dialog with proper context
      // Use rootNavigator: true to show dialog above the edit user dialog
      await showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.5),
        useRootNavigator: true, // Use root navigator to show above existing dialog
        builder: (dialogContext) {
          // Store currentTree in dialog state to ensure it's properly maintained
          PermissionNode currentTree = initialTree;
          
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 32,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  width: isMobile ? double.infinity : 650,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with gradient
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.security_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select Permissions',
                                    style: AppTheme.headingMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Select permissions from your available access',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              onPressed: () => Navigator.of(dialogContext).pop(),
                            ),
                          ],
                        ),
                      ),

                      // Form Content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Info message
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Only permissions that you have access to are shown below. The selected permissions will be assigned to this user.',
                                        style: AppTheme.bodyMedium.copyWith(
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Configure User Role Section
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.settings_outlined,
                                      color: AppTheme.secondaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Configure User Permissions',
                                    style: AppTheme.headingSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Permission Tree
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.borderColor.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                constraints: const BoxConstraints(
                                  maxHeight: 450,
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: currentTree.children.map((node) {
                                      final nodeIndex = currentTree.children.indexOf(node);
                                      return HierarchicalCheckbox(
                                        key: ValueKey('${node.id}_$nodeIndex'),
                                        node: node,
                                        onChanged: (updatedNode) {
                                          setDialogState(() {
                                            final updatedChildren =
                                                List<PermissionNode>.from(
                                                    currentTree.children);
                                            updatedChildren[nodeIndex] = updatedNode;
                                            currentTree = currentTree.copyWith(
                                              children: updatedChildren,
                                            );
                                            currentTree.updateSelectionState();
                                          });
                                        },
                                        isMobile: isMobile,
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Permission Preview
                              PermissionPreviewWidget(
                                selectedPermissions: currentTree.getSelectedPermissionIds(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Action Buttons
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor.withOpacity(0.5),
                          border: Border(
                            top: BorderSide(
                              color: AppTheme.borderColor.withOpacity(0.5),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                // Ensure tree selection state is updated before getting selected IDs
                                // Update the entire tree recursively
                                currentTree.updateSelectionState();
                                
                                // Get all selected permission IDs from the current tree state
                                final allSelectedPermissions =
                                    currentTree.getSelectedPermissionIds();
                                
                                print('🔐 [SAVE PERMISSIONS] Getting selected permissions from tree');
                                print('   Tree structure - Root ID: ${currentTree.id}');
                                print('   Tree has ${currentTree.children.length} top-level children');
                                print('   Tree selected count: ${allSelectedPermissions.length}');
                                print('   Tree selected IDs (first 20): ${allSelectedPermissions.take(20).toList()}');
                                
                                // Verify tree structure by checking all permission IDs
                                final allTreePermissionIds = currentTree.getAllPermissionIds();
                                print('   Tree total permission IDs: ${allTreePermissionIds.length}');
                                print('   Tree permission IDs (first 20): ${allTreePermissionIds.take(20).toList()}');
                                
                                // Filter out root node ID and empty strings
                                final selectedPermissions = allSelectedPermissions
                                    .where((id) => id.isNotEmpty && id != 'root')
                                    .toList();

                                print('   Filtered selected count: ${selectedPermissions.length}');
                                print('   Filtered selected IDs (first 20): ${selectedPermissions.take(20).toList()}');
                                
                                // Check if we're missing permissions that should be selected
                                if (selectedPermissions.length < allTreePermissionIds.length - 1) { // -1 for root
                                  print('   ⚠️ WARNING: Only ${selectedPermissions.length} selected out of ${allTreePermissionIds.length - 1} total permissions in tree');
                                  print('   Missing permissions might be in tree but not marked as selected');
                                }

                                setState(() {
                                  _selectedPermissions = selectedPermissions;
                                });

                                print('   ✅ Saved ${selectedPermissions.length} permissions to _selectedPermissions');

                                Navigator.of(dialogContext).pop();
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Selected ${selectedPermissions.length} permission(s)',
                                    ),
                                    backgroundColor: AppTheme.secondaryColor,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, size: 18),
                                  SizedBox(width: 8),
                                  Text('Save Permissions'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      print('❌ Error in permission selection dialog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error showing permission dialog: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class _CountryCodeSelectorField extends StatefulWidget {
  const _CountryCodeSelectorField({
    required this.controller,
    this.countryTextStyle,
  });

  final TextEditingController controller;
  final TextStyle? countryTextStyle;

  @override
  State<_CountryCodeSelectorField> createState() => _CountryCodeSelectorFieldState();
}

class _CountryCodeSelectorFieldState extends State<_CountryCodeSelectorField> {
  late String _selectedDialCode;

  static const List<Map<String, String>> _countries = [
    {'name': 'India', 'iso': 'IN', 'dialCode': '+91'},
    {'name': 'United States', 'iso': 'US', 'dialCode': '+1'},
    {'name': 'United Kingdom', 'iso': 'GB', 'dialCode': '+44'},
    {'name': 'United Arab Emirates', 'iso': 'AE', 'dialCode': '+971'},
    {'name': 'Singapore', 'iso': 'SG', 'dialCode': '+65'},
    {'name': 'Australia', 'iso': 'AU', 'dialCode': '+61'},
    {'name': 'Germany', 'iso': 'DE', 'dialCode': '+49'},
    {'name': 'France', 'iso': 'FR', 'dialCode': '+33'},
    {'name': 'Canada', 'iso': 'CA', 'dialCode': '+1'},
    {'name': 'China', 'iso': 'CN', 'dialCode': '+86'},
    {'name': 'Japan', 'iso': 'JP', 'dialCode': '+81'},
  ];

  @override
  void initState() {
    super.initState();
    final String initial = widget.controller.text.trim();
    _selectedDialCode = initial.isEmpty ? '+91' : _normalize(initial);
    widget.controller.value = widget.controller.value.copyWith(
      text: _selectedDialCode,
      selection: TextSelection.collapsed(offset: _selectedDialCode.length),
    );
  }

  String _normalize(String value) {
    if (value.isEmpty) {
      return '+91';
    }
    return value.startsWith('+') ? value : '+$value';
  }

  String _flagEmoji(String? countryCode) {
    if (countryCode == null || countryCode.length != 2) {
      return '🌐';
    }
    final String upper = countryCode.toUpperCase();
    final int first = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int second = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCodes([first, second]);
  }

  Map<String, String> _findCountryByDialCode(String dialCode) {
    final String normalized = _normalize(dialCode);
    return _countries.firstWhere(
      (country) => country['dialCode'] == normalized,
      orElse: () => _countries.first,
    );
  }

  Future<void> _showCountryPicker() async {
    final Map<String, String>? selected = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SizedBox(
            width: 360,
            height: 480,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Text(
                    'Select Country',
                    style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryColor),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _countries.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: AppTheme.borderColor.withValues(alpha: 0.5),
                    ),
                    itemBuilder: (context, index) {
                      final country = _countries[index];
                      final bool isSelected = country['dialCode'] == _selectedDialCode;
                      return ListTile(
                        leading: Text(
                          _flagEmoji(country['iso']),
                          style: const TextStyle(fontSize: 22),
                        ),
                        title: Text(
                          country['name'] ?? '',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        trailing: Text(
                          country['dialCode'] ?? '',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () => Navigator.of(dialogContext).pop(country),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;

    setState(() {
      _selectedDialCode = selected['dialCode'] ?? _selectedDialCode;
      widget.controller.text = _selectedDialCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, String> country = _findCountryByDialCode(_selectedDialCode);
    final TextStyle? style = widget.countryTextStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _showCountryPicker,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.borderColor.withValues(alpha: 0.4),
            ),
          ),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Text(
                  _flagEmoji(country['iso']),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      country['name'] ?? '',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      country['dialCode'] ?? '',
                      style: style?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.expand_more,
                color: AppTheme.textSecondary.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldResolution {
  const _FieldResolution({required this.key, required this.value});

  final String key;
  final String value;
}

