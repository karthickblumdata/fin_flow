import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../utils/ui_permission_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final result = await AuthService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result != null && result['success'] == true) {
          final user = result['user'] as Map<String, dynamic>?;
          if (user != null) {
            final role = user['role'] as String?;

            // Initialize Socket.IO for Super Admin (real-time updates)
            final prefs = await SharedPreferences.getInstance();
            final backendRole = prefs.getString('user_role');
            if (backendRole == 'SuperAdmin') {
              await SocketService.initialize();
              print('✅ Socket.IO initialized for Super Admin');
            }

            // Check if user is non-wallet user
            final isNonWallet = await AuthService.isNonWalletUser();
            
            if (isNonWallet) {
              // Non-wallet users: Redirect to All User Wallets view
              if (mounted) {
                context.go('/wallet/all');
              }
            } else {
              // Check if user has dashboard access permission
              final hasDashboardAccess = await UIPermissionChecker.canViewScreen('dashboard');
              
              if (hasDashboardAccess) {
                // User has dashboard access - route to dashboard
                // SuperAdmin goes to SuperAdminDashboard, others can also use it (it handles both)
                if (mounted) {
                  context.go('/dashboard');
                }
              } else {
                // User doesn't have dashboard permission
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('You do not have permission to access the dashboard. Please contact your administrator.'),
                      backgroundColor: AppTheme.errorColor,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
                return;
              }
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result?['message'] as String? ?? 'Invalid email or password',
                ),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
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
                      Icons.account_balance_wallet,
                      size: Responsive.getIconSize(context) + 20,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Financial Flow',
                      style: TextStyle(
                        fontSize: Responsive.getTitleSize(context) + 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Management System',
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
                child: _buildLoginForm(context),
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
                      Icons.account_balance_wallet,
                      size: Responsive.getIconSize(context),
                      color: Colors.white,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Financial Flow',
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
                child: _buildLoginForm(context),
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
          child: _buildLoginForm(context),
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMobile) ...[
            Icon(
              Icons.account_balance_wallet,
              size: Responsive.getIconSize(context),
              color: AppTheme.primaryColor,
            ),
            SizedBox(height: isMobile ? 24 : 32),
          ],

          Text(
            'Welcome Back',
            style: AppTheme.headingLarge.copyWith(
              fontSize: Responsive.getTitleSize(context),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isMobile ? 8 : 12),

          Text(
            'Sign in to manage your finances',
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
            style: TextStyle(fontSize: isMobile ? 16 : 17),
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!EmailValidator.validate(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 16 : 20),

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            style: TextStyle(fontSize: isMobile ? 16 : 17),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          SizedBox(height: isMobile ? 8 : 12),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                context.push('/forgot-password');
              },
              child: Text(
                'Forgot Password?',
                style: TextStyle(fontSize: isMobile ? 14 : 15),
              ),
            ),
          ),
          SizedBox(height: isMobile ? 24 : 32),

          SizedBox(
            height: isMobile ? 52 : 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
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
                      'Sign In',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          SizedBox(height: isMobile ? 32 : 40),

          if (isMobile || isTablet)
            Text(
              'Financial Flow Management System',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontSize: isMobile ? 12 : 13,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildPoweredBySection(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    return Positioned(
      bottom: isMobile ? 16 : 24,
      right: isMobile ? 16 : 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Powered by ',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontSize: isMobile ? 11 : 12,
            ),
          ),
          Image.asset(
            'assets/images/blumdata_logo.png',
            height: isMobile ? 20 : 24,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () async {
              final uri = Uri.parse('https://www.blumdata.com/');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(
              'Blumdata',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.primaryColor,
                fontSize: isMobile ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Responsive.isDesktop(context)
                ? _buildDesktopLayout(context)
                : Responsive.isTablet(context)
                    ? _buildTabletLayout(context)
                    : _buildMobileLayout(context),
            _buildPoweredBySection(context),
          ],
        ),
      ),
    );
  }
}

