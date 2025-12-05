import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../models/smart_approval_item.dart';
import '../services/pending_approval_service.dart';

// Smart Approvals related enums and classes
enum ApprovalStatus { approve, unapprove, verified, accountant }

enum ApprovalActionType {
  approve,
  unapprove,
  reject,
  edit,
  flag,
  delete,
}

class ApprovalItem {
  ApprovalItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.vendor,
    required this.category,
    required this.status,
    this.flagged = false,
    this.notes,
  });

  final int id;
  final String title;
  final String amount;
  final DateTime date;
  final String vendor;
  final String category;
  ApprovalStatus status;
  bool flagged;
  String? notes;
}

class SmartApprovalsSection extends StatefulWidget {
  const SmartApprovalsSection({super.key});

  @override
  State<SmartApprovalsSection> createState() => _SmartApprovalsSectionState();
}

class _SmartApprovalsSectionState extends State<SmartApprovalsSection> {
  List<SmartApprovalItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadApprovalItems();
  }

  Future<void> _loadApprovalItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await PendingApprovalService.getPendingApprovals(
        status: 'Pending',
        limit: 50,
      );

      if (response['success'] == true && mounted) {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        final collections = data['collections'] as List<dynamic>? ?? [];
        final transactions = data['transactions'] as List<dynamic>? ?? [];
        final expenses = data['expenses'] as List<dynamic>? ?? [];

        final List<SmartApprovalItem> items = [];

        // Convert collections
        for (final collection in collections) {
          try {
            items.add(SmartApprovalItem.fromCollection(
              Map<String, dynamic>.from(collection as Map),
            ));
          } catch (e) {
            print('Error parsing collection: $e');
          }
        }

        // Convert transactions
        for (final transaction in transactions) {
          try {
            items.add(SmartApprovalItem.fromTransaction(
              Map<String, dynamic>.from(transaction as Map),
            ));
          } catch (e) {
            print('Error parsing transaction: $e');
          }
        }

        // Convert expenses
        for (final expense in expenses) {
          try {
            items.add(SmartApprovalItem.fromExpense(
              Map<String, dynamic>.from(expense as Map),
            ));
          } catch (e) {
            print('Error parsing expense: $e');
          }
        }

        // Sort by date (newest first)
        items.sort((a, b) => b.date.compareTo(a.date));

        if (mounted) {
          setState(() {
            _items = items;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = response['message'] ?? 'Failed to load approval items';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading approvals: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
        final cardWidth = _getCardWidth(constraints.maxWidth, crossAxisCount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.approval_outlined,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart Approvals',
                          style: AppTheme.headingSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage and review pending approval requests',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppTheme.errorColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.errorColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadApprovalItems,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No pending approvals',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: _items
                    .map(
                      (item) => SizedBox(
                        width: crossAxisCount == 1 ? double.infinity : cardWidth,
                        child: _SmartApprovalCard(
                          item: item,
                          onActionSelected: (action) => _handleAction(item, action),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        );
      },
    );
  }

  int _getCrossAxisCount(double maxWidth) {
    if (maxWidth >= 1280) return 3;
    if (maxWidth >= 860) return 2;
    return 1;
  }

  double _getCardWidth(double maxWidth, int count) {
    if (count <= 1) return maxWidth;
    final totalSpacing = (count - 1) * 20;
    return (maxWidth - totalSpacing) / count;
  }

  Future<void> _handleAction(SmartApprovalItem item, ApprovalActionType action) async {
    // TODO: Implement actual API calls for approve/reject/flag actions
    // For now, just show messages and refresh data
    switch (action) {
      case ApprovalActionType.approve:
        _showSnackBar('${item.type} approved. Refreshing...');
        await _loadApprovalItems();
        break;
      case ApprovalActionType.unapprove:
        _showSnackBar('${item.type} moved to unapproved. Refreshing...');
        await _loadApprovalItems();
        break;
      case ApprovalActionType.reject:
        final confirmed = await _confirmAction(
          title: 'Reject Item',
          message: 'Reject this ${item.type.toLowerCase()}?',
          confirmLabel: 'Reject',
        );
        if (confirmed) {
          _showSnackBar('${item.type} rejected. Refreshing...');
          await _loadApprovalItems();
        }
        break;
      case ApprovalActionType.edit:
        await _showEditNotesDialog(item);
        break;
      case ApprovalActionType.flag:
        final toggled = !item.flagged;
        final confirmed = await _confirmAction(
          title: toggled ? 'Flag Item' : 'Remove Flag',
          message: toggled
              ? 'Flag this ${item.type.toLowerCase()} for follow-up?'
              : 'Remove the follow-up flag from this ${item.type.toLowerCase()}?',
          confirmLabel: toggled ? 'Flag' : 'Remove',
        );
        if (confirmed) {
          _showSnackBar('${item.type} ${toggled ? 'flagged' : 'unflagged'}. Refreshing...');
          await _loadApprovalItems();
        }
        break;
      case ApprovalActionType.delete:
        final confirmed = await _confirmAction(
          title: 'Delete Item',
          message: 'Delete this ${item.type.toLowerCase()}? This action cannot be undone.',
          confirmLabel: 'Delete',
        );
        if (confirmed) {
          _showSnackBar('${item.type} deleted. Refreshing...');
          await _loadApprovalItems();
        }
        break;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showEditNotesDialog(SmartApprovalItem item) async {
    final controller = TextEditingController(text: item.notes ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Notes'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Add context or next steps for this item',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      // TODO: Save notes via API
      _showSnackBar('Notes updated for ${item.type}');
      await _loadApprovalItems();
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}

class _SmartApprovalCard extends StatelessWidget {
  const _SmartApprovalCard({
    required this.item,
    required this.onActionSelected,
  });

  final SmartApprovalItem item;
  final ValueChanged<ApprovalActionType> onActionSelected;

  ApprovalStatus _mapStatus(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return ApprovalStatus.approve;
      case 'pending':
      case 'unapproved':
        return ApprovalStatus.unapprove;
      case 'verified':
      case 'accounted':
        return ApprovalStatus.verified;
      default:
        return ApprovalStatus.unapprove;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _mapStatus(item.status);
    final statusTheme = status.theme;
    final borderColor = statusTheme.color.withOpacity(0.25);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.type,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: AppTheme.headingSmall.copyWith(fontSize: 20),
                      ),
                      if (item.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusBadge(statusTheme: statusTheme, flagged: item.flagged),
                    if (item.isSystematicEntry) ...[
                      const SizedBox(height: 8),
                      _SystematicEntryBadge(),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            _DetailRow(
              icon: Icons.currency_rupee,
              label: 'Amount',
              value: item.formattedAmount,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.event,
              label: 'Date',
              value: DateFormat('dd MMM yyyy').format(item.date),
            ),
            // Type-specific details
            if (item.type == 'Collections') ...[
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.person,
                label: 'Customer',
                value: item.details['customerName'] ?? 'N/A',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.receipt_long,
                label: 'Voucher',
                value: item.details['voucherNumber'] ?? 'N/A',
              ),
              if (item.isAutoPay) ...[
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.autorenew,
                  label: 'Auto Pay',
                  value: 'ON',
                ),
              ],
            ] else if (item.type == 'Transactions') ...[
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.person_outline,
                label: 'From',
                value: item.details['sender'] ?? 'N/A',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.person,
                label: 'To',
                value: item.details['receiver'] ?? 'N/A',
              ),
              if (item.isSystematicEntry) ...[
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.sync,
                  label: 'Type',
                  value: 'System Transaction',
                ),
              ],
            ] else if (item.type == 'Expenses') ...[
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.category,
                label: 'Type',
                value: item.details['expenseType'] ?? 'N/A',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.person,
                label: 'User',
                value: item.details['user'] ?? 'N/A',
              ),
            ],
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.note_alt_outlined,
                label: 'Notes',
                value: item.notes!,
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: status.allowedActions
                  .map(
                    (action) => _ActionButton(
                      action: action,
                      onTap: () => onActionSelected(action),
                      isFlagged: item.flagged,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystematicEntryBadge extends StatelessWidget {
  const _SystematicEntryBadge();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Auto Pay enabled - will be automatically processed on approval',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.12), // Green color
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.autorenew,
              color: const Color(0xFF10B981),
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              'Systematic Entry',
              style: AppTheme.bodySmall.copyWith(
                color: const Color(0xFF10B981),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.statusTheme, required this.flagged});

  final _StatusTheme statusTheme;
  final bool flagged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: statusTheme.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusTheme.icon, color: statusTheme.color, size: 16),
              const SizedBox(width: 6),
              Text(
                statusTheme.label,
                style: AppTheme.bodySmall.copyWith(
                  color: statusTheme.color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        if (flagged) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag, size: 14, color: AppTheme.warningColor),
                const SizedBox(width: 4),
                Text(
                  'Flagged',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTheme.bodyMedium.copyWith(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.onTap,
    required this.isFlagged,
  });

  final ApprovalActionType action;
  final VoidCallback onTap;
  final bool isFlagged;

  @override
  Widget build(BuildContext context) {
    final theme = action.theme(isFlagged: isFlagged);

    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(theme.icon, size: 18),
      label: Text(theme.label),
      style: ButtonStyle(
        foregroundColor: MaterialStateProperty.all(theme.color),
        backgroundColor: MaterialStateProperty.resolveWith(
          (states) {
            final hovered = states.contains(MaterialState.hovered) || states.contains(MaterialState.pressed);
            return hovered ? theme.color.withOpacity(0.18) : theme.color.withOpacity(0.1);
          },
        ),
        overlayColor: MaterialStateProperty.all(theme.color.withOpacity(0.15)),
        padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _StatusTheme {
  const _StatusTheme({
    required this.label,
    required this.color,
    required this.icon,
    required this.allowedActions,
  });

  final String label;
  final Color color;
  final IconData icon;
  final List<ApprovalActionType> allowedActions;
}

extension on ApprovalStatus {
  _StatusTheme get theme {
    switch (this) {
      case ApprovalStatus.approve:
        return _StatusTheme(
          label: 'Approve',
          color: AppTheme.secondaryColor,
          icon: Icons.check_circle,
          allowedActions: const [
            ApprovalActionType.unapprove,
            ApprovalActionType.edit,
            ApprovalActionType.flag,
            ApprovalActionType.delete,
          ],
        );
      case ApprovalStatus.unapprove:
        return _StatusTheme(
          label: 'Unapprove',
          color: AppTheme.warningColor,
          icon: Icons.undo,
          allowedActions: const [
            ApprovalActionType.approve,
            ApprovalActionType.reject,
            ApprovalActionType.edit,
            ApprovalActionType.flag,
            ApprovalActionType.delete,
          ],
        );
      case ApprovalStatus.verified:
        return _StatusTheme(
          label: 'Verified',
          color: AppTheme.accentBlue,
          icon: Icons.verified,
          allowedActions: const [
            ApprovalActionType.approve,
            ApprovalActionType.reject,
            ApprovalActionType.edit,
            ApprovalActionType.flag,
            ApprovalActionType.delete,
          ],
        );
      case ApprovalStatus.accountant:
        return _StatusTheme(
          label: 'Accountant',
          color: AppTheme.primaryColor,
          icon: Icons.account_balance,
          allowedActions: const [
            ApprovalActionType.approve,
            ApprovalActionType.reject,
            ApprovalActionType.edit,
            ApprovalActionType.flag,
          ],
        );
    }
  }

  List<ApprovalActionType> get allowedActions => theme.allowedActions;
}

class _ActionTheme {
  const _ActionTheme({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

extension on ApprovalActionType {
  _ActionTheme theme({required bool isFlagged}) {
    switch (this) {
      case ApprovalActionType.approve:
        return const _ActionTheme(
          label: 'Approve',
          color: AppTheme.secondaryColor,
          icon: Icons.check,
        );
      case ApprovalActionType.unapprove:
        return const _ActionTheme(
          label: 'Unapprove',
          color: AppTheme.warningColor,
          icon: Icons.undo,
        );
      case ApprovalActionType.reject:
        return const _ActionTheme(
          label: 'Reject',
          color: AppTheme.errorColor,
          icon: Icons.close,
        );
      case ApprovalActionType.edit:
        return const _ActionTheme(
          label: 'Edit',
          color: AppTheme.primaryColor,
          icon: Icons.edit,
        );
      case ApprovalActionType.flag:
        return _ActionTheme(
          label: isFlagged ? 'Unflag' : 'Flag',
          color: AppTheme.warningColor,
          icon: isFlagged ? Icons.outlined_flag : Icons.flag_outlined,
        );
      case ApprovalActionType.delete:
        return const _ActionTheme(
          label: 'Delete',
          color: AppTheme.errorColor,
          icon: Icons.delete,
        );
    }
  }
}

