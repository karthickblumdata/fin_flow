import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../services/auth_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedRole = 'Staff';
  bool _isLoading = false;

  final List<String> _roles = ['Staff', 'Admin'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleRegistration() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final result = await AuthService.createUser(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _selectedRole,
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          if (result['success'] == true) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('✅ User created successfully! OTP sent to email.'),
                backgroundColor: AppTheme.secondaryColor,
                duration: const Duration(seconds: 3),
              ),
            );
            
            // Return true to indicate success and refresh the calling screen
            if (mounted) {
              // Check if we can pop (called from dashboard/manage users)
              if (Navigator.canPop(context)) {
                Navigator.pop(context, true);
              } else {
                // Called from login screen, navigate to login
                Navigator.pushReplacementNamed(context, '/login');
              }
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Failed to create user'),
                backgroundColor: AppTheme.errorColor,
                duration: const Duration(seconds: 4),
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
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(60.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_outlined,
                      size: Responsive.getIconSize(context) + 20,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Add New User',
                      style: TextStyle(
                        fontSize: Responsive.getTitleSize(context) + 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create accounts for your team members',
                      style: TextStyle(
                        fontSize: Responsive.getSubtitleSize(context) + 4,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: SingleChildScrollView(
              padding: Responsive.getPadding(context),
              child: SizedBox(
                width: Responsive.getFormWidth(context),
                child: _buildRegistrationForm(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_outlined,
                      size: Responsive.getIconSize(context),
                      color: Colors.white,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Add New User',
                      style: TextStyle(
                        fontSize: Responsive.getTitleSize(context),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Center(
            child: SingleChildScrollView(
              padding: Responsive.getPadding(context),
              child: SizedBox(
                width: Responsive.getFormWidth(context),
                child: _buildRegistrationForm(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: Responsive.getPadding(context),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.getMaxContentWidth(context),
          ),
          child: _buildRegistrationForm(context),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMobile) ...[
            Icon(
              Icons.person_add_outlined,
              size: Responsive.getIconSize(context),
              color: AppTheme.primaryColor,
            ),
            SizedBox(height: isMobile ? 24 : 32),
          ],

          Text(
            'Add New User',
            style: AppTheme.headingLarge.copyWith(
              fontSize: Responsive.getTitleSize(context),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isMobile ? 8 : 12),

          Text(
            'Create a new account for Admin or Staff',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              fontSize: Responsive.getSubtitleSize(context),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isMobile ? 48 : 56),

          TextFormField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            style: TextStyle(fontSize: isMobile ? 16 : 17),
            decoration: InputDecoration(
              labelText: 'Full Name',
              hintText: 'Enter user name',
              prefixIcon: const Icon(Icons.person_outline),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isMobile ? 16 : 18,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 16 : 20),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(fontSize: isMobile ? 16 : 17),
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'Enter user email',
              prefixIcon: const Icon(Icons.email_outlined),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isMobile ? 16 : 18,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an email address';
              }
              if (!EmailValidator.validate(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 16 : 20),

          Text(
            'Select Role',
            style: AppTheme.labelMedium.copyWith(
              fontSize: isMobile ? 14 : 15,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isMobile ? 16 : 18,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              icon: const Icon(Icons.keyboard_arrow_down),
              items: _roles.map((String role) {
                return DropdownMenuItem<String>(
                  value: role,
                  child: Row(
                    children: [
                      Icon(
                        role == 'Admin'
                            ? Icons.admin_panel_settings_outlined
                            : Icons.person_outline,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        role,
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 17,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedRole = newValue;
                  });
                }
              },
            ),
          ),
          SizedBox(height: isMobile ? 32 : 40),

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
                    'An OTP will be sent to the email address for verification',
                    style: AppTheme.bodySmall.copyWith(
                      fontSize: isMobile ? 12 : 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 32 : 40),

          SizedBox(
            height: isMobile ? 52 : 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegistration,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24 : 32,
                  vertical: isMobile ? 16 : 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Send OTP',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          SizedBox(height: isMobile ? 24 : 32),

          TextButton.icon(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            icon: const Icon(Icons.arrow_back),
            label: Text(Navigator.canPop(context) ? 'Back' : 'Back to Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // For desktop/tablet, use full screen layout without AppBar
    // For mobile, use AppBar
    if (Responsive.isDesktop(context) || Responsive.isTablet(context)) {
      return Scaffold(
        body: SafeArea(
          child: Responsive.isDesktop(context)
              ? _buildDesktopLayout(context)
              : _buildTabletLayout(context),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New User'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
        ),
      ),
      body: SafeArea(
        child: _buildMobileLayout(context),
      ),
    );
  }
}

