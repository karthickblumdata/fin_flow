import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/role_service.dart';
import '../services/api_service.dart';
import '../services/pincode_service.dart';
import '../utils/api_constants.dart';
import '../theme/app_theme.dart';
import '../utils/profile_image_helper.dart';
import 'user_permissions_dialog.dart';
import 'role_selector_field.dart';
import 'dart:async';

class AddUserDialog extends StatefulWidget {
  const AddUserDialog({
    super.key,
    this.initialValues,
  });

  final Map<String, dynamic>? initialValues;

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _DismissDialogIntent extends Intent {
  const _DismissDialogIntent();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneNumberController;
  late final TextEditingController _countryCodeController;
  late final TextEditingController _dateOfBirthController;
  late final TextEditingController _addressController;
  late final TextEditingController _addressLine2Controller;
  late final TextEditingController _stateController;
  late final TextEditingController _pinCodeController;
  late String _phoneFieldKey;
  late String _countryCodeFieldKey;
  late String _dobFieldKey;
  late String _addressFieldKey;
  late String _addressLine2FieldKey;
  late String _stateFieldKey;
  late String _pinCodeFieldKey;
  late final TextEditingController _roleController;
  String? _selectedRole;
  List<String> _availableRoles = [];
  bool _isLoadingRoles = false;
  late bool _isActive;
  bool _isNonWalletUser = false;
  bool _emailHasInput = false;
  bool _emailIsValid = false;
  DateTime? _selectedDateOfBirth;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  Uint8List? _imageBytes;
  String? _imageUrl;
  bool _isSubmitting = false;
  String? _userName;
  bool _isLoadingState = false;
  Timer? _pincodeDebounceTimer;

  Map<String, dynamic> get _initialValues =>
      Map<String, dynamic>.from(widget.initialValues ?? {});

  @override
  void initState() {
    super.initState();
    final initial = _initialValues;

    _nameController = TextEditingController(text: _readString(initial['name']));
    _emailController = TextEditingController(text: _readString(initial['email']));
    _emailHasInput = _emailController.text.trim().isNotEmpty;
    _emailIsValid = _isValidEmail(_emailController.text.trim());
    _emailController.addListener(_handleEmailChanged);

    final phoneResolution = _resolveField(
      initial,
      const ['phoneNumber', 'phone', 'contactNumber', 'mobile', 'mobileNumber'],
      fallbackKey: 'phoneNumber',
    );
    _phoneFieldKey = phoneResolution.key;
    _phoneNumberController = TextEditingController(text: phoneResolution.value);

    final countryCodeResolution = _resolveField(
      initial,
      const ['countryCode', 'dialCode', 'phoneCode', 'countryDialCode'],
      fallbackKey: 'countryCode',
    );
    _countryCodeFieldKey = countryCodeResolution.key;
    _countryCodeController = TextEditingController(text: countryCodeResolution.value);

    final dobResolution = _resolveField(
      initial,
      const ['dateOfBirth', 'dob', 'birthDate', 'birth_day'],
      fallbackKey: 'dateOfBirth',
    );
    _dobFieldKey = dobResolution.key;
    _selectedDateOfBirth = _parseDate(dobResolution.value);
    _dateOfBirthController = TextEditingController(
      text: _selectedDateOfBirth != null ? _dateFormat.format(_selectedDateOfBirth!) : dobResolution.value,
    );

    final addressResolution = _resolveField(
      initial,
      const ['address', 'homeAddress', 'residentialAddress', 'mailingAddress'],
      fallbackKey: 'address',
    );
    _addressFieldKey = addressResolution.key;
    _addressController = TextEditingController(text: addressResolution.value);

    final addressLine2Resolution = _resolveField(
      initial,
      const [
        'addressLine2',
        'address2',
        'residentialAddressLine2',
        'mailingAddressLine2',
      ],
      fallbackKey: 'addressLine2',
    );
    _addressLine2FieldKey = addressLine2Resolution.key;
    _addressLine2Controller = TextEditingController(text: addressLine2Resolution.value);

    final stateResolution = _resolveField(
      initial,
      const ['state', 'province', 'region'],
      fallbackKey: 'state',
    );
    _stateFieldKey = stateResolution.key;
    _stateController = TextEditingController(text: stateResolution.value);

    final pinCodeResolution = _resolveField(
      initial,
      const ['pinCode', 'postalCode', 'zipCode', 'zip', 'pincode'],
      fallbackKey: 'pinCode',
    );
    _pinCodeFieldKey = pinCodeResolution.key;
    _pinCodeController = TextEditingController(text: pinCodeResolution.value);
    // Add listener to PINCODE field to auto-load state
    _pinCodeController.addListener(_handlePincodeChanged);

    final resolvedRole = _readString(initial['role']).trim();
    _selectedRole = resolvedRole.isNotEmpty ? resolvedRole : null;
    _roleController = TextEditingController(text: _selectedRole ?? '');

    final normalizedStatus = _normalizeStatus(initial['status']);
    _isActive = normalizedStatus.isEmpty ? true : normalizedStatus == 'active';

    _imageUrl = _extractImageUrl(initial);
    _loadUserInfo();
    _loadAvailableRoles();
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
              // Handle different possible field names
              final roleName = role['roleName']?.toString().trim() ?? 
                              role['name']?.toString().trim() ?? 
                              role['role']?.toString().trim() ?? '';
              return roleName;
            })
            .where((name) => name.isNotEmpty)
            .where((name) => name.toLowerCase() != 'superadmin') // Exclude SuperAdmin
            .toSet() // Remove duplicates
            .toList()
          ..sort(); // Sort alphabetically

        if (mounted) {
          setState(() {
            _availableRoles = roleNames;
            _isLoadingRoles = false;
            
            // If initial role is provided and exists in the list, select it
            if (_selectedRole != null && _availableRoles.contains(_selectedRole)) {
              // Already set, keep it
            } else if (_selectedRole != null && !_availableRoles.contains(_selectedRole)) {
              // Initial role doesn't exist in list, keep it selected but it won't show in dropdown
              // This handles edge case where role was typed manually
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingRoles = false;
          });
        }
      }
    } catch (e) {
      print('Error loading roles: $e');
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
    } else {
      // Clear state if pincode is not 6 digits
      if (mounted && _stateController.text.isNotEmpty) {
        // Don't clear if user manually entered state
        // Only clear if state was auto-filled
      }
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
        if (state.isNotEmpty) {
          _stateController.text = state;
        }
      } else {
        // Don't show error, just silently fail
        // User can manually enter state
      }
    } catch (e) {
      // Silently handle error
      print('Error fetching state from pincode: $e');
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
    _pincodeDebounceTimer?.cancel();
    _nameController.dispose();
    _emailController.removeListener(_handleEmailChanged);
    _emailController.dispose();
    _phoneNumberController.dispose();
    _countryCodeController.dispose();
    _dateOfBirthController.dispose();
    _addressController.dispose();
    _addressLine2Controller.dispose();
    _stateController.dispose();
    _pinCodeController.removeListener(_handlePincodeChanged);
    _pinCodeController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final double maxHeight = MediaQuery.of(context).size.height * (isMobile ? 0.9 : 0.85);

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
              maxWidth: isMobile ? double.infinity : 760,
              maxHeight: maxHeight,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  _buildHeader(context, isMobile: isMobile),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 24,
                        vertical: isMobile ? 12 : 20,
                      ),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Builder(
                              builder: (context) {
                                final isMobile = MediaQuery.of(context).size.width < 600;
                                return Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: Padding(
                                    padding: EdgeInsets.all(isMobile ? 12 : 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final theme = Theme.of(context);
                                        final bool isWide = constraints.maxWidth >= 600;
                                        final bool isMobileLayout = !isWide;

                                        final Widget sectionHeader = _buildSectionHeader(
                                          context,
                                          icon: Icons.badge_outlined,
                                          title: 'Basic Details',
                                          subtitle: 'Enter information for the new user.',
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

                                        final Widget roleField = RoleSelectorField(
                                          isLoading: _isLoadingRoles,
                                          roles: _availableRoles,
                                          selectedRole: _selectedRole,
                                          enabled: !_isSubmitting,
                                          onRoleChanged: (value) {
                                            setState(() {
                                              _selectedRole = value;
                                              _roleController.text = value ?? '';
                                            });
                                          },
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
                                                  SizedBox(height: isMobileLayout ? 8 : 12),
                                                  phoneNumberField,
                                                ],
                                              );

                                        final Widget nameField = TextFormField(
                                          controller: _nameController,
                                          enabled: !_isSubmitting,
                                          textInputAction: TextInputAction.next,
                                          keyboardType: TextInputType.name,
                                          textCapitalization: TextCapitalization.words,
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
                                          SizedBox(height: isMobileLayout ? 12 : 16),
                                          emailField,
                                        ];

                                        final Widget dateField = TextFormField(
                                          controller: _dateOfBirthController,
                                          enabled: !_isSubmitting,
                                          readOnly: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Date of Birth',
                                            hintText: 'Select date of birth',
                                            suffixIcon: Icon(Icons.calendar_today_outlined),
                                          ),
                                          onTap: _isSubmitting ? null : _handleDateOfBirthTap,
                                          validator: (value) {
                                            if ((value ?? '').trim().isEmpty) {
                                              return 'Please select the date of birth.';
                                            }
                                            return null;
                                          },
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
                                                ? 'State will be auto-filled from PIN code'
                                                : null,
                                          ),
                                        );

                                        final Widget addressGroup = Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            addressField,
                                            SizedBox(height: isMobileLayout ? 12 : 16),
                                            addressLine2Field,
                                          ],
                                        );

                                        // State moved to left column, PIN Code stays in right sidebar for desktop

                                        final Widget leftColumn = Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            ...nameEmailGroup,
                                            SizedBox(height: isMobileLayout ? 12 : 16),
                                            contactInputs,
                                            SizedBox(height: isMobileLayout ? 12 : 16),
                                            dateField,
                                            SizedBox(height: isMobileLayout ? 16 : 24),
                                            addressGroup,
                                            SizedBox(height: isMobileLayout ? 12 : 16),
                                            stateField,
                                            SizedBox(height: isMobileLayout ? 12 : 16),
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
                                            SizedBox(height: isMobileLayout ? 16 : 24),
                                            roleField,
                                            SizedBox(height: isMobileLayout ? 16 : 24),
                                            _buildStatusSelector(context),
                                            SizedBox(height: isMobileLayout ? 16 : 24),
                                            _buildNonWalletUserToggle(context),
                                            SizedBox(height: isMobileLayout ? 20 : 32),
                                            pinCodeField,
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
                                            SizedBox(height: isMobileLayout ? 16 : 24),
                                            roleField,
                                            SizedBox(height: isMobileLayout ? 16 : 24),
                                            _buildStatusSelector(context),
                                            SizedBox(height: isMobileLayout ? 12 : 16),
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
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    sectionHeader,
                                                    SizedBox(height: isMobileLayout ? 12 : 20),
                                                    formPanel,
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: isMobileLayout ? 12 : 24),
                                              SizedBox(
                                                width: 260,
                                                child: Column(
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
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            narrowHeader,
                                            SizedBox(height: isMobileLayout ? 12 : 20),
                                            avatarPanelMobile,
                                            SizedBox(height: isMobileLayout ? 12 : 16),
                                            formPanel,
                                            SizedBox(height: isMobileLayout ? 12 : 16),
                                            pinCodeField,
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                              },
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
                      return Padding(
                        padding: EdgeInsets.all(isMobile ? 12 : 20),
                        child: isMobile
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isSubmitting ? null : _handleCreateAndSendInvite,
                                      icon: Icon(Icons.person_add, size: isMobile ? 16 : 18),
                                      label: Text(
                                        'Create User & Send Invite',
                                        style: TextStyle(fontSize: isMobile ? 13 : 14),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isMobile ? 16 : 20,
                                          vertical: isMobile ? 10 : 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: TextButton(
                                      onPressed: _isSubmitting ? null : _handleClose,
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(fontSize: isMobile ? 13 : 14),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  TextButton(
                                    onPressed: _isSubmitting ? null : _handleClose,
                                    child: const Text('Cancel'),
                                  ),
                                  const Spacer(),
                                  ElevatedButton.icon(
                                    onPressed: _isSubmitting ? null : _handleCreateAndSendInvite,
                                    icon: const Icon(Icons.person_add, size: 18),
                                    label: const Text('Create User & Send Invite'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                      );
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

  Widget _buildHeader(BuildContext context, {required bool isMobile}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 24,
        isMobile ? 12 : 20,
        isMobile ? 8 : 24,
        isMobile ? 10 : 16,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
            ),
            child: Icon(
              Icons.person_add_alt_1_outlined,
              color: AppTheme.primaryColor,
              size: isMobile ? 18 : 24,
            ),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add User',
                  style: AppTheme.headingSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: isMobile ? 16 : 18,
                  ),
                ),
                Text(
                  'Create a new profile and grant access.',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: isMobile ? 11 : 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Username in top-right corner - hide on mobile if space is tight
          if (_userName != null && !isMobile)
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
            icon: Icon(Icons.close, size: isMobile ? 20 : 24),
            padding: EdgeInsets.all(isMobile ? 4 : 8),
            constraints: BoxConstraints(
              minWidth: isMobile ? 32 : 48,
              minHeight: isMobile ? 32 : 48,
            ),
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
                                  final roleColor = _getRoleColor(_roleController.text.trim());
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
                                  final roleColor = _getRoleColor(_roleController.text.trim());
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

  Future<void> _handleCreate() async {
    if (_isSubmitting) return;
    final currentState = _formKey.currentState;
    if (currentState != null && !currentState.validate()) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });

    try {
      final roleName = _selectedRole ?? _roleController.text.trim();
      
      if (roleName.isEmpty) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a role.'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      
      // Step 1: Verify role exists (must be created in Roles screen first)
      final roleExists = await RoleService.roleExists(roleName);
      
      if (!roleExists) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role "$roleName" does not exist. Please create it in the Roles screen first.'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
      
      // Step 2: Upload image if provided
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
      
      // Step 3: Format date of birth as ISO string (YYYY-MM-DD)
      String? formattedDateOfBirth;
      if (_selectedDateOfBirth != null) {
        formattedDateOfBirth = _selectedDateOfBirth!.toIso8601String().split('T')[0];
      } else if (_dateOfBirthController.text.trim().isNotEmpty) {
        try {
          final parsedDate = _dateFormat.parse(_dateOfBirthController.text.trim());
          formattedDateOfBirth = parsedDate.toIso8601String().split('T')[0];
        } catch (e) {
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enter a valid date of birth.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }
      }
      
      // Step 4: Proceed with user creation
      final result = await AuthService.createUser(
        _nameController.text.trim(),
        _emailController.text.trim(),
        roleName,
        phoneNumber: _phoneNumberController.text.trim(),
        countryCode: _countryCodeController.text.trim(),
        dateOfBirth: formattedDateOfBirth,
        profileImage: profileImageUrl,
        address: _addressController.text.trim(),
        state: _stateController.text.trim(),
        pinCode: _pinCodeController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      if (result['success'] == true) {
        final userData = result['user'] as Map<String, dynamic>?;
        final userId = userData?['_id'] ?? userData?['id'] ?? '';
        final userName = _nameController.text.trim();
        final userEmail = _emailController.text.trim();
        final newUser = <String, dynamic>{
          'name': userName,
          'email': userEmail,
          _phoneFieldKey: _phoneNumberController.text.trim(),
          _countryCodeFieldKey: _countryCodeController.text.trim(),
          _dobFieldKey: _dateOfBirthController.text.trim(),
          _addressFieldKey: _addressController.text.trim(),
          _addressLine2FieldKey: _addressLine2Controller.text.trim(),
          _stateFieldKey: _stateController.text.trim(),
          _pinCodeFieldKey: _pinCodeController.text.trim(),
          'role': roleName,
          'status': _isActive ? 'Active' : 'Inactive',
          'isVerified': _isActive,
          if (result['user'] is Map<String, dynamic>) ...result['user'] as Map<String, dynamic>,
        };
        // Use uploaded image URL if available, otherwise use API response, otherwise use existing
        if (profileImageUrl != null) {
          newUser['profileImage'] = profileImageUrl;
        } else if (userData?['profileImage'] != null) {
          newUser['profileImage'] = userData!['profileImage'];
        } else if (_imageUrl != null) {
          newUser['profileImage'] = _imageUrl;
        }

        // Close the add user dialog first
        if (mounted) {
          Navigator.of(context).pop({
            'event': 'created',
            'user': newUser,
            'message': result['message'],
            if (_imageBytes != null) 'imageBytes': _imageBytes,
          });
        }

        // Open permission selection dialog after user creation
        if (mounted && userId != null && userId.toString().isNotEmpty) {
          await _showPermissionDialog(userId.toString(), userName, userEmail, roleName);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Failed to create user'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create user: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _handleCreateAndSendInvite() async {
    // If Non Wallet User toggle is ON, use the non-wallet user handler
    if (_isNonWalletUser) {
      await _handleCreateNonWalletUser();
      return;
    }
    
    if (_isSubmitting) return;
    final currentState = _formKey.currentState;
    if (currentState != null && !currentState.validate()) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });

    try {
      final roleName = _selectedRole ?? _roleController.text.trim();
      
      if (roleName.isEmpty) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a role.'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      
      // Step 1: Verify role exists (must be created in Roles screen first)
      final roleExists = await RoleService.roleExists(roleName);
      
      if (!roleExists) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role "$roleName" does not exist. Please create it in the Roles screen first.'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
      
      // Step 2: Upload image if provided
      String? profileImageUrl;
      if (_imageBytes != null) {
        try {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
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
                    Expanded(
                      child: Text('Uploading profile image...'),
                    ),
                  ],
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }
          
          final uploadResult = await ApiService.uploadFile(
            ApiConstants.uploadUserProfileImage,
            '', // filePath not needed when using fileBytes
            'image',
            fileBytes: _imageBytes,
            fileName: 'profile-image.jpg',
          );
          
          if (uploadResult['success'] == true && uploadResult['imageUrl'] != null) {
            profileImageUrl = uploadResult['imageUrl'] as String;
          } else {
            print('⚠️  Image upload failed: ${uploadResult['message']}');
            // Continue without image if upload fails
          }
        } catch (e) {
          print('⚠️  Error uploading image: $e');
          // Continue without image if upload fails
        }
      }
      
      // Step 3: Format date of birth as ISO string (YYYY-MM-DD)
      String? formattedDateOfBirth;
      if (_selectedDateOfBirth != null) {
        formattedDateOfBirth = _selectedDateOfBirth!.toIso8601String().split('T')[0]; // Get YYYY-MM-DD part
      } else if (_dateOfBirthController.text.trim().isNotEmpty) {
        // Try to parse the date from the controller text
        try {
          final parsedDate = _dateFormat.parse(_dateOfBirthController.text.trim());
          formattedDateOfBirth = parsedDate.toIso8601String().split('T')[0];
        } catch (e) {
          // If parsing fails, show error
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enter a valid date of birth.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }
      }
      
      // Step 4: Proceed with user creation
      final result = await AuthService.createUser(
        _nameController.text.trim(),
        _emailController.text.trim(),
        roleName,
        phoneNumber: _phoneNumberController.text.trim(),
        countryCode: _countryCodeController.text.trim(),
        dateOfBirth: formattedDateOfBirth,
        profileImage: profileImageUrl,
        address: _addressController.text.trim(),
        state: _stateController.text.trim(),
        pinCode: _pinCodeController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      if (result['success'] == true) {
        final userData = result['user'] as Map<String, dynamic>?;
        final userId = userData?['_id'] ?? userData?['id'];
        final userEmail = _emailController.text.trim();

        // Send invite email with username and password
        final inviteResult = await AuthService.sendInvite(
          userId: userId?.toString(),
          email: userEmail,
        );

        if (!mounted) {
          return;
        }

        final newUser = <String, dynamic>{
          'name': _nameController.text.trim(),
          'email': userEmail,
          _phoneFieldKey: _phoneNumberController.text.trim(),
          _countryCodeFieldKey: _countryCodeController.text.trim(),
          _dobFieldKey: _dateOfBirthController.text.trim(),
          _addressFieldKey: _addressController.text.trim(),
          _addressLine2FieldKey: _addressLine2Controller.text.trim(),
          _stateFieldKey: _stateController.text.trim(),
          _pinCodeFieldKey: _pinCodeController.text.trim(),
          'role': roleName,
          'status': _isActive ? 'Active' : 'Inactive',
          'isVerified': _isActive,
          if (userData != null) ...userData,
        };
        // Use uploaded image URL if available, otherwise use API response, otherwise use existing
        if (profileImageUrl != null) {
          newUser['profileImage'] = profileImageUrl;
        } else if (userData?['profileImage'] != null) {
          newUser['profileImage'] = userData!['profileImage'];
        } else if (_imageUrl != null) {
          newUser['profileImage'] = _imageUrl;
        }

        String message = result['message'] ?? 'User created successfully';
        if (inviteResult['success'] == true) {
          message = 'User created and invite email sent successfully with username and password';
        } else {
          message = 'User created successfully, but failed to send invite email: ${inviteResult['message']}';
        }

        final userName = _nameController.text.trim();

        // Close the add user dialog first
        if (mounted) {
          Navigator.of(context).pop({
            'event': 'created',
            'user': newUser,
            'message': message,
            'sendInvite': inviteResult['success'] == true,
            'email': userEmail,
            if (_imageBytes != null) 'imageBytes': _imageBytes,
          });
        }

        // Open permission selection dialog after user creation
        if (mounted && userId != null && userId.toString().isNotEmpty) {
          await _showPermissionDialog(userId.toString(), userName, userEmail, roleName);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Failed to create user'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create user: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _handleCreateNonWalletUser() async {
    if (_isSubmitting) return;
    final currentState = _formKey.currentState;
    if (currentState != null && !currentState.validate()) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });

    try {
      final roleName = _selectedRole ?? _roleController.text.trim();
      
      if (roleName.isEmpty) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a role.'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      
      // Step 1: Verify role exists (must be created in Roles screen first)
      final roleExists = await RoleService.roleExists(roleName);
      
      if (!roleExists) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role "$roleName" does not exist. Please create it in the Roles screen first.'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
      
      // Step 2: Upload image if provided
      String? profileImageUrl;
      if (_imageBytes != null) {
        try {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
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
                    Expanded(
                      child: Text('Uploading profile image...'),
                    ),
                  ],
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }
          
          final uploadResult = await ApiService.uploadFile(
            ApiConstants.uploadUserProfileImage,
            '',
            'image',
            fileBytes: _imageBytes,
            fileName: 'profile-image.jpg',
          );
          
          if (uploadResult['success'] == true && uploadResult['imageUrl'] != null) {
            profileImageUrl = uploadResult['imageUrl'] as String;
          } else {
            print('⚠️  Image upload failed: ${uploadResult['message']}');
          }
        } catch (e) {
          print('⚠️  Error uploading image: $e');
        }
      }
      
      // Step 3: Format date of birth as ISO string (YYYY-MM-DD)
      String? formattedDateOfBirth;
      if (_selectedDateOfBirth != null) {
        formattedDateOfBirth = _selectedDateOfBirth!.toIso8601String().split('T')[0];
      } else if (_dateOfBirthController.text.trim().isNotEmpty) {
        try {
          final parsedDate = _dateFormat.parse(_dateOfBirthController.text.trim());
          formattedDateOfBirth = parsedDate.toIso8601String().split('T')[0];
        } catch (e) {
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enter a valid date of birth.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }
      }
      
      // Step 4: Proceed with user creation (without wallet)
      final result = await AuthService.createUser(
        _nameController.text.trim(),
        _emailController.text.trim(),
        roleName,
        phoneNumber: _phoneNumberController.text.trim(),
        countryCode: _countryCodeController.text.trim(),
        dateOfBirth: formattedDateOfBirth,
        profileImage: profileImageUrl,
        address: _addressController.text.trim(),
        state: _stateController.text.trim(),
        pinCode: _pinCodeController.text.trim(),
        skipWallet: true, // Skip wallet creation
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      if (result['success'] == true) {
        final userData = result['user'] as Map<String, dynamic>?;
        final userId = userData?['_id'] ?? userData?['id'];
        final userEmail = _emailController.text.trim();

        // Send invite email with username and password
        final inviteResult = await AuthService.sendInvite(
          userId: userId?.toString(),
          email: userEmail,
        );

        if (!mounted) {
          return;
        }

        final newUser = <String, dynamic>{
          'name': _nameController.text.trim(),
          'email': userEmail,
          _phoneFieldKey: _phoneNumberController.text.trim(),
          _countryCodeFieldKey: _countryCodeController.text.trim(),
          _dobFieldKey: _dateOfBirthController.text.trim(),
          _addressFieldKey: _addressController.text.trim(),
          _addressLine2FieldKey: _addressLine2Controller.text.trim(),
          _stateFieldKey: _stateController.text.trim(),
          _pinCodeFieldKey: _pinCodeController.text.trim(),
          'role': roleName,
          'status': _isActive ? 'Active' : 'Inactive',
          'isVerified': _isActive,
          if (userData != null) ...userData,
        };
        // Use uploaded image URL if available, otherwise use API response, otherwise use existing
        if (profileImageUrl != null) {
          newUser['profileImage'] = profileImageUrl;
        } else if (userData?['profileImage'] != null) {
          newUser['profileImage'] = userData!['profileImage'];
        } else if (_imageUrl != null) {
          newUser['profileImage'] = _imageUrl;
        }

        String message = result['message'] ?? 'User created successfully (without wallet)';
        if (inviteResult['success'] == true) {
          message = 'Non-wallet user created and invite email sent successfully with username and password';
        } else {
          message = 'Non-wallet user created successfully, but failed to send invite email: ${inviteResult['message']}';
        }

        final userName = _nameController.text.trim();

        // Close the add user dialog first
        if (mounted) {
          Navigator.of(context).pop({
            'event': 'created',
            'user': newUser,
            'message': message,
            'sendInvite': inviteResult['success'] == true,
            'email': userEmail,
            'skipWallet': true,
            if (_imageBytes != null) 'imageBytes': _imageBytes,
          });
        }

        // Open permission selection dialog after user creation
        if (mounted && userId != null && userId.toString().isNotEmpty) {
          await _showPermissionDialog(userId.toString(), userName, userEmail, roleName);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Failed to create user'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create user: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _handleSendInvite() {
    if (_isSubmitting) {
      return;
    }
    Navigator.of(context).pop({
      'event': 'sendInvite',
      'email': _emailController.text.trim(),
    });
  }

  /// Show permission selection dialog after user creation
  Future<void> _showPermissionDialog(
    String userId,
    String userName,
    String userEmail,
    String userRole,
  ) async {
    if (!mounted) return;

    // Wait a bit for the dialog to close completely
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    // Show success message first
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('User created successfully. Please assign permissions.'),
        backgroundColor: AppTheme.secondaryColor,
        duration: const Duration(seconds: 2),
      ),
    );

    // Show permission dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => UserPermissionsDialog(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        userRole: userRole,
      ),
    );

    // Show success message if permissions were saved
    if (mounted && result != null && result['success'] == true) {
      final permissionsCount = result['permissionsCount'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            permissionsCount > 0
                ? 'Permissions assigned successfully for $userName ($permissionsCount permissions)'
                : 'User created successfully for $userName (no permissions assigned)',
          ),
          backgroundColor: AppTheme.secondaryColor,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (mounted && result == null) {
      // User closed dialog without saving - show reminder
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User $userName created but no permissions assigned yet. You can assign permissions later from the Roles screen.'),
          backgroundColor: AppTheme.warningColor ?? AppTheme.secondaryColor,
          duration: const Duration(seconds: 4),
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

  Color _tintColor(Color color, double amount) {
    final HSLColor hsl = HSLColor.fromColor(color);
    final double lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
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
    final List<DateFormat> formats = <DateFormat>[
      _dateFormat,
      DateFormat('yyyy-MM-dd'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('yyyy/MM/dd'),
    ];
    for (final format in formats) {
      try {
        return format.parseStrict(trimmed);
      } catch (_) {
        continue;
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

