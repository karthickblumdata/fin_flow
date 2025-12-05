# Routing Migration Plan: Separate Paths for Each Screen

## Current Situation
- App uses `MaterialApp` with `routes` map and `onGenerateRoute`
- `SuperAdminDashboard` uses `NavItem` enum to switch between different views within the same widget
- All dashboard views share the same path: `/super-admin-dashboard`
- Navigation is done via state changes (`_selectedItem`) rather than URL paths

## Goal
- Migrate to `go_router` for better URL-based navigation
- Create unique paths for each `NavItem` view
- Enable direct URL access to each screen
- Maintain backward compatibility with existing navigation

## NavItem Enum Values (15 total)
1. `dashboard` - Main dashboard view
2. `walletSelf` - My Wallet
3. `walletAll` - All User Wallets
4. `walletOverview` - All Wallet Report
5. `transactionCollection` - Collections
6. `transactionTransfer` - Transfer
7. `transactionExpense` - Expenses
8. `transactionTransactions` - Transactions
9. `users` - User Management
10. `roles` - Roles
11. `accountReports` - Account Reports
12. `paymentModes` - Payment Mode
13. `expenseType` - Expenses Type
14. `expenseReport` - Expense Report
15. `smartApprovals` - Smart Approvals

## Proposed Path Structure

### Auth Routes
- `/login` → LoginScreen
- `/registration` → RegistrationScreen
- `/forgot-password` → ForgotPasswordScreen
- `/set-password?email=...` → SetPasswordScreen

### Dashboard Routes (New - Each NavItem gets its own path)
- `/dashboard` → SuperAdminDashboard(initialSelectedItem: NavItem.dashboard)
- `/wallet/self` → SuperAdminDashboard(initialSelectedItem: NavItem.walletSelf)
- `/wallet/all` → SuperAdminDashboard(initialSelectedItem: NavItem.walletAll)
- `/wallet/overview` → SuperAdminDashboard(initialSelectedItem: NavItem.walletOverview)
- `/transactions/collections` → SuperAdminDashboard(initialSelectedItem: NavItem.transactionCollection)
- `/transactions/transfer` → SuperAdminDashboard(initialSelectedItem: NavItem.transactionTransfer)
- `/transactions/expense` → SuperAdminDashboard(initialSelectedItem: NavItem.transactionExpense)
- `/transactions/all` → SuperAdminDashboard(initialSelectedItem: NavItem.transactionTransactions)
- `/users` → SuperAdminDashboard(initialSelectedItem: NavItem.users)
- `/roles` → SuperAdminDashboard(initialSelectedItem: NavItem.roles)
- `/reports/accounts` → SuperAdminDashboard(initialSelectedItem: NavItem.accountReports)
- `/payment-modes` → SuperAdminDashboard(initialSelectedItem: NavItem.paymentModes)
- `/expenses/types` → SuperAdminDashboard(initialSelectedItem: NavItem.expenseType)
- `/reports/expenses` → SuperAdminDashboard(initialSelectedItem: NavItem.expenseReport)
- `/approvals/smart` → SuperAdminDashboard(initialSelectedItem: NavItem.smartApprovals)

### Other Routes (Existing)
- `/reports` → ReportsScreen
- `/wallet` → WalletScreen
- `/transfer` → TransferScreen
- `/manage-users` → ManageUsersScreen
- `/all-user-wallets` → AllUserWalletsScreen
- `/super-admin-settings` → SuperAdminSettingsScreen
- `/collections` → CollectionsScreen
- `/add-account` → AccountManagementScreen
- `/pending-approvals` → PendingApprovalsScreen
- `/edit-user` → EditUserScreen (with user data in query params or state)

## Implementation Steps

### Step 1: Install/Verify go_router Dependency
- Check if `go_router` is in `pubspec.yaml`
- Add if missing: `go_router: ^latest_version`

### Step 2: Create Router Configuration File
- Create `lib/router/app_router.dart`
- Define all routes using `GoRoute`
- Handle query parameters for routes like `/set-password?email=...`
- Handle state passing for routes like `/edit-user`

### Step 3: Update main.dart
- Replace `MaterialApp` with `MaterialApp.router`
- Use `routerConfig` from `app_router.dart`
- Remove old `routes` map and `onGenerateRoute`
- Keep `navigatorObservers` for route tracking

### Step 4: Update Navigation Calls
- Replace `Navigator.pushNamed()` with `context.go()` or `context.push()`
- Update all navigation calls in:
  - `super_admin_dashboard.dart`
  - Other screen files
  - Any widgets that navigate

### Step 5: Update SuperAdminDashboard Navigation
- When user clicks sidebar menu items, use `context.go()` with new paths
- Update `_handleNavigation()` method to use router
- Ensure `initialSelectedItem` is properly set from route

### Step 6: Handle Deep Links
- Update deep link handling in router configuration
- Ensure `/set-password?email=...` works correctly
- Test URL-based navigation

### Step 7: Update Route Observer
- Ensure `routeObserver` works with go_router
- May need to use `GoRouter.of(context).routerDelegate` for observation

### Step 8: Testing
- Test all routes navigate correctly
- Test URL parameters work
- Test deep linking
- Test browser back/forward buttons
- Test direct URL access to each screen

## Benefits
1. ✅ Each screen has unique, bookmarkable URL
2. ✅ Better browser integration (back/forward buttons work)
3. ✅ Direct URL access to any screen
4. ✅ Cleaner URL structure
5. ✅ Better SEO for web version
6. ✅ Easier debugging with visible URLs

## Considerations
- Need to handle state preservation when navigating
- Query parameters for filters might need to be in URL
- Need to ensure all existing navigation still works
- May need to update route observer implementation

## Files to Modify
1. `lib/main.dart` - Replace MaterialApp with MaterialApp.router
2. `lib/router/app_router.dart` - NEW FILE: Router configuration
3. `lib/screens/super_admin/super_admin_dashboard.dart` - Update navigation calls
4. All other screen files with navigation calls
5. `pubspec.yaml` - Add go_router if missing

## Questions to Confirm
1. Path naming convention - Are the proposed paths acceptable?
2. Should filters/query params be in URL? (e.g., `/wallet/self?userId=123`)
3. Should we keep old routes for backward compatibility?
4. Any specific path preferences?

