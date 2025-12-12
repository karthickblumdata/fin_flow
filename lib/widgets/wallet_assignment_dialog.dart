import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../services/wallet_service.dart';
import '../services/user_service.dart';

class WalletAssignmentDialog extends StatefulWidget {
  final String walletId;
  final String userId;
  final String userName;

  const WalletAssignmentDialog({
    super.key,
    required this.walletId,
    required this.userId,
    required this.userName,
  });

  @override
  State<WalletAssignmentDialog> createState() => _WalletAssignmentDialogState();
}

class _WalletAssignmentDialogState extends State<WalletAssignmentDialog> {
  bool _isLoading = true;
  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _remainingUsers = [];
  String? _assignedByName;
  String? _assignedByEmail;

  @override
  void initState() {
    super.initState();
    _loadAssignmentInfo();
  }

  Future<void> _loadAssignmentInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await WalletService.getWalletAssignments(widget.walletId);

      if (result['success'] == true) {
        final wallet = result['wallet'] as Map<String, dynamic>?;
        final remainingUsers = result['remainingUsers'] as List<dynamic>? ?? [];

        setState(() {
          _wallet = wallet;
          _remainingUsers = remainingUsers
              .map((u) => Map<String, dynamic>.from(u as Map))
              .toList();

          // Extract assignedBy info
          final assignedBy = wallet?['assignedBy'] as Map<String, dynamic>?;
          if (assignedBy != null) {
            _assignedByName = assignedBy['name']?.toString();
            _assignedByEmail = assignedBy['email']?.toString();
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to load assignment info'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
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
    final isTablet = Responsive.isTablet(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : (isTablet ? 600 : 700),
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.assignment_ind,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wallet Assignment',
                            style: AppTheme.headingMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 18 : 20,
                            ),
                          ),
                          if (widget.userName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.userName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      tooltip: 'Close',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(isMobile ? 16 : 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Assigned To Section
                            _buildSection(
                              title: 'Assigned To',
                              icon: Icons.person_outline,
                              color: AppTheme.primaryColor,
                              child: _assignedByName != null
                                  ? _buildUserCard(
                                      name: _assignedByName!,
                                      email: _assignedByEmail ?? '',
                                      isAssignedTo: true,
                                    )
                                  : _buildEmptyState('No assignment found'),
                            ),

                            const SizedBox(height: 24),

                            // Assigned For Section
                            _buildSection(
                              title: 'Assigned For',
                              icon: Icons.people_outline,
                              color: AppTheme.secondaryColor,
                              child: _remainingUsers.isEmpty
                                  ? _buildEmptyState('No users available')
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: _remainingUsers
                                          .map((user) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 8),
                                                child: _buildUserCard(
                                                  name: user['name']?.toString() ??
                                                      'Unknown',
                                                  email: user['email']
                                                          ?.toString() ??
                                                      '',
                                                  isAssignedTo: false,
                                                ),
                                              ))
                                          .toList(),
                                    ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTheme.headingMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildUserCard({
    required String name,
    required String email,
    required bool isAssignedTo,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAssignedTo
            ? AppTheme.primaryColor.withOpacity(0.1)
            : AppTheme.secondaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAssignedTo
              ? AppTheme.primaryColor.withOpacity(0.3)
              : AppTheme.secondaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isAssignedTo
                  ? AppTheme.primaryColor
                  : AppTheme.secondaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isAssignedTo)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Assigned',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.borderColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor.withOpacity(0.3),
        ),
      ),
      child: Center(
        child: Text(
          message,
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

