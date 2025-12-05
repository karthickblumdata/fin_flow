import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    if (_emailFormKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final result = await AuthService.forgotPassword(
        _emailController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Password has been reset and sent to your email. Please check your inbox.'),
              backgroundColor: AppTheme.secondaryColor,
              duration: const Duration(seconds: 5),
            ),
          );

          // Navigate back to login after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              context.pop();
            }
          });
        } else {
          // Show error with better formatting
          final errorMessage = result['message'] ?? 'Failed to send reset link';
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Forgot Password'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.getMaxContentWidth(context),
            ),
            child: _buildEmailForm(isMobile),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm(bool isMobile) {
    return Form(
      key: _emailFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.lock_reset_outlined,
            size: isMobile ? 64 : 80,
            color: AppTheme.primaryColor,
          ),
          SizedBox(height: isMobile ? 24 : 32),
          Text(
            'Forgot Password?',
            style: AppTheme.headingLarge.copyWith(
              fontSize: isMobile ? 24 : 28,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            'Enter your registered email address and we\'ll send you a new password based on your name and date of birth',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              fontSize: isMobile ? 14 : 16,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isMobile ? 48 : 56),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSendResetLink(),
            style: TextStyle(fontSize: isMobile ? 16 : 17),
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'Enter your registered email',
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email address';
              }
              if (!EmailValidator.validate(value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 24 : 32),
          SizedBox(
            height: isMobile ? 52 : 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSendResetLink,
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
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              'Back to Login',
              style: TextStyle(fontSize: isMobile ? 14 : 15),
            ),
          ),
        ],
      ),
    );
  }

}

