import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../utils/route_observer.dart';
import '../../services/payment_mode_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletScreen extends StatefulWidget {
  final String? userRole;
  final bool embedInDashboard;
  const WalletScreen({super.key, this.userRole, this.embedInDashboard = false});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with RouteAware {
  String? _userRole;
  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  bool _isLoadingTransactions = true;
  bool _hasLoadedInitialData = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadWalletData();
    _hasLoadedInitialData = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Called when the top route has been popped off, and this route shows up.
  @override
  void didPopNext() {
    // User navigated back to this screen - refresh data
    if (_hasLoadedInitialData && !widget.embedInDashboard) {
      _loadWalletData();
    }
  }

  Future<void> _loadUserRole() async {
    // Use role from widget parameter if provided
    if (widget.userRole != null) {
      setState(() {
        _userRole = widget.userRole;
      });
      return;
    }
    
    // Get role from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    if (role != null) {
      setState(() {
        _userRole = role == 'SuperAdmin' ? 'Super Admin' : role == 'Admin' ? 'Admin' : 'Staff';
      });
    }
  }

  Future<void> _loadWalletData() async {
    setState(() {
      _isLoading = true;
    });

    // Backend API call removed - using empty wallet data
    if (mounted) {
      setState(() {
        _wallet = {
          'cashBalance': 0.0,
          'upiBalance': 0.0,
          'bankBalance': 0.0,
          'totalBalance': 0.0,
        };
        _isLoading = false;
      });
    }

    await _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoadingTransactions = true;
    });

    // Backend API call removed - using empty transactions list
    if (mounted) {
      setState(() {
        _transactions = [];
        _isLoadingTransactions = false;
      });
    }
  }

  // Helper function to extract payment mode name from transaction
  String _extractPaymentModeName(dynamic transaction) {
    if (transaction == null) return '';
    
    // Try nested paymentMode object first (from transformed data)
    final paymentMode = transaction['paymentMode'];
    if (paymentMode != null && paymentMode is Map) {
      final modeName = paymentMode['modeName'] ?? paymentMode['name'] ?? paymentMode['displayName'];
      if (modeName != null && modeName.toString().trim().isNotEmpty) {
        return modeName.toString().trim();
      }
    }
    
    // Try paymentModeId object directly (if populated but not transformed)
    final paymentModeId = transaction['paymentModeId'];
    if (paymentModeId != null && paymentModeId is Map) {
      final modeName = paymentModeId['modeName'] ?? paymentModeId['name'] ?? paymentModeId['displayName'];
      if (modeName != null && modeName.toString().trim().isNotEmpty) {
        return modeName.toString().trim();
      }
    }
    
    // Fallback: check mode field
    final mode = transaction['mode'];
    if (mode != null) {
      if (mode is Map) {
        // If mode is an object, extract name
        final modeName = mode['modeName'] ?? mode['name'] ?? mode['displayName'];
        if (modeName != null && modeName.toString().trim().isNotEmpty) {
          return modeName.toString().trim();
        }
      } else if (mode is String && mode.trim().isNotEmpty) {
        // If mode is a string, check if it's a name (not an ID)
        final modeStr = mode.trim();
        // If it doesn't look like an ObjectId, treat it as a name
        if (modeStr.length != 24 || !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(modeStr)) {
          return modeStr;
        }
      }
    }
    
    return '';
  }

  Map<String, dynamic> _formatTransaction(dynamic transaction) {
    final date = transaction['createdAt'] != null 
        ? DateTime.parse(transaction['createdAt']).toLocal()
        : DateTime.now();
    
    // Extract payment mode name (e.g., "ONLINE", "CASH ONE") instead of just payment method type (Cash, UPI, Bank)
    final mode = _extractPaymentModeName(transaction);
    final fallbackMode = transaction['mode']?.toString() ?? '';
    final finalMode = mode.isNotEmpty ? mode : fallbackMode;
    
    return {
      'id': transaction['_id'] ?? transaction['id'],
      'date': '${date.day}-${_getMonthAbbr(date.month)}-${date.year.toString().substring(2)}',
      'time': '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
      'user': transaction['sender']?['name'] ?? transaction['initiatedBy']?['name'] ?? '',
      'receiver': transaction['receiver']?['name'] ?? '',
      'mode': finalMode,
      'amount': '₹${_formatAmount(transaction['amount'] ?? 0)}',
      'description': transaction['purpose'] ?? '',
      'status': transaction['status'] ?? '',
      'type': 'Transaction',
    };
  }

  Map<String, dynamic> _formatWalletTransaction(dynamic transaction) {
    final date = transaction['createdAt'] != null 
        ? DateTime.parse(transaction['createdAt']).toLocal()
        : DateTime.now();
    
    final type = transaction['type'] ?? 'add';
    final typeLabel = type == 'add' ? 'Added' : type == 'withdraw' ? 'Withdrawn' : type == 'transfer' ? 'Transferred' : 'Transaction';
    
    // Extract payment mode name (e.g., "ONLINE", "CASH ONE") instead of just payment method type (Cash, UPI, Bank)
    final mode = _extractPaymentModeName(transaction);
    final fallbackMode = transaction['mode']?.toString() ?? transaction['fromMode']?.toString() ?? '';
    final finalMode = mode.isNotEmpty ? mode : fallbackMode;
    
    return {
      'id': transaction['_id'] ?? transaction['id'],
      'date': '${date.day}-${_getMonthAbbr(date.month)}-${date.year.toString().substring(2)}',
      'time': '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
      'user': transaction['userId']?['name'] ?? transaction['createdBy']?['name'] ?? '',
      'receiver': transaction['toUserId']?['name'] ?? '',
      'mode': finalMode,
      'amount': '₹${_formatAmount(transaction['amount'] ?? 0)}',
      'description': transaction['notes'] ?? '',
      'status': transaction['status'] ?? '',
      'type': typeLabel,
    };
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }


  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final content = SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title - only show if not embedded in dashboard
            if (!widget.embedInDashboard)
              Text(
                'Wallet Management',
                style: AppTheme.headingMedium.copyWith(
                  fontSize: isMobile ? 20 : 24,
                ),
              ),
            if (!widget.embedInDashboard) const SizedBox(height: 12),
            _buildWalletCard(context),
            if (_userRole == 'Super Admin') ...[
              const SizedBox(height: 12),
              Text(
                'Quick Actions',
                style: AppTheme.headingMedium.copyWith(
                  fontSize: isMobile ? 20 : 24,
                ),
              ),
              const SizedBox(height: 6),
              _buildQuickActions(context),
            ],
            const SizedBox(height: 12),
            Text(
              'Wallet Breakdown',
              style: AppTheme.headingMedium.copyWith(
                fontSize: isMobile ? 20 : 24,
              ),
            ),
            const SizedBox(height: 6),
            _buildWalletBreakdown(context),
            const SizedBox(height: 12),
            Text(
              'Recent Wallet Transactions',
              style: AppTheme.headingMedium.copyWith(
                fontSize: isMobile ? 20 : 24,
              ),
            ),
            const SizedBox(height: 6),
            _buildRecentTransactions(context),
          ],
        ),
      );

    if (widget.embedInDashboard) {
      return content;
    }
    
    return Scaffold(
      body: content,
    );
  }

  Widget _buildWalletCard(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    
    final totalBalance = _wallet != null 
        ? (_wallet!['totalBalance'] ?? 0.0).toDouble()
        : 0.0;
    final cashBalance = _wallet != null 
        ? (_wallet!['cashBalance'] ?? 0.0).toDouble()
        : 0.0;
    final upiBalance = _wallet != null 
        ? (_wallet!['upiBalance'] ?? 0.0).toDouble()
        : 0.0;
    final bankBalance = _wallet != null 
        ? (_wallet!['bankBalance'] ?? 0.0).toDouble()
        : 0.0;

    if (_isLoading) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.borderColor),
        ),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 20 : 28),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.all(isMobile ? 20 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Wallet Balance',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadWalletData,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '₹${_formatAmount(totalBalance)}',
              style: TextStyle(
                fontSize: isMobile ? 32 : 42,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildBalanceItem('Cash', '₹${_formatAmount(cashBalance)}', Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBalanceItem('UPI', '₹${_formatAmount(upiBalance)}', Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBalanceItem('Bank', '₹${_formatAmount(bankBalance)}', Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceItem(String label, String amount, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textColor.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildActionCard(
          context,
          'Add Amount',
          'Add funds to wallet',
          Icons.add_circle_outline,
          AppTheme.primaryColor,
          () {
            // Backend API call removed
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Add amount feature is currently unavailable'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          },
        ),
        _buildActionCard(
          context,
          'Withdraw',
          'Withdraw from wallet',
          Icons.remove_circle_outline,
          AppTheme.errorColor,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Withdraw feature is currently unavailable'),
              ),
            );
          },
        ),
        _buildActionCard(
          context,
          'Transfer',
          'Transfer between modes',
          Icons.swap_horiz,
          AppTheme.secondaryColor,
          () async {
            await _showTransferBetweenModesDialog(context);
          },
        ),
        _buildActionCard(
          context,
          'Add Collection',
          'Create new collection',
          Icons.payment_outlined,
          AppTheme.secondaryColor,
          () {
            // Backend API call removed
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Add collection feature is currently unavailable'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isMobile = Responsive.isMobile(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.borderColor),
        ),
        child: Container(
          width: isMobile ? double.infinity : 200,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTheme.headingSmall.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletBreakdown(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    
    final cashBalance = _wallet != null 
        ? (_wallet!['cashBalance'] ?? 0.0).toDouble()
        : 0.0;
    final upiBalance = _wallet != null 
        ? (_wallet!['upiBalance'] ?? 0.0).toDouble()
        : 0.0;
    final bankBalance = _wallet != null 
        ? (_wallet!['bankBalance'] ?? 0.0).toDouble()
        : 0.0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 5,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: isMobile ? 3.0 : 2.0,
      children: [
        _buildBreakdownCard('Cash', '₹${_formatAmount(cashBalance)}', Icons.money, AppTheme.primaryColor),
        _buildBreakdownCard('UPI', '₹${_formatAmount(upiBalance)}', Icons.qr_code, AppTheme.secondaryColor),
        _buildBreakdownCard('Bank', '₹${_formatAmount(bankBalance)}', Icons.account_balance, AppTheme.warningColor),
      ],
    );
  }

  Widget _buildBreakdownCard(String label, String amount, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      label,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      amount,
                      style: AppTheme.headingSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    
    if (_isLoadingTransactions) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.borderColor),
        ),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.borderColor),
        ),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No transactions found')),
        ),
      );
    }

    return Card(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!isMobile)
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text('Date', style: AppTheme.labelMedium)),
                        Expanded(flex: 2, child: Text('User', style: AppTheme.labelMedium)),
                        Expanded(flex: 1, child: Text('Mode', style: AppTheme.labelMedium)),
                        Expanded(flex: 2, child: Text('Amount', style: AppTheme.labelMedium)),
                        Expanded(flex: 3, child: Text('Description', style: AppTheme.labelMedium)),
                        Expanded(flex: 2, child: Text('Status', style: AppTheme.labelMedium)),
                      ],
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadTransactions,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            if (!isMobile) const SizedBox(height: 12),
            ...(_transactions.take(10).map((transaction) {
              return isMobile
                  ? _buildTxnCardMobile(transaction)
                  : _buildTxnRowDesktop(transaction);
            }).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTxnRowDesktop(Map<String, dynamic> transaction) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(transaction['date'], style: AppTheme.bodyMedium)),
          Expanded(flex: 2, child: Text(transaction['user'], style: AppTheme.bodyMedium)),
          Expanded(flex: 1, child: Text(transaction['mode'], style: AppTheme.bodyMedium)),
          Expanded(flex: 2, child: Text(transaction['amount'], style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 3, child: Text(transaction['description'], style: AppTheme.bodyMedium)),
          Expanded(
            flex: 2,
            child: Text(
              transaction['status'],
              style: AppTheme.bodyMedium.copyWith(
                color: _getStatusColor(transaction['status']),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTxnCardMobile(Map<String, dynamic> transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(transaction['date'], style: AppTheme.bodySmall),
                Text(
                  transaction['status'],
                  style: AppTheme.bodySmall.copyWith(
                    color: _getStatusColor(transaction['status']),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(transaction['description'], style: AppTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(transaction['user'], style: AppTheme.bodySmall),
                Text(transaction['mode'], style: AppTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(transaction['amount'], style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'Approved' || status == 'Completed') {
      return AppTheme.secondaryColor;
    } else if (status == 'Pending') {
      return AppTheme.warningColor;
    } else {
      return AppTheme.errorColor;
    }
  }

  Future<void> _showTransferBetweenModesDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String fromMode = 'Cash';
    String toMode = 'UPI';
    bool isLoading = false;

    final modes = ['Cash', 'UPI', 'Bank'];
    final cashBalance = _wallet != null ? (_wallet!['cashBalance'] ?? 0.0).toDouble() : 0.0;
    final upiBalance = _wallet != null ? (_wallet!['upiBalance'] ?? 0.0).toDouble() : 0.0;
    final bankBalance = _wallet != null ? (_wallet!['bankBalance'] ?? 0.0).toDouble() : 0.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Transfer Between Modes'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Available Balances',
                    style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildBalanceRow('Cash', cashBalance),
                  _buildBalanceRow('UPI', upiBalance),
                  _buildBalanceRow('Bank', bankBalance),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: fromMode,
                    decoration: const InputDecoration(
                      labelText: 'From Mode *',
                      prefixIcon: Icon(Icons.arrow_downward),
                    ),
                    items: modes.map((mode) {
                      return DropdownMenuItem<String>(
                        value: mode,
                        child: Text(mode),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          fromMode = value;
                          if (toMode == fromMode) {
                            toMode = modes.firstWhere((m) => m != fromMode);
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: toMode,
                    decoration: const InputDecoration(
                      labelText: 'To Mode *',
                      prefixIcon: Icon(Icons.arrow_upward),
                    ),
                    items: modes.where((m) => m != fromMode).map((mode) {
                      return DropdownMenuItem<String>(
                        value: mode,
                        child: Text(mode),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          toMode = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid amount';
                      }
                      double availableBalance = 0;
                      if (fromMode == 'Cash') availableBalance = cashBalance;
                      if (fromMode == 'UPI') availableBalance = upiBalance;
                      if (fromMode == 'Bank') availableBalance = bankBalance;
                      if (amount > availableBalance) {
                        return 'Insufficient balance. Available: ₹${availableBalance.toStringAsFixed(2)}';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      prefixIcon: Icon(Icons.note_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (formKey.currentState!.validate()) {
                  // Backend API call removed
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transfer feature is currently unavailable'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Transfer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceRow(String mode, double balance) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(mode, style: AppTheme.bodyMedium),
          Text(
            '₹${_formatAmount(balance)}',
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}