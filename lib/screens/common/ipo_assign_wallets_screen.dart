import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

class IpoAssignWalletsScreen extends StatefulWidget {
  final bool embedInDashboard;
  
  const IpoAssignWalletsScreen({
    super.key,
    this.embedInDashboard = false,
  });

  @override
  State<IpoAssignWalletsScreen> createState() => _IpoAssignWalletsScreenState();
}

class _IpoAssignWalletsScreenState extends State<IpoAssignWalletsScreen> {
  @override
  Widget build(BuildContext context) {
    final content = const Center(
      child: Text('Content coming soon...'),
    );

    // When embedded in dashboard, don't show AppBar (dashboard handles it)
    if (widget.embedInDashboard) {
      return content;
    }

    // When standalone, show full Scaffold with AppBar
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go('/users');
            }
          },
          tooltip: 'Back',
        ),
        title: const Text('Assign Wallets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // TODO: Implement refresh functionality
            },
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
      ),
      body: content,
    );
  }
}

