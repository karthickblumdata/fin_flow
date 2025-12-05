import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../services/audit_log_service.dart';

class RecentActivityScreen extends StatefulWidget {
  final bool showAppBar;
  final VoidCallback? onClose;
  const RecentActivityScreen({super.key, this.showAppBar = true, this.onClose});

  @override
  State<RecentActivityScreen> createState() => _RecentActivityScreenState();
}

class _RecentActivityScreenState extends State<RecentActivityScreen> {
  List<dynamic> _activities = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'User', 'Wallet', 'Transaction', 'Collection', 'Expense'];

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuditLogService.getRecentActivity(limit: 100);
      if (result['success'] == true && mounted) {
        setState(() {
          _activities = result['activities'] ?? [];
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

  List<dynamic> get _filteredActivities {
    if (_selectedFilter == 'All') {
      return _activities;
    }
    return _activities.where((activity) => activity['type'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final body = _buildActivityBody(isMobile: isMobile);

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Recent Activity'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadActivities,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: body,
      );
    }

    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDialogHeader(),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildDialogHeader() {
    final navigator = Navigator.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Smart View',
                  style: AppTheme.headingSmall.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recent Activity and approvals overview',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () {
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                navigator.maybePop();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadActivities,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityBody({required bool isMobile}) {
    return Container(
      color: widget.showAppBar ? AppTheme.backgroundColor : AppTheme.surfaceColor,
      child: Column(
        children: [
          _buildFilterSection(isMobile: isMobile),
          Expanded(child: _buildActivityList(isMobile: isMobile)),
        ],
      ),
    );
  }

  Widget _buildFilterSection({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: widget.showAppBar ? AppTheme.backgroundColor : Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            'Filter:',
            style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
              ),
              child: DropdownButton<String>(
                value: _selectedFilter,
                underline: const SizedBox(),
                isExpanded: true,
                isDense: true,
                items: _filters.map((filter) {
                  return DropdownMenuItem<String>(
                    value: filter,
                    child: Text(filter),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedFilter = value;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList({required bool isMobile}) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredActivities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No activities found',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      itemCount: _filteredActivities.length,
      itemBuilder: (context, index) {
        final activity = _filteredActivities[index];
        return _buildActivityCard(activity);
      },
    );
  }

  Widget _buildActivityCard(dynamic activity) {
    final user = activity['user'];
    final userName = user?['name'] ?? 'Unknown';
    final userRole = user?['role'] ?? 'Unknown';
    final action = activity['action'] ?? 'Unknown';
    final type = activity['type'] ?? 'Unknown';
    final timestamp = activity['timestamp'] != null
        ? DateTime.parse(activity['timestamp']).toLocal()
        : DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(type).withValues(alpha: 0.1),
          child: Icon(
            _getTypeIcon(type),
            color: _getTypeColor(type),
            size: 20,
          ),
        ),
        title: Text(
          action,
          style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '$userName ($userRole)',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatDate(timestamp)} • ${_formatTime(timestamp)}',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getTypeColor(type).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            type,
            style: AppTheme.bodySmall.copyWith(
              color: _getTypeColor(type),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'User':
        return Icons.person;
      case 'Wallet':
        return Icons.account_balance_wallet;
      case 'Transaction':
        return Icons.swap_horiz;
      case 'Collection':
        return Icons.payment;
      case 'Expense':
        return Icons.receipt;
      default:
        return Icons.info;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'User':
        return AppTheme.primaryColor;
      case 'Wallet':
        return AppTheme.secondaryColor;
      case 'Transaction':
        return AppTheme.warningColor;
      case 'Collection':
        return AppTheme.secondaryColor;
      case 'Expense':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}-${_getMonthAbbr(date.month)}-${date.year.toString().substring(2)}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

