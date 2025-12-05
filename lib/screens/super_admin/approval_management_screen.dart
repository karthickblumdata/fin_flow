import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../widgets/screen_back_button.dart';

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

class ApprovalManagementScreen extends StatefulWidget {
  const ApprovalManagementScreen({super.key});

  @override
  State<ApprovalManagementScreen> createState() => _ApprovalManagementScreenState();
}

class _ApprovalManagementScreenState extends State<ApprovalManagementScreen> {
  final List<ApprovalItem> _items = [
    ApprovalItem(
      id: 4125,
      title: 'Marketing Campaign Spend',
      amount: '₹245,500',
      date: DateTime(2025, 11, 2),
      vendor: 'Spark Media Pvt. Ltd.',
      category: 'Marketing',
      status: ApprovalStatus.approve,
      notes: 'Awaiting invoice upload confirmation.',
    ),
    ApprovalItem(
      id: 4126,
      title: 'Fleet Maintenance',
      amount: '₹119,200',
      date: DateTime(2025, 11, 1),
      vendor: 'North Star Motors',
      category: 'Operations',
      status: ApprovalStatus.unapprove,
      flagged: true,
      notes: 'Missing repair logs for two vehicles.',
    ),
    ApprovalItem(
      id: 4127,
      title: 'Branch Audit Reconciliation',
      amount: '₹68,340',
      date: DateTime(2025, 10, 29),
      vendor: 'Bright Ledger LLP',
      category: 'Compliance',
      status: ApprovalStatus.verified,
    ),
    ApprovalItem(
      id: 4128,
      title: 'Vendor Payment Batch',
      amount: '₹512,780',
      date: DateTime(2025, 10, 30),
      vendor: 'Multiple Vendors',
      category: 'Finance',
      status: ApprovalStatus.accountant,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBackButton(fallbackRoute: '/super-admin-dashboard'),
        title: const Text('Approval Management'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
          final cardWidth = _getCardWidth(constraints.maxWidth, crossAxisCount);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Wrap(
              spacing: 20,
              runSpacing: 20,
              children: _items
                  .map(
                    (item) => SizedBox(
                      width: crossAxisCount == 1 ? double.infinity : cardWidth,
                      child: _ApprovalCard(
                        item: item,
                        onActionSelected: (action) => _handleAction(item, action),
                      ),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
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
    return (maxWidth - totalSpacing - 48) / count;
  }

  Future<void> _handleAction(ApprovalItem item, ApprovalActionType action) async {
    switch (action) {
      case ApprovalActionType.approve:
        _updateStatus(item, ApprovalStatus.approve, message: 'Item #${item.id} approved.');
        break;
      case ApprovalActionType.unapprove:
        _updateStatus(item, ApprovalStatus.unapprove, message: 'Item #${item.id} moved to Unapprove.');
        break;
      case ApprovalActionType.reject:
        final confirmed = await _confirmAction(
          title: 'Reject Item',
          message: 'Reject this item? This will move it back to Unapprove status.',
          confirmLabel: 'Reject',
        );
        if (confirmed) {
          _updateStatus(item, ApprovalStatus.unapprove, message: 'Item #${item.id} rejected.');
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
              ? 'Flag this item for follow-up?'
              : 'Remove the follow-up flag from this item?',
          confirmLabel: toggled ? 'Flag' : 'Remove',
        );
        if (confirmed) {
          setState(() {
            item.flagged = toggled;
          });
          _showSnackBar('Item #${item.id} ${toggled ? 'flagged' : 'unflagged'}');
        }
        break;
      case ApprovalActionType.delete:
        final confirmed = await _confirmAction(
          title: 'Delete Item',
          message: 'Delete this item? This action cannot be undone.',
          confirmLabel: 'Delete',
        );
        if (confirmed) {
          setState(() {
            _items.removeWhere((entry) => entry.id == item.id);
          });
          _showSnackBar('Item #${item.id} deleted');
        }
        break;
    }
  }

  void _updateStatus(ApprovalItem item, ApprovalStatus status, {required String message}) {
    setState(() {
      item.status = status;
      if (status == ApprovalStatus.approve) {
        item.flagged = false;
      }
    });
    _showSnackBar(message);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showEditNotesDialog(ApprovalItem item) async {
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
      setState(() {
        item.notes = controller.text.trim().isEmpty ? null : controller.text.trim();
      });
      _showSnackBar('Notes updated for item #${item.id}');
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

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.item,
    required this.onActionSelected,
  });

  final ApprovalItem item;
  final ValueChanged<ApprovalActionType> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final statusTheme = item.status.theme;
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
                        'Item #${item.id}',
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
                    ],
                  ),
                ),
                _StatusBadge(statusTheme: statusTheme, flagged: item.flagged),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            _DetailRow(
              icon: Icons.currency_rupee,
              label: 'Amount',
              value: item.amount,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.event,
              label: 'Date',
              value: DateFormat('dd MMM yyyy').format(item.date),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.storefront,
              label: 'Vendor',
              value: item.vendor,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.category,
              label: 'Category',
              value: item.category,
            ),
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
              children: item.status.allowedActions
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

