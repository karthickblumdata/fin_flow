import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/screen_back_button.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  String _type = 'Bank';
  final _labelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_type == 'UPI' ? 'UPI ID' : 'Bank Account'} added successfully'),
        backgroundColor: AppTheme.secondaryColor,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBackButton(fallbackRoute: '/super-admin-dashboard'),
        title: const Text('Add Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          PopupMenuButton<String>(
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : Responsive.isTablet(context) ? 600 : 720,
            ),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.borderColor),
              ),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account Type', style: AppTheme.labelMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Bank'),
                            selected: _type == 'Bank',
                            onSelected: (v) => setState(() => _type = 'Bank'),
                          ),
                          ChoiceChip(
                            label: const Text('UPI'),
                            selected: _type == 'UPI',
                            onSelected: (v) => setState(() => _type = 'UPI'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _labelController,
                        decoration: InputDecoration(
                          labelText: _type == 'UPI' ? 'UPI ID' : 'Account Label / Number',
                          hintText: _type == 'UPI' ? 'yourname@bank' : 'HDFC •••• 1234',
                          prefixIcon: Icon(_type == 'UPI' ? Icons.qr_code : Icons.account_balance),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                )
                              : const Text('Save Account'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


