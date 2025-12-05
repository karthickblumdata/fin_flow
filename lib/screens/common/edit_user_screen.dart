import "dart:typed_data";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../../theme/app_theme.dart";
import "../../services/user_service.dart";
import "../../utils/profile_image_helper.dart";

class EditUserScreen extends StatefulWidget {
  const EditUserScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserSidebar extends StatefulWidget {
  const _EditUserSidebar({
    required this.currentRoute,
    required this.isCompact,
    required this.isSubmitting,
    required this.onSave,
  });

  final String? currentRoute;
  final bool isCompact;
  final bool isSubmitting;
  final VoidCallback onSave;

  @override
  State<_EditUserSidebar> createState() => _EditUserSidebarState();
}

class _EditUserSidebarState extends State<_EditUserSidebar> {
  static const String _dashboardRoute = '/super-admin-dashboard';
  static const String _manageUsersRoute = '/manage-users';
  static const String _rolesRoute = '/roles';
  static const String _walletRoute = '/wallet';
  static const String _allUserWalletsRoute = '/all-user-wallets';
  static const String _settingsRoute = '/super-admin-settings';
  static const String _editUserRoute = '/edit-user';

  static const Set<String> _userRoutes = {_manageUsersRoute, _rolesRoute, _editUserRoute};
  static const Set<String> _userManagementRoutes = {_manageUsersRoute, _editUserRoute};
  static const Set<String> _walletRoutes = {_walletRoute, _allUserWalletsRoute};

  bool _usersExpanded = false;
  bool _walletExpanded = false;

  @override
  void initState() {
    super.initState();
    _syncExpansionFromRoute();
  }

  @override
  void didUpdateWidget(covariant _EditUserSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRoute != widget.currentRoute) {
      _syncExpansionFromRoute();
    }
  }

  void _syncExpansionFromRoute() {
    final current = widget.currentRoute;
    _usersExpanded = _userRoutes.contains(current);
    _walletExpanded = _walletRoutes.contains(current);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCompactHeader(),
          Expanded(child: _buildCompactContent(context)),
          _buildSaveButton(
            context,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          ),
        ],
      );
    }

    return Container(
      color: AppTheme.surfaceColor,
      child: Column(
        children: [
          _buildExpandedHeader(context),
          Expanded(child: _buildExpandedContent(context)),
          const Divider(height: 1),
          _buildSaveButton(
            context,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.admin_panel_settings,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Super Admin',
                  style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Financial Management',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        _buildExpandedNavItem(
          context,
          icon: Icons.dashboard_outlined,
          title: 'Dashboard',
          isSelected: widget.currentRoute == _dashboardRoute,
          onTap: () => _navigateTo(_dashboardRoute),
        ),
        _buildExpandedSection(
          context,
          icon: Icons.people_outlined,
          title: 'All Users',
          isExpanded: _usersExpanded,
          hasSelectedChild: _userRoutes.contains(widget.currentRoute),
          onTap: () => setState(() => _usersExpanded = !_usersExpanded),
          children: [
            _buildExpandedSubItem(
              context,
              title: 'User Management',
              isSelected: _userManagementRoutes.contains(widget.currentRoute),
              onTap: () => _navigateTo(_manageUsersRoute),
            ),
            _buildExpandedSubItem(
              context,
              title: 'Roles',
              isSelected: widget.currentRoute == _rolesRoute,
              onTap: () => _navigateTo(_rolesRoute),
            ),
          ],
        ),
        _buildExpandedSection(
          context,
          icon: Icons.account_balance_wallet_outlined,
          title: 'Wallet',
          isExpanded: _walletExpanded,
          hasSelectedChild: _walletRoutes.contains(widget.currentRoute),
          onTap: () => setState(() => _walletExpanded = !_walletExpanded),
          children: [
            _buildExpandedSubItem(
              context,
              title: 'Self Wallet',
              isSelected: widget.currentRoute == _walletRoute,
              onTap: () => _navigateTo(_walletRoute),
            ),
            _buildExpandedSubItem(
              context,
              title: 'All User Wallets',
              isSelected: widget.currentRoute == _allUserWalletsRoute,
              onTap: () => _navigateTo(_allUserWalletsRoute),
            ),
          ],
        ),
        _buildExpandedNavItem(
          context,
          icon: Icons.settings_outlined,
          title: 'Settings',
          isSelected: widget.currentRoute == _settingsRoute,
          onTap: () => _navigateTo(_settingsRoute),
        ),
      ],
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
      ),
      child: const Row(
        children: [
          Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
          SizedBox(width: 12),
          Text(
            'Super Admin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactContent(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildCompactNavItem(
          context,
          icon: Icons.dashboard_outlined,
          title: 'Dashboard',
          isSelected: widget.currentRoute == _dashboardRoute,
          route: _dashboardRoute,
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(
              Icons.people_outlined,
              color: AppTheme.textSecondary,
            ),
            initiallyExpanded: _usersExpanded,
            title: Text(
              'All Users',
              style: TextStyle(
                fontWeight:
                    _userRoutes.contains(widget.currentRoute) ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            onExpansionChanged: (value) => setState(() => _usersExpanded = value),
            children: [
              _buildCompactNavItem(
                context,
                title: 'User Management',
                isSelected: _userManagementRoutes.contains(widget.currentRoute),
                route: _manageUsersRoute,
                dense: true,
              ),
              _buildCompactNavItem(
                context,
                title: 'Roles',
                isSelected: widget.currentRoute == _rolesRoute,
                route: _rolesRoute,
                dense: true,
              ),
            ],
          ),
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(
              Icons.account_balance_wallet_outlined,
              color: AppTheme.textSecondary,
            ),
            initiallyExpanded: _walletExpanded,
            title: Text(
              'Wallet',
              style: TextStyle(
                fontWeight:
                    _walletRoutes.contains(widget.currentRoute) ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            onExpansionChanged: (value) => setState(() => _walletExpanded = value),
            children: [
              _buildCompactNavItem(
                context,
                title: 'Self Wallet',
                isSelected: widget.currentRoute == _walletRoute,
                route: _walletRoute,
                dense: true,
              ),
              _buildCompactNavItem(
                context,
                title: 'All User Wallets',
                isSelected: widget.currentRoute == _allUserWalletsRoute,
                route: _allUserWalletsRoute,
                dense: true,
              ),
            ],
          ),
        ),
        _buildCompactNavItem(
          context,
          icon: Icons.settings_outlined,
          title: 'Settings',
          isSelected: widget.currentRoute == _settingsRoute,
          route: _settingsRoute,
        ),
      ],
    );
  }

  Widget _buildExpandedNavItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isSelected ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isExpanded,
    required bool hasSelectedChild,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    final Color iconColor = hasSelectedChild ? AppTheme.primaryColor : AppTheme.textSecondary;
    final Color titleColor = hasSelectedChild ? AppTheme.primaryColor : AppTheme.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          Material(
            color: hasSelectedChild ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon, color: iconColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: hasSelectedChild ? FontWeight.w600 : FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: iconColor,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded) ...children,
        ],
      ),
    );
  }

  Widget _buildExpandedSubItem(
    BuildContext context, {
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 40, right: 16, top: 4, bottom: 4),
      child: Material(
        color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: isSelected ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactNavItem(
    BuildContext context, {
    IconData? icon,
    required String title,
    required bool isSelected,
    required String route,
    bool dense = false,
  }) {
    final TextStyle? baseStyle = dense ? Theme.of(context).textTheme.bodyMedium : Theme.of(context).textTheme.bodyLarge;

    return ListTile(
      leading: icon != null
          ? Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            )
          : null,
      title: Text(
        title,
        style: baseStyle?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
        ),
      ),
      dense: dense,
      selected: isSelected,
      onTap: isSelected ? null : () => _navigateTo(route),
    );
  }

  void _navigateTo(String route) {
    if (route == widget.currentRoute) {
      return;
    }
    final navigator = Navigator.of(context);
    if (widget.isCompact) {
      navigator.pop();
      Future.microtask(() {
        navigator.pushNamed(route);
      });
    } else {
      navigator.pushNamed(route);
    }
  }

  Widget _buildSaveButton(BuildContext context, {required EdgeInsets padding}) {
    return Padding(
      padding: padding,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
          foregroundColor: AppTheme.primaryColor,
        ),
        onPressed: widget.isSubmitting ? null : widget.onSave,
        icon: widget.isSubmitting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(widget.isSubmitting ? 'Saving...' : 'Save changes'),
      ),
    );
  }
}

class _EditUserScreenState extends State<EditUserScreen> {
  static const double _wideLayoutBreakpoint = 960;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneNumberController;
  late final TextEditingController _dateOfBirthController;
  late final TextEditingController _addressController;
  late String _selectedRole;
  late bool _isActive;

  Uint8List? _imageBytes;
  String? _imageUrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _readString(widget.user['name']));
    _emailController = TextEditingController(text: _readString(widget.user['email']));
    _phoneNumberController =
        TextEditingController(text: _readString(widget.user['phoneNumber']));
    _dateOfBirthController =
        TextEditingController(text: _readString(widget.user['dateOfBirth']));
    _addressController = TextEditingController(text: _readString(widget.user['address']));
    _selectedRole = _readString(widget.user['role'], fallback: 'Staff');
    _isActive = _normalizeStatus(widget.user['status']) == 'active' ||
        (widget.user['isVerified'] is bool && widget.user['isVerified'] == true);
    _imageUrl = _extractImageUrl(widget.user);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _dateOfBirthController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isWide = width >= _wideLayoutBreakpoint;
    final String? currentRoute = ModalRoute.of(context)?.settings.name;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: !isWide && Navigator.of(context).canPop() ? 96 : null,
        leading: Builder(
          builder: (context) {
            final navigator = Navigator.of(context);
            final bool canPop = navigator.canPop();

            if (isWide) {
              if (!canPop) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => navigator.pop(),
              );
            }

            if (canPop) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                    onPressed: () => navigator.pop(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.menu),
                    tooltip: 'Menu',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ],
              );
            }

            return IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
        title: const Text('Edit User'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _handleSave,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 20),
              label: const Text('Save changes'),
            ),
          ),
        ],
      ),
      drawer: isWide
          ? null
          : Drawer(
              child: SafeArea(
                child: _EditUserSidebar(
                  currentRoute: currentRoute,
                  isCompact: true,
                  isSubmitting: _isSubmitting,
                  onSave: _handleSave,
                ),
              ),
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final EdgeInsets contentPadding = EdgeInsets.symmetric(
              horizontal: isWide ? 32 : 20,
              vertical: isWide ? 32 : 24,
            );
            final Widget formContent = _buildFormContent(
              context,
              padding: contentPadding,
              maxWidth: isWide ? 760 : 720,
            );

            if (!isWide) {
              return formContent;
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 280,
                  child: _EditUserSidebar(
                    currentRoute: currentRoute,
                    isCompact: false,
                    isSubmitting: _isSubmitting,
                    onSave: _handleSave,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: formContent),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    const double avatarSize = 96;

    ImageProvider? provider;
    if (_imageBytes != null) {
      provider = MemoryImage(_imageBytes!);
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      provider = NetworkImage(_imageUrl!);
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: avatarSize / 2,
          backgroundColor: AppTheme.surfaceColor,
          backgroundImage: provider,
          child: provider == null
              ? Icon(
                  Icons.person,
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  size: 40,
                )
              : null,
        ),
        Material(
          color: AppTheme.primaryColor,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _isSubmitting ? null : _pickImage,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.edit, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
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

      // Call backend API to update user
      final result = await UserService.updateUser(
        userId: userId.toString(),
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        role: _selectedRole,
      );

      if (!mounted) return;

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
      updatedUser['phoneNumber'] = _phoneNumberController.text.trim();
      updatedUser['dateOfBirth'] = _dateOfBirthController.text.trim();
      updatedUser['address'] = _addressController.text.trim();
      updatedUser['role'] = _selectedRole;
      updatedUser['status'] = _isActive ? 'Active' : 'Inactive';
      updatedUser['isVerified'] = _isActive;
      if (_imageUrl != null) {
        updatedUser['profileImage'] = _imageUrl;
      }

      // Merge backend response data
      if (result['user'] is Map<String, dynamic>) {
        updatedUser.addAll(result['user'] as Map<String, dynamic>);
      }

      if (!mounted) return;
      Navigator.pop(context, {
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

  Widget _buildFormContent(
    BuildContext context, {
    required EdgeInsets padding,
    required double maxWidth,
  }) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
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
                        Align(
                          child: Column(
                            children: [
                              _buildAvatarPicker(),
                              const SizedBox(height: 16),
                              _buildStatusPill(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader(
                          context,
                          icon: Icons.badge_outlined,
                          title: 'Basic Details',
                          subtitle: 'Keep the user\'s profile up to date.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
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
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          enabled: !_isSubmitting,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'Enter email address',
                          ),
                          validator: (value) {
                            final String trimmed = (value ?? '').trim();
                            if (trimmed.isEmpty) {
                              return 'Please enter the email address.';
                            }
                            final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                            if (!emailRegex.hasMatch(trimmed)) {
                              return 'Please enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneNumberController,
                          enabled: !_isSubmitting,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            hintText: 'Enter phone number',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _dateOfBirthController,
                          enabled: !_isSubmitting,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth',
                            hintText: 'Enter date of birth (optional)',
                            helperText: 'Optional - Date of birth is only required when creating a new user',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          enabled: !_isSubmitting,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.streetAddress,
                          maxLines: 3,
                          minLines: 1,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            hintText: 'Enter address',
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Super Admin', child: Text('Super Admin')),
                            DropdownMenuItem(value: 'SuperAdmin', child: Text('SuperAdmin')),
                            DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                            DropdownMenuItem(value: 'Staff', child: Text('Staff')),
                          ],
                          onChanged: _isSubmitting
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _selectedRole = value;
                                  });
                                },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionHeader(
                          context,
                          icon: Icons.verified_user_outlined,
                          title: 'Account Status',
                          subtitle: 'Control the user\'s ability to log in.',
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile.adaptive(
                          value: _isActive,
                          title: Text(
                            _isActive ? 'Active' : 'Inactive',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text('Disable to temporarily block access without deleting the account.'),
                          secondary: Icon(
                            _isActive ? Icons.check_circle : Icons.block,
                            color: _isActive ? AppTheme.secondaryColor : AppTheme.errorColor,
                          ),
                          onChanged: _isSubmitting
                              ? null
                              : (value) {
                                  setState(() {
                                    _isActive = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isActive
                              ? 'The user can access the platform and perform actions according to their role.'
                              : 'The user cannot access the platform until reactivated.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  color: AppTheme.errorColor.withValues(alpha: 0.05),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionHeader(
                          context,
                          icon: Icons.warning_amber_rounded,
                          title: 'Danger zone',
                          subtitle: 'Delete the user permanently from the system.',
                          titleColor: AppTheme.errorColor,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.4)),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.delete_forever, color: AppTheme.errorColor),
                            title: const Text('Delete user'),
                            subtitle: const Text('Remove the user and all associated access. This action cannot be undone.'),
                            trailing: FilledButton.tonalIcon(
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete'),
                              style: FilledButton.styleFrom(
                                foregroundColor: AppTheme.errorColor,
                                backgroundColor: AppTheme.errorColor.withValues(alpha: 0.12),
                              ),
                              onPressed: _isSubmitting ? null : _handleDelete,
                            ),
                          ),
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
    );
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

  Widget _buildStatusPill() {
    final bool active = _isActive;
    final Color color = active ? AppTheme.secondaryColor : AppTheme.errorColor;
    final String label = active ? 'Active' : 'Inactive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.verified_user : Icons.block,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete() async {
    if (_isSubmitting) return;
    final confirmed = await showDialog<bool>(
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
        Navigator.pop(context, {
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

  String _readString(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  String _normalizeStatus(dynamic value) {
    final raw = _readString(value).toLowerCase();
    if (raw.isEmpty && widget.user['isVerified'] is bool) {
      return (widget.user['isVerified'] as bool) ? 'active' : 'inactive';
    }
    return raw;
  }

  String? _extractImageUrl(Map<String, dynamic> user) {
    return ProfileImageHelper.extractImageUrl(user);
  }
}
