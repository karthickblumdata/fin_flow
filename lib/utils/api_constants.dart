class ApiConstants {
  // Base URL - Connected to backend-1
  // For Android Emulator: use 'http://10.0.2.2:4455/api' OR your computer's IP
  // For iOS Simulator: use 'http://localhost:4455/api'
  // For Physical Device: use 'http://YOUR_COMPUTER_IP:4455/api'
  // Alternative: Use your computer's IP address if 10.0.2.2 doesn't work
  // NOTE: Backend server runs on port 4455 by default (check backend/server.js)
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://localhost:4455/api',
  );
  
  // Authentication endpoints
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  
  // OTP endpoints
  static const String verifyOtp = '/otp/verify';
  static const String setPassword = '/otp/set-password';
  static const String sendOtp = '/otp/send';
  
  // User endpoints
  static const String createUser = '/users/create';
  static const String sendInvite = '/users/send-invite';
  static const String uploadUserProfileImage = '/users/upload-image';
  static const String getUsers = '/users';
  static String deleteUser(String userId) => '/users/$userId';
  static String updateUser(String userId) => '/users/$userId';
  
  // Role endpoints
  static const String createRole = '/roles/create';
  static String getRolePermissions(String roleName) => '/roles/$roleName/permissions';
  static String updateRolePermissions(String roleName) => '/roles/$roleName/permissions';
  static const String getAllRoles = '/roles';
  
  // Permission endpoints
  static const String getAllPermissions = '/permissions';
  static const String createPermission = '/permissions/create';
  static String getPermissionById(String id) => '/permissions/$id';
  static String updatePermission(String id) => '/permissions/$id';
  static String deletePermission(String id) => '/permissions/$id';
  
  // User permission endpoints
  static String getUserPermissions(String userId) => '/users/$userId/permissions';
  static String updateUserPermissions(String userId) => '/users/$userId/permissions';
  static const String refreshCurrentUserPermissions = '/auth/me/permissions';
  
  // Wallet endpoints
  static const String getWallet = '/wallet';
  static const String getAllWallets = '/wallet/all';
  static const String addWallet = '/wallet/add';
  static const String withdrawWallet = '/wallet/withdraw';
  static const String resetWallet = '/wallet/reset';
  static const String getWalletReport = '/wallet/report'; // Deprecated - use getSelfWalletReport or getAllWalletReport
  static const String getSelfWalletReport = '/wallet/report/self';
  static const String getAllWalletReport = '/wallet/report/all';
  static const String getWalletTransactions = '/wallet/transactions';
  static const String transferBetweenModes = '/wallet/transfer/mode';
  static const String transferBetweenUsers = '/wallet/transfer/user';
  static const String getWalletSettings = '/wallet/settings';
  static const String updateWalletSettings = '/wallet/settings';
  static const String exportWalletReport = '/wallet/report/export';
  static const String getWalletAnalytics = '/wallet/analytics';
  
  // Account endpoints
  static const String addAmountToAccount = '/accounts/add-amount';
  static const String withdrawFromAccount = '/accounts/withdraw';
  
  // All Wallet Reports endpoints
  static const String getAllWalletReportsTotals = '/all-wallet-reports/totals';
  static String getUserWalletReport(String userId) => '/all-wallet-reports/user/$userId';
  static const String getAllWalletReports = '/all-wallet-reports';
  
  // Transaction endpoints
  static const String createTransaction = '/transactions';
  static const String getTransactions = '/transactions';
  static const String approveTransaction = '/transactions'; // /:id/approve
  static const String rejectTransaction = '/transactions'; // /:id/reject
  static const String cancelTransaction = '/transactions'; // /:id/cancel
  static const String flagTransaction = '/transactions'; // /:id/flag
  
  // Collection endpoints
  static const String createCollection = '/collections';
  static const String getCollections = '/collections';
  static const String approveCollection = '/collections'; // /:id/approve
  static const String rejectCollection = '/collections'; // /:id/reject
  static const String flagCollection = '/collections'; // /:id/flag
  static const String editCollection = '/collections'; // /:id
  static const String restoreCollection = '/collections'; // /:id/restore
  
  // Expense endpoints
  static const String createExpense = '/expenses';
  static const String getExpenses = '/expenses';
  static const String uploadExpenseProofImage = '/expenses/upload-image';
  static const String approveExpense = '/expenses'; // /:id/approve
  static const String rejectExpense = '/expenses'; // /:id/reject
  static const String flagExpense = '/expenses'; // /:id/flag
  static const String editExpense = '/expenses'; // /:id
  
  // Payment Mode endpoints
  static const String createPaymentMode = '/payment-modes';
  static const String getPaymentModes = '/payment-modes';
  static const String updatePaymentMode = '/payment-modes'; // /:id
  static const String deletePaymentMode = '/payment-modes'; // /:id
  
  // Expense Type endpoints
  static const String createExpenseType = '/expense-types';
  static const String getExpenseTypes = '/expense-types';
  static const String updateExpenseTypeBase = '/expense-types'; // /:id
  static const String deleteExpenseTypeBase = '/expense-types'; // /:id
  static const String uploadExpenseTypeImage = '/expense-types/upload-image';
  
  // Dashboard endpoints
  static const String getDashboard = '/dashboard';
  static const String getDashboardSummary = '/dashboard/summary';
  
  // Report endpoints
  static const String getReports = '/reports';
  static const String getPersonWiseReports = '/reports/person-wise';
  static const String saveReport = '/reports/save';
  static const String getSavedReports = '/reports/saved';
  static String getSavedReport(String id) => '/reports/saved/$id';
  static String updateSavedReport(String id) => '/reports/saved/$id';
  static String deleteSavedReport(String id) => '/reports/saved/$id';
  static String duplicateSavedReport(String id) => '/reports/saved/$id/duplicate';
  static const String getReportTemplates = '/reports/templates';
  static const String getPendingApprovals = '/pending-approvals';
  static const String exportPendingApprovals = '/pending-approvals/export';
  
  // Audit Log endpoints
  static const String getAuditLogs = '/audit-logs';
  static const String getRecentActivity = '/audit-logs/recent';
  static String getUserActivity(String userId) => '/audit-logs/user/$userId';

  // Settings endpoints
  static const String getActionButtonSettings = '/settings/action-buttons';
  static const String updateActionButtonSettings = '/settings/action-buttons';
  static const String resetActionButtonSettings = '/settings/action-buttons/reset';
  
  // Helper methods
  static String transactionApprove(String id) => '$getTransactions/$id/approve';
  static String transactionReject(String id) => '$getTransactions/$id/reject';
  static String transactionCancel(String id) => '$getTransactions/$id/cancel';
  static String transactionFlag(String id) => '$getTransactions/$id/flag';
  static String transactionResubmit(String id) => '$getTransactions/$id/resubmit';
  static String transactionEdit(String id) => '$getTransactions/$id';
  
  static String collectionApprove(String id) => '$getCollections/$id/approve';
  static String collectionReject(String id) => '$getCollections/$id/reject';
  static String collectionFlag(String id) => '$getCollections/$id/flag';
  static String collectionResubmit(String id) => '$getCollections/$id/resubmit';
  static String collectionEdit(String id) => '$getCollections/$id';
  static String collectionRestore(String id) => '$getCollections/$id/restore';
  
  static String expenseApprove(String id) => '$getExpenses/$id/approve';
  static String expenseReject(String id) => '$getExpenses/$id/reject';
  static String expenseFlag(String id) => '$getExpenses/$id/flag';
  static String expenseResubmit(String id) => '$getExpenses/$id/resubmit';
  static String expenseEdit(String id) => '$getExpenses/$id';
  
  static String paymentModeUpdate(String id) => '$getPaymentModes/$id';
  static String paymentModeDelete(String id) => '$getPaymentModes/$id';
  
  static String updateExpenseType(String id) => '$updateExpenseTypeBase/$id';
  static String deleteExpenseType(String id) => '$deleteExpenseTypeBase/$id';
  
  static String walletTransactionById(String id) => '$getWalletTransactions/$id';
}
