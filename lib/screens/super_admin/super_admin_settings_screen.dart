

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/action_button_setting.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/screen_back_button.dart';

class SuperAdminSettingsScreen extends StatefulWidget {
  const SuperAdminSettingsScreen({
    super.key,
    this.onSettingsUpdated,
    this.wrapWithScaffold = false,
  });

  final VoidCallback? onSettingsUpdated;
  final bool wrapWithScaffold;

  @override
  State<SuperAdminSettingsScreen> createState() => _SuperAdminSettingsScreenState();
}

class _SuperAdminSettingsScreenState extends State<SuperAdminSettingsScreen> {
  static const Map<String, ActionButtonSetting> _kDefaultSettings = {
    'approve': ActionButtonSetting(key: 'approve', showButton: true, enablePopup: true),
    'reject': ActionButtonSetting(key: 'reject', showButton: true, enablePopup: true),
    'unapprove': ActionButtonSetting(key: 'unapprove', showButton: true, enablePopup: false),
    'delete': ActionButtonSetting(key: 'delete', showButton: true, enablePopup: true),
    'edit': ActionButtonSetting(key: 'edit', showButton: true, enablePopup: false),
    'flag': ActionButtonSetting(key: 'flag', showButton: true, enablePopup: true),
  };

  late Map<String, ActionButtonSetting> _buttonSettings;
  final Set<String> _expandedTiles = {'actionButtons'};
  bool _isLoading = false;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _buttonSettings = Map<String, ActionButtonSetting>.from(_kDefaultSettings);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final settings = await SettingsService.fetchActionButtonSettings();
      if (!mounted) return;
      setState(() {
        _buttonSettings = _mergeWithDefaults(settings);
      });
      widget.onSettingsUpdated?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = _errorMessage(error, 'Failed to load action button settings.');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final contentPadding = EdgeInsets.all(isMobile ? 16 : 24);

    Widget content;
    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_loadError != null) {
      content = Padding(
        padding: contentPadding,
        child: _buildLoadErrorCard(isMobile),
      );
    } else {
      content = SingleChildScrollView(
        padding: contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Super Admin Settings',
              style: AppTheme.headingMedium.copyWith(fontSize: isMobile ? 20 : 24),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure action buttons and other administrative options.',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            _buildExpandableSection(
              context,
              id: 'actionButtons',
              icon: Icons.tune,
              title: 'Action Button Controls',
              description: 'Configure visibility and confirmation settings for key workflow actions.',
              color: AppTheme.primaryColor,
              child: Column(
                children: [
                  _buildSummaryRow(isMobile),
                  const SizedBox(height: 24),
                  _buildFooterActions(context, isMobile),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (!widget.wrapWithScaffold) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        leading: const ScreenBackButton(fallbackRoute: '/super-admin-dashboard'),
        title: const Text('Super Admin Settings'),
      ),
      body: content,
    );
  }

  Widget _buildSummaryRow(bool isMobile) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _ButtonConfig.all.map((config) {
        final settings = _buttonSettings[config.key] ?? _kDefaultSettings[config.key]!;
        final visible = settings.showButton;
        final withPopup = settings.enablePopup;
        final statusText = visible
            ? (withPopup ? 'Visible · Popup' : 'Visible · Direct')
            : 'Hidden';
        final Color statusColor = visible
            ? (withPopup ? config.color : AppTheme.textPrimary)
            : AppTheme.textSecondary;

        return GestureDetector(
          onTap: () => _showConfigDialog(config),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: visible
                    ? config.color.withValues(alpha: 0.28)
                    : AppTheme.borderColor.withValues(alpha: 0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: isMobile ? double.infinity : 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: config.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(config.icon, color: config.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.label,
                          style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusText,
                          style: AppTheme.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoadErrorCard(bool isMobile) {
    final message = _loadError ?? 'Unable to load action button settings.';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 20 : 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.error_outline, color: AppTheme.errorColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unable to load settings',
                        style: AppTheme.headingSmall.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _loadSettings,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableSection(
    BuildContext context, {
    required String id,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required Widget child,
  }) {
    final isExpanded = _expandedTiles.contains(id);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.8)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            if (expanded) {
              _expandedTiles.add(id);
            } else {
              _expandedTiles.remove(id);
            }
          });
        },
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.headingSmall.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
        children: [child],
        ),
      ),
    );
  }

  Widget _buildFooterActions(BuildContext context, bool isMobile) {
    final isBusy = _isSaving;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: OutlinedButton.icon(
            onPressed: isBusy ? null : () => _resetToDefaults(context),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset Defaults'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 18 : 22,
                vertical: 16,
              ),
              textStyle: AppTheme.labelMedium,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: ElevatedButton.icon(
            onPressed: isBusy ? null : () => _saveSettings(context),
            icon: const Icon(Icons.save_outlined),
            label: Text(isBusy ? 'Saving...' : 'Save All'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : 26,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handlePreviewTap(BuildContext context, _ButtonConfig config, bool enablePopup) async {
    if (enablePopup) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              void submit() => Navigator.of(dialogContext).pop(true);

              return Shortcuts(
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                  SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (intent) {
                        submit();
                        return null;
                      },
                    ),
                  },
                  child: FocusTraversalGroup(
                    child: FocusScope(
                      autofocus: true,
                      child: AlertDialog(
                        title: Text('${config.label} Confirmation'),
                        content: Text('Are you sure you want to ${config.actionDescription}?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: config.color,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Confirm'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ) ??
          false;

      if (!mounted || !confirmed) return;

      _showSnackBar('${config.label} confirmed via popup', backgroundColor: config.color);
    } else {
      _showSnackBar('${config.label} triggered without popup', backgroundColor: config.color);
    }
  }

  Future<void> _resetToDefaults(BuildContext context) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final resetSettings = await SettingsService.resetActionButtonSettings();
      if (!mounted) return;
      setState(() {
        _buttonSettings = _mergeWithDefaults(resetSettings);
      });
      _showSnackBar('Settings reset to defaults');
      widget.onSettingsUpdated?.call();
    } catch (error) {
      final message = _errorMessage(error, 'Failed to reset settings.');
      _showSnackBar(message, isError: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _saveSettings(BuildContext context) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final payload = _ButtonConfig.all
          .map((config) => _buttonSettings[config.key] ?? _kDefaultSettings[config.key]!)
          .toList();
      final updatedSettings = await SettingsService.updateActionButtonSettings(
        payload,
      );
      if (!mounted) return;
      setState(() {
        _buttonSettings = _mergeWithDefaults(updatedSettings);
      });
      _showSnackBar('Action button settings saved successfully');
      widget.onSettingsUpdated?.call();
    } catch (error) {
      final message = _errorMessage(error, 'Failed to save settings.');
      _showSnackBar(message, isError: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  Map<String, ActionButtonSetting> _mergeWithDefaults(Iterable<ActionButtonSetting> settings) {
    final merged = Map<String, ActionButtonSetting>.from(_kDefaultSettings);
    for (final setting in settings) {
      if (_kDefaultSettings.containsKey(setting.key)) {
        merged[setting.key] = setting;
      }
    }
    return merged;
  }

  String _errorMessage(Object error, String fallback) {
    final raw = error.toString();
    if (raw.isEmpty) {
      return fallback;
    }
    final cleaned = raw.replaceFirst(RegExp(r'^(Exception|FormatException):\s*'), '').trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }

  void _showSnackBar(String message, {bool isError = false, Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? (isError ? AppTheme.errorColor : null),
      ),
    );
  }

  Future<void> _showConfigDialog(_ButtonConfig config) async {
    final current = _buttonSettings[config.key] ?? _kDefaultSettings[config.key]!;
    bool showButton = current.showButton;
    bool enablePopup = current.enablePopup;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            title: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: config.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(config.icon, color: config.color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(config.label, style: AppTheme.headingSmall.copyWith(fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(
                        config.caption,
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show Button'),
                  subtitle: Text('Choose whether ${config.label.toLowerCase()} is visible to users.'),
                  value: showButton,
                  onChanged: (value) {
                    setDialogState(() {
                      showButton = value;
                      if (!showButton) {
                        enablePopup = false;
                      }
                    });
                  },
                  activeColor: config.color,
                ),
                AnimatedOpacity(
                  opacity: showButton ? 1 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Popup Confirmation'),
                    subtitle: Text('Require confirmation before ${config.label.toLowerCase()} is executed.'),
                    value: enablePopup,
                    onChanged: showButton
                        ? (value) {
                            setDialogState(() {
                              enablePopup = value;
                            });
                          }
                        : null,
                    activeColor: config.color,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Preview', style: AppTheme.labelMedium.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      if (showButton)
                        FilledButton.icon(
                          onPressed: () => _handlePreviewTap(context, config, enablePopup),
                          style: FilledButton.styleFrom(
                            backgroundColor: config.color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: Icon(config.icon, size: 18),
                          label: Text(config.label),
                        )
                      else
                        Text(
                          'Button hidden. Enable "Show Button" to allow this action.',
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        showButton
                            ? (enablePopup ? 'Shows with popup' : 'Shows without popup')
                            : 'Hidden from all users',
                        style: AppTheme.bodySmall.copyWith(
                          color: showButton
                              ? (enablePopup ? config.color : AppTheme.textPrimary)
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    final currentSetting = _buttonSettings[config.key] ?? _kDefaultSettings[config.key]!;
                    _buttonSettings[config.key] = currentSetting.copyWith(
                      showButton: showButton,
                      enablePopup: enablePopup,
                    );
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

}

class _ButtonConfig {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final String caption;
  final String actionDescription;

  const _ButtonConfig({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.caption,
    required this.actionDescription,
  });

  static const List<_ButtonConfig> all = [
    _ButtonConfig(
      key: 'approve',
      label: 'Approve',
      icon: Icons.check_circle,
      color: AppTheme.secondaryColor,
      caption: 'Green action button for approving items',
      actionDescription: 'approve this item',
    ),
    _ButtonConfig(
      key: 'reject',
      label: 'Reject',
      icon: Icons.cancel,
      color: AppTheme.errorColor,
      caption: 'Red action button for rejecting items',
      actionDescription: 'reject this item',
    ),
    _ButtonConfig(
      key: 'unapprove',
      label: 'Unapprove',
      icon: Icons.undo,
      color: AppTheme.warningColor,
      caption: 'Orange action button for reversing approvals',
      actionDescription: 'mark this item as unapproved',
    ),
    _ButtonConfig(
      key: 'delete',
      label: 'Delete',
      icon: Icons.delete_outline,
      color: AppTheme.errorColor,
      caption: 'Red action button for deleting entries',
      actionDescription: 'delete this item',
    ),
    _ButtonConfig(
      key: 'edit',
      label: 'Edit',
      icon: Icons.edit_outlined,
      color: AppTheme.accentBlue,
      caption: 'Blue action button for editing entries',
      actionDescription: 'edit this item',
    ),
    _ButtonConfig(
      key: 'flag',
      label: 'Flag',
      icon: Icons.flag_outlined,
      color: AppTheme.warningColor,
      caption: 'Orange action button for flagging entries',
      actionDescription: 'flag this item for review',
    ),
  ];
}


