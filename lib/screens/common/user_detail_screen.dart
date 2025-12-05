import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../services/audit_log_service.dart';
import '../../services/auth_service.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final String userRole;
  
  const UserDetailScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
  });

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  int _selectedTab = 0; // 0: Overview, 1: Transfers, 2: Collections, 3: Expenses
  
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _wallet;
  List<dynamic> _transactions = [];
  List<dynamic> _collections = [];
  List<dynamic> _expenses = [];
  List<dynamic> _auditLogs = [];
  Map<String, dynamic>? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuditLogService.getUserActivity(widget.userId);
      if (result['success'] == true && mounted) {
        setState(() {
          _userData = result['user'];
          _wallet = result['wallet'];
          _transactions = result['transactions'] ?? [];
          _collections = result['collections'] ?? [];
          _expenses = result['expenses'] ?? [];
          _auditLogs = result['auditLogs'] ?? [];
          _summary = result['summary'] ?? {};
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Align(
          alignment: Alignment.centerLeft,
          child: _buildUserInfoInAppBar(isMobile),
        ),
        actions: [
          // Navigation buttons in app bar
          if (!isMobile) ...[
            _buildNavButton(Icons.info_outline, 'Overview', 0),
            _buildNavButton(Icons.swap_horiz, 'Transfers', 1),
            _buildNavButton(Icons.payment, 'Collections', 2),
            _buildNavButton(Icons.receipt, 'Expenses', 3),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await AuthService.logout();
                if (mounted) {
                  context.go('/login');
                }
              } catch (e) {
                if (mounted) {
                  context.go('/login');
                }
              }
            },
            tooltip: 'Logout',
          ),
        ],
        bottom: isMobile
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMobileNavButton(Icons.info_outline, 'Overview', 0),
                      _buildMobileNavButton(Icons.swap_horiz, 'Transfers', 1),
                      _buildMobileNavButton(Icons.payment, 'Collections', 2),
                      _buildMobileNavButton(Icons.receipt, 'Expenses', 3),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _getCurrentTab(),
    );
  }

  Widget _buildOverviewTab() {
    final isMobile = Responsive.isMobile(context);
    final walletBalance = _wallet != null ? (_wallet!['totalBalance'] ?? 0.0).toDouble() : 0.0;
    final cashBalance = _wallet != null ? (_wallet!['cashBalance'] ?? 0.0).toDouble() : 0.0;
    final upiBalance = _wallet != null ? (_wallet!['upiBalance'] ?? 0.0).toDouble() : 0.0;
    final bankBalance = _wallet != null ? (_wallet!['bankBalance'] ?? 0.0).toDouble() : 0.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Wallet Balance Card - Narrower and neater
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallet Balance',
                    style: AppTheme.headingSmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBalanceCard(
                          'Total',
                          walletBalance,
                          Icons.account_balance_wallet,
                          AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildBalanceCard(
                          'Cash',
                          cashBalance,
                          Icons.money,
                          AppTheme.secondaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildBalanceCard(
                          'UPI',
                          upiBalance,
                          Icons.payment,
                          AppTheme.warningColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildBalanceCard(
                          'Bank',
                          bankBalance,
                          Icons.account_balance,
                          AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Actions - Attractive Design
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.borderColor),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.05),
                    AppTheme.secondaryColor.withValues(alpha: 0.05),
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.bolt,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Quick Actions',
                          style: AppTheme.headingSmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (isMobile)
                      Column(
                        children: [
                          _buildAttractiveQuickActionButton(
                            'Add Collection',
                            'for ${widget.userName}',
                            Icons.payment,
                            AppTheme.secondaryColor,
                            () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Add Collection feature is currently unavailable'),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildAttractiveQuickActionButton(
                            'Add Transfer',
                            'Between users',
                            Icons.swap_horiz,
                            AppTheme.primaryColor,
                            () async {
                              final result = await Navigator.pushNamed(context, '/transfer');
                              if (result == true && mounted) {
                                _loadUserData();
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildAttractiveQuickActionButton(
                            'Add Expenses',
                            'Record expense',
                            Icons.receipt,
                            AppTheme.warningColor,
                            () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Expenses feature is currently unavailable'),
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _buildAttractiveQuickActionButton(
                              'Add Collection',
                              'for ${widget.userName}',
                              Icons.payment,
                              AppTheme.secondaryColor,
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Add Collection feature is currently unavailable'),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAttractiveQuickActionButton(
                              'Add Transfer',
                              'Between users',
                              Icons.swap_horiz,
                              AppTheme.primaryColor,
                              () async {
                                final result = await context.push('/transfer');
                                if (result == true && mounted) {
                                  _loadUserData();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAttractiveQuickActionButton(
                              'Add Expenses',
                              'Record expense',
                              Icons.receipt,
                              AppTheme.warningColor,
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Expenses feature is currently unavailable'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Summary Stats
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity Summary',
                    style: AppTheme.headingSmall,
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow(
                    'Total Transactions',
                    (_summary?['totalTransactions'] ?? 0).toString(),
                    Icons.swap_horiz,
                  ),
                  const Divider(),
                  _buildSummaryRow(
                    'Total Collections',
                    (_summary?['totalCollections'] ?? 0).toString(),
                    Icons.payment,
                  ),
                  const Divider(),
                  _buildSummaryRow(
                    'Total Expenses',
                    (_summary?['totalExpenses'] ?? 0).toString(),
                    Icons.receipt,
                  ),
                  const Divider(),
                  _buildSummaryRow(
                    'Audit Logs',
                    (_summary?['totalAuditLogs'] ?? 0).toString(),
                    Icons.history,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String label, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₹${_formatAmount(amount)}',
            style: AppTheme.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No transactions found',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final transaction = _transactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildTransactionCard(dynamic transaction) {
    final date = transaction['createdAt'] != null
        ? DateTime.parse(transaction['createdAt']).toLocal()
        : DateTime.now();
    final amount = (transaction['amount'] ?? 0).toDouble();
    final status = transaction['status'] ?? 'Pending';
    final sender = transaction['sender']?['name'] ?? 'Unknown';
    final receiver = transaction['receiver']?['name'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Icon(Icons.swap_horiz, color: AppTheme.primaryColor),
        ),
        title: Text('$sender → $receiver'),
        subtitle: Text(
          '${_formatDate(date)} • ${transaction['mode'] ?? 'Cash'}',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${_formatAmount(amount)}',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: AppTheme.bodySmall.copyWith(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionsTab() {
    if (_collections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No collections found',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _collections.length,
      itemBuilder: (context, index) {
        final collection = _collections[index];
        return _buildCollectionCard(collection);
      },
    );
  }

  Widget _buildCollectionCard(dynamic collection) {
    final date = collection['createdAt'] != null
        ? DateTime.parse(collection['createdAt']).toLocal()
        : DateTime.now();
    final amount = (collection['amount'] ?? 0).toDouble();
    final status = collection['status'] ?? 'Pending';
    final voucherNumber = collection['voucherNumber'] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.1),
          child: Icon(Icons.payment, color: AppTheme.secondaryColor),
        ),
        title: Text(collection['customerName'] ?? 'Collection'),
        subtitle: Text(
          'Voucher: $voucherNumber • ${_formatDate(date)}',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${_formatAmount(amount)}',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: AppTheme.bodySmall.copyWith(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesTab() {
    if (_expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No expenses found',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final expense = _expenses[index];
        return _buildExpenseCard(expense);
      },
    );
  }

  Widget _buildExpenseCard(dynamic expense) {
    final date = expense['createdAt'] != null
        ? DateTime.parse(expense['createdAt']).toLocal()
        : DateTime.now();
    final amount = (expense['amount'] ?? 0).toDouble();
    final status = expense['status'] ?? 'Pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1),
          child: Icon(Icons.receipt, color: AppTheme.errorColor),
        ),
        title: Text(expense['category'] ?? 'Expense'),
        subtitle: Text(
          '${expense['description'] ?? ''} • ${_formatDate(date)}',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${_formatAmount(amount)}',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: AppTheme.bodySmall.copyWith(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'approved':
        return AppTheme.secondaryColor;
      case 'pending':
        return AppTheme.warningColor;
      case 'rejected':
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}-${_getMonthAbbr(date.month)}-${date.year.toString().substring(2)}';
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildUserInfoInAppBar(bool isMobile) {
    if (isMobile) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
            child: Icon(
              widget.userRole == 'SuperAdmin'
                  ? Icons.admin_panel_settings
                  : widget.userRole == 'Admin'
                      ? Icons.manage_accounts
                      : Icons.person,
              color: AppTheme.primaryColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.userName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.userRole,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      );
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Icon(
            widget.userRole == 'SuperAdmin'
                ? Icons.admin_panel_settings
                : widget.userRole == 'Admin'
                    ? Icons.manage_accounts
                    : Icons.person,
            color: AppTheme.primaryColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.userName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.userEmail,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            widget.userRole,
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttractiveQuickActionButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String label, int index) {
    final isSelected = _selectedTab == index;
    return TextButton.icon(
      onPressed: () {
        setState(() {
          _selectedTab = index;
        });
      },
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
        backgroundColor: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildMobileNavButton(IconData icon, String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTheme.bodySmall.copyWith(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getCurrentTab() {
    switch (_selectedTab) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildTransactionsTab();
      case 2:
        return _buildCollectionsTab();
      case 3:
        return _buildExpensesTab();
      default:
        return _buildOverviewTab();
    }
  }
}


