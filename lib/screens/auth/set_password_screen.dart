import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../services/auth_service.dart';

class SetPasswordScreen extends StatefulWidget {
  final String? email;
  
  const SetPasswordScreen({super.key, this.email});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set email from widget parameter
    if (widget.email != null) {
      _emailController.text = widget.email!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Set password with OTP verification (combined in one API call)
        final result = await AuthService.setPassword(
          _emailController.text.trim(),
          _otpController.text.trim(),
          _passwordController.text,
        );

          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            if (result['success'] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('✅ Password set successfully! You can now login.'),
                  backgroundColor: AppTheme.secondaryColor,
                  duration: const Duration(seconds: 3),
                ),
              );

              // Navigate to login after 2 seconds
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              });
            } else {
              // Show error with better formatting
              final errorMessage = result['message'] ?? 'Failed to set password';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.errorColor,
                  duration: const Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
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
                      Icons.lock_outline,
                      size: Responsive.getIconSize(context) + 20,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Set Your Password',
                      style: TextStyle(
                        fontSize: Responsive.getTitleSize(context) + 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create a secure password for your account',
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
                child: _buildSetPasswordForm(context),
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
                      Icons.lock_outline,
                      size: Responsive.getIconSize(context),
                      color: Colors.white,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Set Your Password',
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
                child: _buildSetPasswordForm(context),
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
          child: _buildSetPasswordForm(context),
        ),
      ),
    );
  }

  Widget _buildSetPasswordForm(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMobile) ...[
            Icon(
              Icons.lock_outline,
              size: Responsive.getIconSize(context),
              color: AppTheme.primaryColor,
            ),
            SizedBox(height: isMobile ? 24 : 32),
          ],

          Text(
            'Set Your Password',
            style: AppTheme.headingLarge.copyWith(
              fontSize: Responsive.getTitleSize(context),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isMobile ? 8 : 12),

          Text(
            'Enter your OTP and create a new password',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              fontSize: Responsive.getSubtitleSize(context),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isMobile ? 48 : 56),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: widget.email != null, // Disable if email is provided
            style: TextStyle(fontSize: isMobile ? 16 : 17),
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'Enter your email',
              prefixIcon: const Icon(Icons.email_outlined),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isMobile ? 16 : 18,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email address';
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 16 : 20),

          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            maxLength: 4,
            style: TextStyle(fontSize: isMobile ? 16 : 17),
            decoration: InputDecoration(
              labelText: 'OTP Code',
              hintText: 'Enter 4-digit OTP',
              prefixIcon: const Icon(Icons.pin_outlined),
              counterText: '',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isMobile ? 16 : 18,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter OTP';
              }
              if (value.length != 4) {
                return 'OTP must be 4 digits';
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 16 : 20),

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            style: TextStyle(fontSize: isMobile ? 16 : 17),
            decoration: InputDecoration(
              labelText: 'New Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isMobile ? 16 : 18,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 16 : 20),

          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSetPassword(),
            style: TextStyle(fontSize: isMobile ? 16 : 17),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              hintText: 'Re-enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isMobile ? 16 : 18,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 32 : 40),

          SizedBox(
            height: isMobile ? 52 : 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSetPassword,
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
                      'Set Password',
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
              Navigator.of(context).pushReplacementNamed('/login');
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Responsive.isDesktop(context)
            ? _buildDesktopLayout(context)
            : Responsive.isTablet(context)
                ? _buildTabletLayout(context)
                : _buildMobileLayout(context),
      ),
    );
  }
}

