import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class UserActionBottomSheet extends StatelessWidget {
  final String userName;
  final String userId;
  final String userEmail;
  final VoidCallback? onAddAmount;
  final VoidCallback? onAddCollection;
  final VoidCallback? onAddExpense;
  final VoidCallback? onAddTransaction;

  const UserActionBottomSheet({
    super.key,
    required this.userName,
    required this.userId,
    required this.userEmail,
    this.onAddAmount,
    this.onAddCollection,
    this.onAddExpense,
    this.onAddTransaction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header with user info
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(userName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              userName,
                              style: AppTheme.headingSmall.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              // Navigate to All Wallet Reports with selected user
                              final uri = Uri(
                                path: '/wallet/overview',
                                queryParameters: {
                                  'userId': userId,
                                  'userLabel': userName,
                                },
                              );
                              context.push(uri.toString());
                            },
                            icon: const Icon(Icons.description_outlined, size: 16),
                            label: const Text('REPORT'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userEmail,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildActionButton(
                  context: context,
                  icon: Icons.add_circle_outline,
                  title: 'Add Amount',
                  subtitle: 'Add money to ${userName}\'s wallet',
                  color: AppTheme.secondaryColor,
                  onTap: () async {
                    // Close bottom sheet first
                    Navigator.of(context).pop();
                    // Wait a bit for bottom sheet to close completely
                    await Future.delayed(const Duration(milliseconds: 300));
                    // Then call the callback
                    onAddAmount?.call();
                  },
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  context: context,
                  icon: Icons.payment,
                  title: 'Add Collection',
                  subtitle: 'Create collection for ${userName}',
                  color: const Color(0xFF1F9D4D),
                  onTap: () async {
                    // Close bottom sheet first
                    Navigator.of(context).pop();
                    // Wait a bit for bottom sheet to close completely
                    await Future.delayed(const Duration(milliseconds: 300));
                    // Then call the callback
                    onAddCollection?.call();
                  },
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  context: context,
                  icon: Icons.receipt_long,
                  title: 'Add Expense',
                  subtitle: 'Record expense for ${userName}',
                  color: AppTheme.warningColor,
                  onTap: () async {
                    // Close bottom sheet first
                    Navigator.of(context).pop();
                    // Wait a bit for bottom sheet to close completely
                    await Future.delayed(const Duration(milliseconds: 300));
                    // Then call the callback
                    onAddExpense?.call();
                  },
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  context: context,
                  icon: Icons.swap_horiz,
                  title: 'Add Transaction',
                  subtitle: 'Transfer money to ${userName}',
                  color: AppTheme.primaryColor,
                  onTap: () async {
                    // Close bottom sheet first
                    Navigator.of(context).pop();
                    // Wait a bit for bottom sheet to close completely
                    await Future.delayed(const Duration(milliseconds: 300));
                    // Then call the callback
                    onAddTransaction?.call();
                  },
                ),
              ],
            ),
          ),
          
          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '--';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final word = parts.first;
      if (word.length >= 2) {
        return word.substring(0, 2).toUpperCase();
      }
      return word.substring(0, 1).toUpperCase();
    }
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}

