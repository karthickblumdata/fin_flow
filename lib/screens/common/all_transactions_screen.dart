import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../services/transaction_service.dart';
import '../../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'transfer_screen.dart';

class AllTransactionsScreen extends StatefulWidget {
  final bool embedInDashboard;
  const AllTransactionsScreen({super.key, this.embedInDashboard = false});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  bool _isLoading = true;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await TransactionService.getTransactions();

      if (mounted) {
        setState(() {
          _transactions = result['success'] == true ? (result['transactions'] ?? []) : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      DateTime dateTime;
      if (date is DateTime) {
        dateTime = date;
      } else if (date is String) {
        dateTime = DateTime.parse(date);
      } else {
        return '';
      }
      return DateFormat('dd-MMM-yyyy').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  String _formatTime(dynamic date) {
    if (date == null) return '';
    try {
      DateTime dateTime;
      if (date is DateTime) {
        dateTime = date;
      } else if (date is String) {
        dateTime = DateTime.parse(date);
      } else {
        return '';
      }
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildTransactionsTable(isMobile);

    if (widget.embedInDashboard) {
      return content; // No AppBar when embedded - dashboard handles it
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/super-admin-dashboard');
            }
          },
          tooltip: 'Back',
        ),
        title: const Text('All Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await AuthService.logout();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: content,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TransferScreen(),
            ),
          );
          if (result == true && mounted) {
            _loadTransactions();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildTransactionsTable(bool isMobile) {
    if (_transactions.isEmpty) {
      return Padding(
        padding: widget.embedInDashboard 
            ? const EdgeInsets.symmetric(vertical: 8, horizontal: 8)
            : const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_horiz_outlined,
              size: widget.embedInDashboard ? 32 : 48,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            SizedBox(height: widget.embedInDashboard ? 4 : 8),
            Text(
              'No transactions found',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontSize: widget.embedInDashboard ? 12 : 14,
              ),
            ),
            SizedBox(height: widget.embedInDashboard ? 4 : 8),
            Text(
              'Tap the + button to create a new transaction',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontSize: widget.embedInDashboard ? 11 : 12,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: widget.embedInDashboard 
          ? EdgeInsets.all(isMobile ? 8 : 12)
          : EdgeInsets.all(isMobile ? 16 : 24),
      child: Card(
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
              if (!isMobile)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text('Date', style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text('Sender', style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text('Receiver', style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text('Amount', style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600))),
                      Expanded(flex: 1, child: Text('Mode', style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text('Purpose', style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text('Created By', style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text('Timestamp', style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600))),
                      SizedBox(width: 100, child: Text('Status', style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              if (!isMobile) const Divider(height: 24),
              ..._transactions.map((tx) {
                final date = _formatDate(tx['createdAt']);
                final sender = tx['sender'] != null ? tx['sender']['name'] ?? 'Unknown' : 'Unknown';
                final receiver = tx['receiver'] != null ? tx['receiver']['name'] ?? 'Unknown' : 'Unknown';
                final amount = '₹${tx['amount']?.toStringAsFixed(0) ?? '0'}';
                final mode = tx['mode'] ?? '';
                final createdBy = tx['initiatedBy'] != null ? tx['initiatedBy']['name'] ?? 'Unknown' : 'Unknown';
                final purpose = tx['purpose'] ?? 'N/A';
                final timestamp = _formatTime(tx['createdAt']);
                final status = tx['status'] ?? 'Pending';

                return isMobile
                    ? _buildTransactionCard(date, sender, receiver, amount, mode, createdBy, timestamp, status, purpose)
                    : _buildTransactionRow(date, sender, receiver, amount, mode, purpose, createdBy, timestamp, status);
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionRow(
    String date,
    String sender,
    String receiver,
    String amount,
    String mode,
    String purpose,
    String createdBy,
    String timestamp,
    String status,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(date, style: AppTheme.bodyMedium)),
          Expanded(flex: 2, child: Text(sender, style: AppTheme.bodyMedium)),
          Expanded(flex: 2, child: Text(receiver, style: AppTheme.bodyMedium)),
          Expanded(
            flex: 2,
            child: Text(
              amount,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          Expanded(flex: 1, child: Text(mode, style: AppTheme.bodyMedium)),
          Expanded(
            flex: 2,
            child: Tooltip(
              message: purpose,
              child: Text(
                purpose,
                style: AppTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(flex: 2, child: Text(createdBy, style: AppTheme.bodyMedium)),
          Expanded(flex: 2, child: Text(timestamp, style: AppTheme.bodySmall)),
          SizedBox(width: 100, child: _buildStatusChip(status)),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    String date,
    String sender,
    String receiver,
    String amount,
    String mode,
    String createdBy,
    String timestamp,
    String status,
    String purpose,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
                Text(
                  date,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'From: $sender',
                    style: AppTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'To: $receiver',
                    style: AppTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (purpose != 'N/A') ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.description_outlined, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Purpose: $purpose',
                      style: AppTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  amount,
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        mode,
                        style: AppTheme.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timestamp,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Created by: $createdBy',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    if (status == 'Completed' || status == 'Approved') {
      chipColor = AppTheme.secondaryColor;
    } else if (status == 'Pending') {
      chipColor = AppTheme.warningColor;
    } else {
      chipColor = AppTheme.errorColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: AppTheme.bodySmall.copyWith(
          color: chipColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
