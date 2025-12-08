import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/registration_screen.dart';
import '../screens/auth/set_password_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/super_admin/super_admin_dashboard.dart';
import '../screens/common/all_user_wallets_screen.dart';
import '../screens/common/reports_screen.dart';
import '../screens/common/roles_screen.dart';
import '../screens/common/wallet_screen.dart';
import '../screens/common/transfer_screen.dart';
import '../screens/common/manage_users_screen.dart';
import '../screens/common/payment_modes_screen.dart';
import '../screens/common/edit_user_screen.dart';
import '../screens/common/account_management_screen.dart';
import '../screens/common/collections_screen.dart';
import '../screens/common/pending_approvals_screen.dart';
import '../screens/super_admin/super_admin_settings_screen.dart';
import '../constants/nav_item.dart';
import '../services/auth_service.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    // Auth Routes
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/registration',
      name: 'registration',
      builder: (context, state) => const RegistrationScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/set-password',
      name: 'set-password',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'];
        return SetPasswordScreen(email: email);
      },
    ),
    GoRoute(
      path: '/reset-password',
      name: 'reset-password',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'];
        final token = state.uri.queryParameters['token'];
        return ResetPasswordScreen(email: email, token: token);
      },
    ),

    // Dashboard Routes - Each NavItem gets its own path
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      redirect: (context, state) async {
        // Block non-wallet users from accessing dashboard
        final isNonWallet = await AuthService.isNonWalletUser();
        if (isNonWallet) {
          return '/wallet/all'; // Redirect to All User Wallets
        }
        return null; // Allow access
      },
      builder: (context, state) => SuperAdminDashboard(
        initialSelectedItem: NavItem.dashboard,
      ),
    ),
    GoRoute(
      path: '/wallet/self',
      name: 'wallet-self',
      redirect: (context, state) async {
        // Block non-wallet users from accessing My Wallet
        final isNonWallet = await AuthService.isNonWalletUser();
        if (isNonWallet) {
          return '/wallet/all'; // Redirect to All User Wallets
        }
        return null; // Allow access
      },
      builder: (context, state) => SuperAdminDashboard(
        initialSelectedItem: NavItem.walletSelf,
      ),
    ),
    GoRoute(
      path: '/wallet/all',
      name: 'wallet-all',
      builder: (context, state) => SuperAdminDashboard(
        initialSelectedItem: NavItem.walletAll,
      ),
    ),
    GoRoute(
      path: '/wallet/overview',
      name: 'wallet-overview',
      builder: (context, state) {
        final userId = state.uri.queryParameters['userId'];
        final userLabel = state.uri.queryParameters['userLabel'];
        return SuperAdminDashboard(
          initialSelectedItem: NavItem.walletOverview,
          initialUserId: userId,
          initialUserLabel: userLabel,
        );
      },
    ),
    GoRoute(
      path: '/transactions/collections',
      name: 'transactions-collections',
      builder: (context, state) => SuperAdminDashboard(
        initialSelectedItem: NavItem.transactionCollection,
      ),
    ),
    GoRoute(
      path: '/transactions/transfer',
      name: 'transactions-transfer',
      builder: (context, state) => SuperAdminDashboard(
        initialSelectedItem: NavItem.transactionTransfer,
      ),
    ),
    GoRoute(
      path: '/transactions/expense',
      name: 'transactions-expense',
      builder: (context, state) => SuperAdminDashboard(
        initialSelectedItem: NavItem.transactionExpense,
      ),
    ),
    GoRoute(
      path: '/transactions/all',
      name: 'transactions-all',
      builder: (context, state) => SuperAdminDashboard(
        initialSelectedItem: NavItem.transactionTransactions,
      ),
    ),
    GoRoute(
      path: '/users',
      name: 'users',
      builder: (context, state) => SuperAdminDashboard(
        initialSelectedItem: NavItem.users,
      ),
    ),
    GoRoute(
      path: '/roles',
      name: 'roles',
      builder: (context, state) {
        final highlightRole = state.uri.queryParameters['highlightRole'];
        return SuperAdminDashboard(
          initialSelectedItem: NavItem.roles,
        );
      },
    ),
    GoRoute(
      path: '/users/assign-wallets',
      name: 'assign-wallets',
      builder: (context, state) => SuperAdminDashboard(
        initialSelectedItem: NavItem.assignWallets,
      ),
    ),
    GoRoute(
      path: '/reports/accounts',
      name: 'reports-accounts',
      builder: (context, state) => SuperAdminDashboard(
        initialSelectedItem: NavItem.accountReports,
      ),
    ),
    GoRoute(
      path: '/payment-modes',
      name: 'payment-modes',
      builder: (context, state) => SuperAdminDashboard(
        initialSelectedItem: NavItem.paymentModes,
      ),
    ),
    GoRoute(
      path: '/expenses/types',
      name: 'expenses-types',
      builder: (context, state) => SuperAdminDashboard(
        initialSelectedItem: NavItem.expenseType,
      ),
    ),
    GoRoute(
      path: '/reports/expenses',
      name: 'reports-expenses',
      builder: (context, state) => SuperAdminDashboard(
        initialSelectedItem: NavItem.expenseReport,
      ),
    ),
    GoRoute(
      path: '/approvals/smart',
      name: 'approvals-smart',
      builder: (context, state) => SuperAdminDashboard(
        initialSelectedItem: NavItem.smartApprovals,
      ),
    ),
    GoRoute(
      path: '/settings/collection-custom-field',
      name: 'collection-custom-field',
      builder: (context, state) => SuperAdminDashboard(
        initialSelectedItem: NavItem.collectionCustomField,
      ),
    ),

    // Legacy route for backward compatibility
    GoRoute(
      path: '/super-admin-dashboard',
      name: 'super-admin-dashboard',
      redirect: (context, state) => '/dashboard',
    ),

    // Other Routes
    GoRoute(
      path: '/reports',
      name: 'reports',
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      path: '/wallet',
      name: 'wallet',
      redirect: (context, state) async {
        // Block non-wallet users from accessing My Wallet screen
        final isNonWallet = await AuthService.isNonWalletUser();
        if (isNonWallet) {
          return '/wallet/all'; // Redirect to All User Wallets
        }
        return null; // Allow access
      },
      builder: (context, state) => const WalletScreen(),
    ),
    GoRoute(
      path: '/transfer',
      name: 'transfer',
      builder: (context, state) => const TransferScreen(),
    ),
    GoRoute(
      path: '/manage-users',
      name: 'manage-users',
      builder: (context, state) => const ManageUsersScreen(),
    ),
    GoRoute(
      path: '/all-user-wallets',
      name: 'all-user-wallets',
      builder: (context, state) => const AllUserWalletsScreen(),
    ),
    GoRoute(
      path: '/super-admin-settings',
      name: 'super-admin-settings',
      builder: (context, state) => const SuperAdminSettingsScreen(wrapWithScaffold: true),
    ),
    GoRoute(
      path: '/collections',
      name: 'collections',
      builder: (context, state) => const CollectionsScreen(role: 'Staff'),
    ),
    GoRoute(
      path: '/add-account',
      name: 'add-account',
      builder: (context, state) => const AccountManagementScreen(),
    ),
    GoRoute(
      path: '/pending-approvals',
      name: 'pending-approvals',
      builder: (context, state) => const PendingApprovalsScreen(),
    ),
    GoRoute(
      path: '/edit-user',
      name: 'edit-user',
      builder: (context, state) {
        final userData = state.extra as Map<String, dynamic>?;
        if (userData != null && userData['user'] != null) {
          return EditUserScreen(user: userData['user'] as Map<String, dynamic>);
        }
        return const Scaffold(
          body: Center(
            child: Text('User details are required to edit.'),
          ),
        );
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}'),
    ),
  ),
);

