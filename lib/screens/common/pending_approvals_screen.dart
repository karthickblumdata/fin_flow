import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:characters/characters.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../utils/api_constants.dart';
import '../../services/collection_service.dart';
import '../../services/transaction_service.dart';
import '../../services/expense_service.dart';
import '../../services/auth_service.dart';
import '../../services/pending_approval_service.dart';
import '../../services/payment_mode_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/action_pill_button.dart';
import '../../utils/profile_image_helper.dart';
import '../../utils/ui_permission_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _HeaderAction { approve, unapprove, reject, flag, edit, delete }
enum _PendingExportFormat { csv, excel, pdf }

class _ApproveIntent extends Intent {
  const _ApproveIntent();
}

class _RejectIntent extends Intent {
  const _RejectIntent();
}

class _FlagIntent extends Intent {
  const _FlagIntent();
}

class _EditIntent extends Intent {
  const _EditIntent();
}

class _DeleteIntent extends Intent {
  const _DeleteIntent();
}

class _PreviousIntent extends Intent {
  const _PreviousIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

class PendingApprovalsScreen extends StatefulWidget {
  final bool embedInDashboard;
  const PendingApprovalsScreen({super.key, this.embedInDashboard = false});

  @override
  State<PendingApprovalsScreen> createState() => PendingApprovalsScreenState();
}

class PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  final GlobalKey<_PendingApprovalsScreenContentState> _contentKey = GlobalKey<_PendingApprovalsScreenContentState>();

  void refresh() {
    _contentKey.currentState?._loadPendingItems();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return _PendingApprovalsScreenContent(
      key: _contentKey,
      embedInDashboard: widget.embedInDashboard,
    );
  }
}

class _PendingApprovalsScreenContent extends StatefulWidget {
  final bool embedInDashboard;
  const _PendingApprovalsScreenContent({super.key, this.embedInDashboard = false});

  @override
  State<_PendingApprovalsScreenContent> createState() => _PendingApprovalsScreenContentState();
}

class _PendingApprovalsScreenContentState extends State<_PendingApprovalsScreenContent> {
  static const String _allFilterValue = 'All';
  static const String _defaultStatusShortcut = 'Pending';
  static const List<String> _defaultModeSuggestions = <String>[
    'HDFC',
    'KVB',
    'ICICI',
    'Axis',
    'SBI',
    'UPI',
    'Cash',
    'Bank Transfer',
    'Cheque',
  ];

  // Default status options for dropdown
  static const List<String> _defaultStatusOptions = <String>[
    'Pending',
    'Approved',
    'Unapproved',
    'Unaccounted',
    'Verified',
    'Accountant',
    'Flagged',
    'Rejected',
    'Completed',
  ];
  
  // Default mode options for dropdown
  static const List<String> _defaultModeOptions = <String>[
    'Cash',
    'UPI',
    'Bank',
    'Bank Transfer',
    'HDFC',
    'KVB',
    'ICICI',
    'Axis',
    'SBI',
    'Cheque',
  ];

  String _selectedType = _allFilterValue;
  String _selectedStatus = _defaultStatusShortcut; // Default to 'Pending' for Smart Approvals
  String _selectedMode = _allFilterValue;

  List<String> _availableTypes = const [];
  List<String> _availableStatuses = const [];
  List<String> _availableModes = const [];
  final Set<String> _autoPayModes = <String>{};
  
  // Payment modes from backend
  List<Map<String, dynamic>> _paymentModes = [];
  bool _isLoadingPaymentModes = false;
  final ValueNotifier<bool> _paymentModesLoadedNotifier = ValueNotifier<bool>(false);

  final Set<String> _activeStatusShortcuts = <String>{_defaultStatusShortcut};

  List<Map<String, dynamic>> _pendingItems = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _currentUserId;
  String? _currentUserRole;
  bool _hasSmartApprovalsPermission = false;
  
  // Auto-refresh configuration
  Timer? _autoRefreshTimer;
  static const Duration _autoRefreshInterval = Duration(seconds: 30); // Refresh every 30 seconds
  static const Duration _debounceRefreshDelay = Duration(seconds: 2); // Debounce to prevent rapid refreshes
  DateTime? _lastRefreshTime;
  
  // Cached permission checks for Smart Approvals actions
  Map<String, bool> _actionPermissions = {
    'transaction.approve': false,
    'transaction.reject': false,
    'transaction.flag': false,
    'transaction.edit': false,
    'transaction.delete': false,
    'collection.approve': false,
    'collection.reject': false,
    'collection.flag': false,
    'collection.edit': false,
    'collection.delete': false,
    'expense.approve': false,
    'expense.reject': false,
    'expense.flag': false,
    'expense.edit': false,
    'expense.delete': false,
  };

  String? _selectedItemId;
  bool _showDetailPanel = false;
  int? _selectedIndex;
  String? _activeActionItemId;
  String? _activeActionKey;
  final Set<String> _bulkSelectedIds = <String>{};
  bool _isBulkActionInProgress = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadPaymentModes();
    _loadPendingItems();
    
    // Initialize socket for real-time updates
    _initializeSocketListeners();
    
    // Start auto-refresh timer
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _cleanupSocketListeners();
    _paymentModesLoadedNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Auto-refresh method with debouncing to prevent excessive API calls
  /// This method ensures pending approvals data is refreshed when changes occur
  void _autoRefreshPendingItems() {
    if (!mounted) return;
    
    // Debounce: Don't refresh if we just refreshed recently
    if (_lastRefreshTime != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
      if (timeSinceLastRefresh < _debounceRefreshDelay) {
        // Too soon since last refresh, skip this one
        return;
      }
    }
    
    // Don't refresh if already loading
    if (_isLoading) {
      return;
    }
    
    // Update last refresh time
    _lastRefreshTime = DateTime.now();
    
    // Refresh pending items data silently
    _loadPendingItems();
  }

  /// Start the auto-refresh timer
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _autoRefreshPendingItems();
    });
  }

  /// Stop the auto-refresh timer
  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  /// Initialize socket listeners for real-time pending approvals updates
  void _initializeSocketListeners() {
    try {
      // Initialize socket service
      SocketService.initialize().then((_) {
        if (!mounted) return;
        
        final socket = SocketService.socket;
        if (socket != null) {
          // Listen to expense updates (approve/reject/flag actions)
          socket.on('expenseUpdate', (data) {
            if (mounted) {
              _autoRefreshPendingItems();
            }
          });
          
          // Listen to transaction updates (approve/reject/flag actions)
          socket.on('transactionUpdate', (data) {
            if (mounted) {
              _autoRefreshPendingItems();
            }
          });
          
          // Listen to collection updates (approve/reject/flag actions)
          socket.on('collectionUpdate', (data) {
            if (mounted) {
              _autoRefreshPendingItems();
            }
          });
          
          // Listen to expense created/updated events
          socket.on('expenseCreated', (data) {
            if (mounted) {
              _autoRefreshPendingItems();
            }
          });
          
          socket.on('expenseUpdated', (data) {
            if (mounted) {
              _autoRefreshPendingItems();
            }
          });
          
          // Listen to transaction created/updated events
          socket.on('transactionCreated', (data) {
            if (mounted) {
              _autoRefreshPendingItems();
            }
          });
          
          socket.on('transactionUpdated', (data) {
            if (mounted) {
              _autoRefreshPendingItems();
            }
          });
          
          // Listen to collection created/updated events
          socket.on('collectionCreated', (data) {
            if (mounted) {
              _autoRefreshPendingItems();
            }
          });
          
          socket.on('collectionUpdated', (data) {
            if (mounted) {
              _autoRefreshPendingItems();
            }
          });
          
          // Listen to dashboard updates (general updates)
          SocketService.onDashboardUpdate((data) {
            if (mounted) {
              _autoRefreshPendingItems();
            }
          });
          
          // Listen to amount updates (wallet changes may affect approvals)
          SocketService.onAmountUpdate((data) {
            if (mounted) {
              _autoRefreshPendingItems();
            }
          });
        }
      });
    } catch (e) {
      print('❌ [SMART APPROVALS] Error initializing socket listeners: $e');
    }
  }

  /// Clean up socket listeners
  void _cleanupSocketListeners() {
    try {
      final socket = SocketService.socket;
      if (socket != null) {
        socket.off('expenseUpdate');
        socket.off('transactionUpdate');
        socket.off('collectionUpdate');
        socket.off('expenseCreated');
        socket.off('expenseUpdated');
        socket.off('transactionCreated');
        socket.off('transactionUpdated');
        socket.off('collectionCreated');
        socket.off('collectionUpdated');
      }
    } catch (e) {
      print('❌ [SMART APPROVALS] Error cleaning up socket listeners: $e');
    }
  }

  Future<void> _loadPaymentModes() async {
    if (_isLoadingPaymentModes) return;

    setState(() {
      _isLoadingPaymentModes = true;
    });

    try {
      final result = await PaymentModeService.getPaymentModes();
      if (!mounted) {
        return;
      }

      setState(() {
        if (result['success'] == true) {
          final List<dynamic> paymentModesRaw = result['paymentModes'] as List<dynamic>? ?? [];
          _paymentModes = paymentModesRaw
              .map((mode) => Map<String, dynamic>.from(mode as Map))
              .where((mode) => mode['isActive'] != false)
              .toList();
          debugPrint('Loaded ${_paymentModes.length} payment modes for Smart Approvals');
          for (var mode in _paymentModes) {
            debugPrint('Payment mode name: ${mode['modeName']}');
          }
          
          // Update available modes with active payment modes
          final paymentModeNames = _getPaymentModeNames();
          if (paymentModeNames.isNotEmpty) {
            // If we have pending items, filter modes from items to only active ones
            if (_pendingItems.isNotEmpty) {
              final activeModeSet = paymentModeNames.toSet();
              final modeOptionsRaw = _buildFilterOptions(
                _pendingItems,
                'mode',
                defaultOptions: paymentModeNames,
              );
              _availableModes = modeOptionsRaw.where((mode) => 
                mode == _allFilterValue || activeModeSet.contains(mode)
              ).toList();
            } else {
              // If no items yet, just use active payment modes
              _availableModes = [_allFilterValue, ...paymentModeNames];
            }
          }
        } else {
          debugPrint('Failed to load payment modes: ${result['message']}');
        }
        _isLoadingPaymentModes = false;
        _paymentModesLoadedNotifier.value = !_paymentModesLoadedNotifier.value;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingPaymentModes = false;
        _paymentModesLoadedNotifier.value = !_paymentModesLoadedNotifier.value;
      });
    }
  }

  // Get mode names directly from payment modes (actual modeName values)
  List<String> _getPaymentModeNames() {
    if (_paymentModes.isEmpty) {
      return _defaultModeOptions;
    }
    
    // Extract actual modeName from each active payment mode
    final List<String> modeNames = _paymentModes
        .map((mode) => mode['modeName']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    
    // Remove duplicates and sort
    final uniqueModes = modeNames.toSet().toList();
    uniqueModes.sort();
    
    return uniqueModes;
  }

  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final role = prefs.getString('user_role');
      final hasSmartApprovals = await UIPermissionChecker.canAccessSmartApprovals();
      
      // Load action permissions for Smart Approvals
      final isSuperAdmin = await UIPermissionChecker.isSuperAdmin();
      final actionPerms = <String, bool>{};
      
      if (isSuperAdmin) {
        // Super Admin has all permissions
        actionPerms.addAll({
          'transaction.approve': true,
          'transaction.reject': true,
          'transaction.flag': true,
          'transaction.edit': true,
          'transaction.delete': true,
          'collection.approve': true,
          'collection.reject': true,
          'collection.flag': true,
          'collection.edit': true,
          'collection.delete': true,
          'expense.approve': true,
          'expense.reject': true,
          'expense.flag': true,
          'expense.edit': true,
          'expense.delete': true,
        });
      } else {
        // Check each permission
        actionPerms['transaction.approve'] = await UIPermissionChecker.hasPermission('smart_approvals.transaction.approve');
        actionPerms['transaction.reject'] = await UIPermissionChecker.hasPermission('smart_approvals.transaction.reject');
        actionPerms['transaction.flag'] = await UIPermissionChecker.hasPermission('smart_approvals.transaction.flag');
        actionPerms['transaction.edit'] = await UIPermissionChecker.hasPermission('smart_approvals.transaction.edit');
        actionPerms['transaction.delete'] = await UIPermissionChecker.hasPermission('smart_approvals.transaction.delete');
        
        actionPerms['collection.approve'] = await UIPermissionChecker.hasPermission('smart_approvals.collections.approve');
        actionPerms['collection.reject'] = await UIPermissionChecker.hasPermission('smart_approvals.collections.reject');
        actionPerms['collection.flag'] = await UIPermissionChecker.hasPermission('smart_approvals.collections.flag');
        actionPerms['collection.edit'] = await UIPermissionChecker.hasPermission('smart_approvals.collections.edit');
        actionPerms['collection.delete'] = await UIPermissionChecker.hasPermission('smart_approvals.collections.delete');
        
        actionPerms['expense.approve'] = await UIPermissionChecker.hasPermission('smart_approvals.expenses.approve');
        actionPerms['expense.reject'] = await UIPermissionChecker.hasPermission('smart_approvals.expenses.reject');
        actionPerms['expense.flag'] = await UIPermissionChecker.hasPermission('smart_approvals.expenses.flag');
        actionPerms['expense.edit'] = await UIPermissionChecker.hasPermission('smart_approvals.expenses.edit');
        actionPerms['expense.delete'] = await UIPermissionChecker.hasPermission('smart_approvals.expenses.delete');
      }
      
      setState(() {
        _currentUserId = userId;
        _currentUserRole = role;
        _hasSmartApprovalsPermission = hasSmartApprovals;
        _actionPermissions = actionPerms;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadPendingItems() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    final String? typeParam = _normalizeFilterValue(_selectedType);
    final String? modeParam = _normalizeFilterValue(_selectedMode);
    final bool hasShortcutFilters = _activeStatusShortcuts.isNotEmpty;
    final bool useSingleShortcut =
        hasShortcutFilters &&
        _activeStatusShortcuts.length == 1;
    final String? statusParam = hasShortcutFilters
        ? (useSingleShortcut ? _activeStatusShortcuts.first : null)
        : _normalizeFilterValue(_selectedStatus);

    // Debug logging for Flagged filter
    if (_activeStatusShortcuts.contains('Flagged')) {
      print('🔍 [FLAGGED FILTER] Loading items with status filter:');
      print('   Active shortcuts: $_activeStatusShortcuts');
      print('   Status param sent to API: $statusParam');
      print('   Type param: $typeParam');
      print('   Mode param: $modeParam');
    }

    try {
      final response = await PendingApprovalService.getPendingApprovals(
        type: typeParam,
        status: statusParam,
        mode: modeParam,
      );

      if (!mounted) return;

      if (response['success'] != true) {
        final message =
            response['message']?.toString() ?? 'Unable to load pending approvals';
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      final dynamic responseData = response['data'];
      final items = _extractPendingItems(
        responseData is Map<String, dynamic> ? responseData : <String, dynamic>{},
      );

      // Debug logging for Smart Approvals
      print('\n📋 [SMART APPROVALS] Frontend - Items extracted:');
      print('   Total items from API: ${items.length}');
      print('   User Role: $_currentUserRole');
      print('   Has Smart Approvals Permission: $_hasSmartApprovalsPermission');
      if (items.isNotEmpty) {
        print('   Sample items:');
        for (int i = 0; i < (items.length > 3 ? 3 : items.length); i++) {
          final item = items[i];
          print('     Item $i: type=${item['type']}, status=${item['status']}, isReceiver=${item['isReceiver']}, createdBySuperAdmin=${item['createdBySuperAdmin']}');
        }
      }
      print('=====================================\n');

      // Debug logging for Flagged filter
      if (_activeStatusShortcuts.contains('Flagged')) {
        print('🔍 [FLAGGED FILTER] Items received from API:');
        print('   Total items: ${items.length}');
        if (items.isNotEmpty) {
          print('   Sample item statuses:');
          for (int i = 0; i < (items.length > 3 ? 3 : items.length); i++) {
            final item = items[i];
            print('     Item $i: type=${item['type']}, status=${item['status']}');
          }
        }
      }

    items.sort((a, b) {
      final int priorityComparison =
          _statusPriority(a['status']?.toString()) - _statusPriority(b['status']?.toString());
      if (priorityComparison != 0) {
        return priorityComparison;
      }

      final aDate = a['createdAt'] as DateTime?;
      final bDate = b['createdAt'] as DateTime?;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    final typeOptions = _buildFilterOptions(items, 'type');
    final statusOptions = _buildFilterOptions(
      items,
      'status',
      defaultOptions: _defaultStatusOptions,
    );
    // Use actual mode names from payment modes instead of static defaults
    final paymentModeNames = _getPaymentModeNames();
    final modeOptionsRaw = _buildFilterOptions(
      items,
      'mode',
      defaultOptions: paymentModeNames,
    );
    // Filter to only show active payment modes (exclude inactive modes from old items)
    final activeModeSet = paymentModeNames.toSet();
    final modeOptions = modeOptionsRaw.where((mode) => 
      mode == _allFilterValue || activeModeSet.contains(mode)
    ).toList();
      final List<String> statusList =
          statusOptions.where((value) => value != _allFilterValue).toList();
      final statusSet = statusList.toSet();
      final availableIds = items
          .map((item) => item['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

    if (!mounted) return;
    
    setState(() {
      _pendingItems = items;
      _availableTypes = typeOptions;
      _availableStatuses = statusOptions;
      _availableModes = modeOptions;
        _autoPayModes
          ..clear()
          ..addAll(
            items
                .where((item) => item['autoPay'] == true)
                .map((item) => (item['mode'] ?? '').toString().trim())
                .where((mode) => mode.isNotEmpty),
          );
        _bulkSelectedIds.removeWhere((id) => !availableIds.contains(id));
        if (!_availableTypes.contains(_selectedType)) {
      _selectedType = _allFilterValue;
        }
        if (!_availableStatuses.contains(_selectedStatus)) {
      _selectedStatus = _allFilterValue;
        }
        if (!_availableModes.contains(_selectedMode)) {
      _selectedMode = _allFilterValue;
        }
        _activeStatusShortcuts.removeWhere((status) => !statusSet.contains(status));
      if (_activeStatusShortcuts.isEmpty) {
          if (statusSet.contains(_defaultStatusShortcut)) {
            _activeStatusShortcuts.add(_defaultStatusShortcut);
          } else if (statusList.isNotEmpty) {
            _activeStatusShortcuts.add(statusList.first);
          }
        }
        _isLoading = false;
      });

      _ensureSelectionVisibility();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load pending approvals: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _extractPendingItems(Map<String, dynamic>? payload) {
    if (payload == null) {
      return [];
    }

    final results = <Map<String, dynamic>>[];

    void addItems(dynamic source, Map<String, dynamic> Function(dynamic) formatter) {
      if (source is List) {
        for (final entry in source) {
          try {
            results.add(formatter(entry));
          } catch (_) {
            // Ignore malformed entries
          }
        }
      }
    }

    addItems(payload['collections'], _formatCollection);
    addItems(payload['transactions'], _formatTransaction);
    addItems(payload['expenses'], _formatExpense);

    return results;
  }

  // ignore: unused_element
  List<Map<String, dynamic>> _buildMockPendingItems() {
    final now = DateTime.now();

    final seedData = [
      {
        'id': 'txn-1001',
        'type': 'Transactions',
        'from': 'Super Admin',
        'fromId': 'user-1',
        'to': 'Madhan',
        'toId': 'user-2',
        'mode': 'UPI',
        'amountValue': 520.0,
        'purpose': 'Team reimbursement',
        'status': 'Approved',
        'createdAt': now.subtract(const Duration(hours: 2)),
        'createdBySuperAdmin': true,
        'createdByName': 'Super Admin',
        'isReceiver': false,
        'approvedByName': 'Karthick',
        'notes': 'Reimbursed via UPI settlement',
        'proofUrl': 'https://via.placeholder.com/480x320.png?text=UPI+Receipt',
      },
      {
        'id': 'exp-2042',
        'type': 'Expenses',
        'from': 'Madhan',
        'fromId': 'user-2',
        'to': 'Logistics',
        'toId': 'vendor-9',
        'mode': 'Cash',
        'amountValue': 150.0,
        'purpose': 'Office supplies',
        'status': 'Pending',
        'createdAt': now.subtract(const Duration(hours: 5)),
        'createdBySuperAdmin': false,
        'createdByName': 'Madhan',
        'category': 'Stationery',
        'isReceiver': true,
        'notes': 'Need approval before Friday',
        'proofUrl': 'https://via.placeholder.com/480x320.png?text=Bill',
      },
      {
        'id': 'col-3099',
        'type': 'Collections',
        'from': 'Rajesh',
        'fromId': 'user-3',
        'to': 'Super Admin',
        'toId': 'user-1',
        'mode': 'Bank',
        'amountValue': 250.0,
        'purpose': 'Customer payment',
        'customerName': 'Innotech Pvt Ltd',
        'voucherNumber': 'VCH-6542',
        'status': 'Flagged',
        'autoPay': true,
        'createdAt': now.subtract(const Duration(days: 1, hours: 3)),
        'createdBySuperAdmin': false,
        'createdByName': 'Rajesh',
        'approvedByName': 'Karthick',
        'notes': 'Customer requested verification of account details',
        'isReceiver': false,
        'proofUrl': 'https://via.placeholder.com/480x320.png?text=Bank+Slip',
      },
    ];

    return seedData.map((entry) {
      final raw = Map<String, dynamic>.from(entry);
      final createdAt = raw['createdAt'] as DateTime;
      final amountValue = (raw['amountValue'] as num).toDouble();
      return {
        ...raw,
        'amount': _formatCurrency(amountValue),
        'date': _formatDateLabel(createdAt),
        'raw': raw,
      };
    }).toList();
  }

  String? _normalizeFilterValue(String value) {
    if (value.isEmpty || value == _allFilterValue) {
      return null;
    }
    return value;
  }

  List<String> _buildFilterOptions(
    List<Map<String, dynamic>> items,
    String key, {
    List<String>? defaultOptions,
  }) {
    final values = <String>{};
    
    // Add default options if provided
    if (defaultOptions != null) {
      values.addAll(defaultOptions);
    }
    
    // Extract values from items
    for (final item in items) {
      final value = item[key];
      if (value is String && value.trim().isNotEmpty) {
        values.add(value.trim());
      }
    }
    
    final sorted = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [_allFilterValue, ...sorted];
  }

  void _setActionInProgress(String itemId, String actionKey) {
    setState(() {
      _activeActionItemId = itemId;
      _activeActionKey = actionKey;
    });
  }

  void _clearActionInProgress() {
    if (!mounted) return;
    setState(() {
      _activeActionItemId = null;
      _activeActionKey = null;
    });
  }

  bool _isActionInProgress(String itemId, String actionKey) {
    return _activeActionItemId == itemId && _activeActionKey == actionKey;
  }

  String _normalizeStatusValue(String status) => status.toLowerCase().trim();

  int _statusPriority(String? status) {
    final normalized = _normalizeStatusValue((status ?? '').toString());
    if (normalized == 'flagged') {
      return 0;
    }
    if (normalized == 'pending') {
      return 1;
    }
    return 2;
  }

  bool _isApprovedOrAccounted(String status) {
    final normalized = _normalizeStatusValue(status);
    return normalized == 'approved' || normalized == 'completed' || normalized == 'accounted';
  }

  bool _canApproveItem(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'Pending').toString();
    return !_isApprovedOrAccounted(status);
  }

  bool _canRejectItem(Map<String, dynamic> item) {
    final status = (item['status'] ?? '').toString();
    return _normalizeStatusValue(status) != 'rejected';
  }

  bool _isItemBulkSelected(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) {
      return false;
    }
    return _bulkSelectedIds.contains(id);
  }

  void _updateBulkSelection(Map<String, dynamic> item, bool shouldSelect) {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) {
      return;
    }
    setState(() {
      if (shouldSelect) {
        _bulkSelectedIds.add(id);
      } else {
        _bulkSelectedIds.remove(id);
      }
    });
  }

  void _toggleSelectAllFor(List<Map<String, dynamic>> items) {
    final selectableIds = items
        .where(_canApproveItem)
        .map((item) => item['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    if (selectableIds.isEmpty) {
      return;
    }

    final bool allSelected = _bulkSelectedIds.containsAll(selectableIds);
    setState(() {
      if (allSelected) {
        _bulkSelectedIds.removeAll(selectableIds);
      } else {
        _bulkSelectedIds.addAll(selectableIds);
      }
    });
  }

  Widget _buildBulkHeaderCheckbox(List<Map<String, dynamic>> items) {
    final selectableIds = items
        .where(_canApproveItem)
        .map((item) => item['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final bool anySelected = selectableIds.any(_bulkSelectedIds.contains);
    final bool allSelected = selectableIds.isNotEmpty && _bulkSelectedIds.containsAll(selectableIds);

    return SizedBox(
      width: 40,
      child: Checkbox(
        value: allSelected
            ? true
            : anySelected
                ? null
                : false,
        tristate: true,
        onChanged: (_isBulkActionInProgress || selectableIds.isEmpty)
            ? null
            : (_) => _toggleSelectAllFor(items),
      ),
    );
  }

  Widget _buildFilterToolbar({
    required bool isMobile,
    required bool isTablet,
    required int itemCount,
  }) {
    final typeOptions = _availableTypes.isNotEmpty ? _availableTypes : [_allFilterValue];
    final statusOptions = _availableStatuses.isNotEmpty ? _availableStatuses : [_allFilterValue];
    final modeOptions = _availableModes.isNotEmpty ? _availableModes : [_allFilterValue];
    final double controlWidth;
    if (isMobile) {
      controlWidth = double.infinity;
    } else if (isTablet) {
      controlWidth = 210;
    } else {
      controlWidth = 240;
    }

    final EdgeInsets cardPadding = EdgeInsets.symmetric(
      horizontal: isMobile ? 12 : 24,
      vertical: isMobile ? 10 : 16,
    );

    return Container(
      margin: EdgeInsets.only(
        left: isMobile ? 0 : 8,
        right: isMobile ? 0 : 8,
        bottom: isMobile ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x190F172A),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        _buildQuickStatusFilters(
          isMobile: isMobile,
        ),
            SizedBox(height: isMobile ? 10 : 12),
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFilterDropdown(
                        label: 'Type',
                        value: typeOptions.contains(_selectedType) ? _selectedType : _allFilterValue,
                        options: typeOptions,
                        width: controlWidth,
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value;
                          });
                          _ensureSelectionVisibility();
                          _loadPendingItems();
                        },
                      ),
                      SizedBox(height: isMobile ? 10 : 12),
                      _buildFilterDropdown(
                        label: 'Status',
                        value: statusOptions.contains(_selectedStatus) ? _selectedStatus : _allFilterValue,
                        options: statusOptions,
                        width: controlWidth,
                        onChanged: (value) {
                          setState(() {
                            _activeStatusShortcuts.clear();
                            _selectedStatus = value;
                          });
                          _loadPendingItems();
                        },
                      ),
                      SizedBox(height: isMobile ? 10 : 12),
                      ValueListenableBuilder<bool>(
                        valueListenable: _paymentModesLoadedNotifier,
                        builder: (context, _, __) {
                          final modeOptions = _availableModes.isNotEmpty ? _availableModes : [_allFilterValue];
                          return _buildFilterDropdown(
                            label: 'Mode',
                            value: modeOptions.contains(_selectedMode) ? _selectedMode : _allFilterValue,
                            options: modeOptions,
                            width: controlWidth,
                            highlightOptions: _autoPayModes,
                            highlightLabel: 'AutoPay',
                            onChanged: (value) {
                              setState(() {
                                _selectedMode = value;
                              });
                              _loadPendingItems();
                            },
                          );
                        },
                      ),
                    ],
                  )
                : Wrap(
                    spacing: 18,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildFilterDropdown(
                        label: 'Type',
                        value: typeOptions.contains(_selectedType) ? _selectedType : _allFilterValue,
                        options: typeOptions,
                        width: controlWidth,
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value;
                          });
                          _ensureSelectionVisibility();
                          _loadPendingItems();
                        },
                      ),
                      _buildFilterDropdown(
                        label: 'Status',
                        value: statusOptions.contains(_selectedStatus) ? _selectedStatus : _allFilterValue,
                        options: statusOptions,
                        width: controlWidth,
                        onChanged: (value) {
                          setState(() {
                            _activeStatusShortcuts.clear();
                            _selectedStatus = value;
                          });
                          _loadPendingItems();
                        },
                      ),
                      SizedBox(width: 24),
                      ValueListenableBuilder<bool>(
                        valueListenable: _paymentModesLoadedNotifier,
                        builder: (context, _, __) {
                          final modeOptions = _availableModes.isNotEmpty ? _availableModes : [_allFilterValue];
                          return _buildFilterDropdown(
                            label: 'Mode',
                            value: modeOptions.contains(_selectedMode) ? _selectedMode : _allFilterValue,
                            options: modeOptions,
                            width: controlWidth,
                            highlightOptions: _autoPayModes,
                            highlightLabel: 'AutoPay',
                            onChanged: (value) {
                              setState(() {
                                _selectedMode = value;
                              });
                              _loadPendingItems();
                            },
                          );
                        },
                      ),
                    ],
                  ),
            SizedBox(height: isMobile ? 10 : 16),
            _buildToolbarSummary(itemCount),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<_PendingExportFormat> _buildPendingExportMenuItem({
    required _PendingExportFormat format,
    required String label,
    required IconData icon,
    required bool isMobile,
  }) {
    return PopupMenuItem<_PendingExportFormat>(
      value: format,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isMobile ? 18 : 20,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    required double width,
    Set<String>? highlightOptions,
    String? highlightLabel,
  }) {
    final isMobile = Responsive.isMobile(context);
    final effectiveValue = options.contains(value) ? value : _allFilterValue;
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16,
            vertical: isMobile ? 2 : 4,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: effectiveValue,
            isExpanded: true,
            items: options
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            option,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (highlightOptions != null &&
                            highlightLabel != null &&
                            option != _allFilterValue &&
                            highlightOptions.contains(option)) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              highlightLabel,
                              style: AppTheme.bodySmall.copyWith(
                                fontSize: 11,
                                letterSpacing: 0.3,
                                color: AppTheme.secondaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (selected) {
              if (selected == null) return;
              onChanged(selected);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatusFilters({
    required bool isMobile,
  }) {
    final filteredItems = _filteredItems;
    final Widget quickButtons = Wrap(
      spacing: isMobile ? 8 : 12,
      runSpacing: isMobile ? 8 : 12,
      children: [
        _buildStatusQuickButton(
          label: 'Pending Approvals',
          statusValue: 'Pending',
          icon: Icons.hourglass_bottom_outlined,
          isSelected: _activeStatusShortcuts.contains('Pending'),
          isMobile: isMobile,
        ),
        _buildStatusQuickButton(
          label: 'Flagged',
          statusValue: 'Flagged',
          icon: Icons.flag_outlined,
          isSelected: _activeStatusShortcuts.contains('Flagged'),
          isMobile: isMobile,
        ),
      ],
    );
    final Widget exportButton = Builder(
      builder: (context) {
        final bool isBusy = _isExporting;
        final bool canExport = !isBusy && filteredItems.isNotEmpty;
        final double iconSize = isMobile ? 14 : 16;
        final double fontSize = isMobile ? 12 : 13;

        return OutlinedButton.icon(
          onPressed: canExport
              ? () async {
                  final RenderBox? buttonBox = context.findRenderObject() as RenderBox?;
                  final OverlayState? overlayState = Overlay.of(context);
                  final RenderBox? overlayBox =
                      overlayState?.context.findRenderObject() as RenderBox?;

                  if (buttonBox == null || overlayBox == null) {
                    await _exportFilteredItems(filteredItems);
                    return;
                  }

                  final Offset offset =
                      buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
                  final RelativeRect position = RelativeRect.fromRect(
                    Rect.fromLTWH(
                      offset.dx,
                      offset.dy,
                      buttonBox.size.width,
                      buttonBox.size.height,
                    ),
                    Offset.zero & overlayBox.size,
                  );

                  final _PendingExportFormat? format = await showMenu<_PendingExportFormat>(
                    context: context,
                    position: position,
                    items: [
                      _buildPendingExportMenuItem(
                        format: _PendingExportFormat.csv,
                        label: 'CSV',
                        icon: Icons.table_rows_outlined,
                        isMobile: isMobile,
                      ),
                      _buildPendingExportMenuItem(
                        format: _PendingExportFormat.excel,
                        label: 'Excel',
                        icon: Icons.grid_on_outlined,
                        isMobile: isMobile,
                      ),
                      _buildPendingExportMenuItem(
                        format: _PendingExportFormat.pdf,
                        label: 'PDF',
                        icon: Icons.picture_as_pdf_outlined,
                        isMobile: isMobile,
                      ),
                    ],
                  );

                  if (format != null) {
                    await _exportFilteredItems(filteredItems, format: format);
                  }
                }
              : null,
          icon: isBusy
              ? SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.download_outlined, size: iconSize),
          label: Text(
            'Export As',
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 8 : 10,
            ),
            foregroundColor: AppTheme.primaryColor,
            side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.6)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
    );

    final Widget actionButtons = SizedBox(
      width: isMobile ? double.infinity : null,
      child: Wrap(
        spacing: isMobile ? 8 : 12,
        runSpacing: isMobile ? 8 : 12,
        alignment: isMobile ? WrapAlignment.start : WrapAlignment.end,
        children: [
          exportButton,
          OutlinedButton.icon(
            onPressed: _isUsingDefaultFilters ? null : _clearFilters,
            icon: Icon(Icons.clear_all, size: isMobile ? 16 : 18),
            label: Text(
              'Clear Filters',
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 12 : 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 20,
                vertical: isMobile ? 8 : 12,
              ),
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          quickButtons,
          SizedBox(height: isMobile ? 10 : 12),
          actionButtons,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: quickButtons),
        const SizedBox(width: 16),
        actionButtons,
      ],
    );
  }

  Widget _buildStatusQuickButton({
    required String label,
    required String statusValue,
    required IconData icon,
    required bool isSelected,
    required bool isMobile,
  }) {
    final bool isActive = isSelected;
    final Color activeColor = AppTheme.primaryColor;
    final Color inactiveBorder = AppTheme.borderColor.withOpacity(0.7);
    final Color foregroundColor = isActive ? activeColor : AppTheme.textSecondary;
    final Color borderColor = isActive ? activeColor.withOpacity(0.8) : inactiveBorder;
    final Color backgroundColor = Colors.white;

    final double horizontalPadding = isMobile
        ? AppTheme.quickFilterHorizontalPaddingMobile
        : AppTheme.quickFilterHorizontalPaddingDesktop;
    final double verticalPadding = isMobile
        ? AppTheme.quickFilterVerticalPaddingMobile
        : AppTheme.quickFilterVerticalPaddingDesktop;
    final double iconSize = isMobile ? 14 : 16;
    final double fontSize = isMobile ? 12 : 13;

    return OutlinedButton.icon(
      onPressed: () {
        final bool shouldSelect = !isSelected;
        setState(() {
          if (shouldSelect) {
            _activeStatusShortcuts.add(statusValue);
            print('✅ [SMART APPROVALS] Added status shortcut: $statusValue');
            print('   Active shortcuts: $_activeStatusShortcuts');
          } else {
            _activeStatusShortcuts.remove(statusValue);
            print('❌ [SMART APPROVALS] Removed status shortcut: $statusValue');
            print('   Active shortcuts: $_activeStatusShortcuts');
          }
          _selectedStatus = _allFilterValue;
        });
        print('🔍 [SMART APPROVALS] Filtered items count: ${_filteredItems.length}');
        // Reload items from API when status shortcut changes to ensure correct filtering
        _loadPendingItems();
        _ensureSelectionVisibility();
      },
      icon: Icon(
        icon,
        size: iconSize,
        color: foregroundColor,
      ),
      label: Text(
        label,
        style: AppTheme.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
          letterSpacing: 0.1,
          color: foregroundColor,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: foregroundColor,
        backgroundColor: backgroundColor,
        side: BorderSide(color: borderColor, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ).merge(
        ButtonStyle(
          overlayColor: MaterialStateProperty.all(
            activeColor.withOpacity(0.08),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarSummary(int itemCount) {
    final isMobile = Responsive.isMobile(context);
    final quickStatuses = _activeStatusShortcuts.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final summaryParts = <String>[
      _selectedType == _allFilterValue ? 'All Transactions' : _selectedType,
      if (_selectedStatus != _allFilterValue) _selectedStatus,
      if (_selectedStatus == _allFilterValue && quickStatuses.isNotEmpty)
        quickStatuses.join(' + '),
      if (_selectedMode != _allFilterValue) _selectedMode,
    ];
    final selectionSummary = summaryParts.join(' • ');

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Showing: $selectionSummary ($itemCount records)',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.start,
            children: [
              _buildHeaderActionButton(_HeaderAction.approve, 'Approve'),
              _buildHeaderActionButton(_HeaderAction.unapprove, 'Unapprove'),
              _buildHeaderActionButton(_HeaderAction.reject, 'Reject'),
              _buildHeaderActionButton(_HeaderAction.edit, 'Edit'),
              _buildHeaderActionButton(_HeaderAction.flag, 'Flag'),
              _buildHeaderActionButton(_HeaderAction.delete, 'Delete'),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Showing: $selectionSummary ($itemCount records)',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 44,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeaderActionButton(_HeaderAction.approve, 'Approve'),
                const SizedBox(width: 8),
                _buildHeaderActionButton(_HeaderAction.unapprove, 'Unapprove'),
                const SizedBox(width: 8),
                _buildHeaderActionButton(_HeaderAction.reject, 'Reject'),
                const SizedBox(width: 8),
                _buildHeaderActionButton(_HeaderAction.edit, 'Edit'),
                const SizedBox(width: 8),
                _buildHeaderActionButton(_HeaderAction.flag, 'Flag'),
                const SizedBox(width: 8),
                _buildHeaderActionButton(_HeaderAction.delete, 'Delete'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderActionButton(
    _HeaderAction action,
    String label,
  ) {
    final selected = _getSelectedItem();
    final hasSelection = selected != null;

    String normalizedStatus = '';
    bool isApproved = false;
    bool isAccounted = false;
    bool isFlagged = false;
    if (selected != null) {
      normalizedStatus = _normalizeStatusValue(selected['status']?.toString() ?? '');
      isApproved = normalizedStatus == 'approved' || normalizedStatus == 'completed';
      isAccounted = normalizedStatus == 'accounted';
      isFlagged = normalizedStatus == 'flagged';
    }

    final Map<String, dynamic>? selectedItem = selected;

    bool isEnabled = false;
    Color activeColor = AppTheme.textPrimary;
    IconData icon = Icons.help_outline;
    VoidCallback? onPressed;

    // IMPORTANT: If status is Approved or Completed, disable ALL action buttons
    // No actions should be allowed on approved/completed items in self wallet
    final bool isApprovedOrCompleted = isApproved || isAccounted;
    
    switch (action) {
      case _HeaderAction.approve:
        icon = Icons.check_circle_outline;
        activeColor = Colors.green.shade600;
        isEnabled = hasSelection && !isApprovedOrCompleted;
        if (isEnabled && selectedItem != null) {
          final Map<String, dynamic> item = selectedItem;
          onPressed = () async {
            await _approveItem(item);
          };
        }
        break;
      case _HeaderAction.unapprove:
        icon = Icons.undo;
        activeColor = Colors.orange.shade600;
        // Disable unapprove when status is Approved or Completed
        isEnabled = false; // Always disabled for approved/completed items
        break;
      case _HeaderAction.reject:
        icon = Icons.cancel_outlined;
        activeColor = Colors.red.shade600;
        isEnabled = hasSelection && !isApprovedOrCompleted && normalizedStatus != 'rejected';
        if (isEnabled && selectedItem != null) {
          final Map<String, dynamic> item = selectedItem;
          onPressed = () async => _rejectItem(item);
        }
        break;
      case _HeaderAction.flag:
        icon = Icons.flag_outlined;
        activeColor = Colors.orange.shade600;
        isEnabled = hasSelection && !isFlagged && !isApprovedOrCompleted;
        if (isEnabled && selectedItem != null) {
          final Map<String, dynamic> item = selectedItem;
          onPressed = () async => _flagItem(item);
        }
        break;
      case _HeaderAction.edit:
        icon = Icons.edit_outlined;
        activeColor = Colors.indigo.shade500;
        isEnabled = hasSelection && !isApprovedOrCompleted;
        if (isEnabled && selectedItem != null) {
          final Map<String, dynamic> item = selectedItem;
          onPressed = () async => _editItem(item);
        }
        break;
      case _HeaderAction.delete:
        icon = Icons.delete_outline;
        activeColor = Colors.red.shade600;
        isEnabled = hasSelection && !isApprovedOrCompleted;
        if (isEnabled && selectedItem != null) {
          final Map<String, dynamic> item = selectedItem;
          onPressed = () async => _deleteItem(item);
        }
        break;
    }

    return ActionPillButton(
      icon: icon,
      label: label,
      color: activeColor,
      onPressed: onPressed,
      enabled: isEnabled,
      dense: true,
    );
  }

  Map<String, dynamic>? _getSelectedItem() {
    if (_selectedItemId == null) {
      return null;
    }
    try {
      return _filteredItems.firstWhere(
        (item) => item['id']?.toString() == _selectedItemId.toString(),
        orElse: () => {},
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleUnapprove(Map<String, dynamic> item) async {
    final String id = item['id']?.toString() ?? '';
    final String type = item['type']?.toString() ?? '';
    if (id.isEmpty || type.isEmpty) {
      return;
    }

    _setActionInProgress(id, 'unapprove');

    try {
      Map<String, dynamic> result;
      if (type == 'Collections') {
        result = await CollectionService.restoreCollection(id);
      } else if (type == 'Transactions') {
        result = await TransactionService.cancelTransaction(id);
      } else if (type == 'Expenses') {
        result = await ExpenseService.updateExpenseStatus(id, 'Unapproved');
      } else {
        _showComingSoon('Unapprove');
        return;
      }

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '${item['type']} moved to unapproved'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        await _loadPendingItems();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to unapprove ${item['type']}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unapprove: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      _clearActionInProgress();
    }
  }

  void _showComingSoon(String actionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$actionName action is not available yet'),
        backgroundColor: AppTheme.warningColor,
      ),
    );
  }

  void _clearFilters() {
    final bool shouldReload = !_isUsingDefaultFilters;
    setState(() {
      _selectedType = _allFilterValue;
      _selectedStatus = _allFilterValue;
      _selectedMode = _allFilterValue;
      _selectedItemId = null;
      _showDetailPanel = false;
      _activeStatusShortcuts
        ..clear()
        ..add(_defaultStatusShortcut);
    });
    if (shouldReload) {
      _loadPendingItems();
    }
  }

  void _ensureSelectionVisibility() {
    if (!mounted || _selectedItemId == null) return;
    final exists = _filteredItems.any((item) => item['id']?.toString() == _selectedItemId.toString());
    if (!exists) {
      if (mounted) {
        setState(() {
          _selectedItemId = null;
          _showDetailPanel = false;
          _selectedIndex = null;
        });
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pending_actions_outlined,
            size: 76,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No pending approvals match the selected filters',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportFilteredItems(
    List<Map<String, dynamic>> items, {
    _PendingExportFormat? format,
  }) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No records available to export'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
    });

    final filters = <String, String>{};
    if (_selectedType != _allFilterValue) filters['type'] = _selectedType;
    if (_selectedStatus != _allFilterValue) filters['status'] = _selectedStatus;
    if (_selectedMode != _allFilterValue) filters['mode'] = _selectedMode;

    final ids = items
        .map((item) => item['id'])
        .where((value) => value != null)
        .map((value) => value.toString())
        .toList();

    final payload = {
      'filters': filters,
      'ids': ids,
    };

    if (format != null) {
      payload['format'] = _pendingExportFormatKey(format);
    }

    try {
      final response = await PendingApprovalService.exportPendingApprovals(payload);

      if (!mounted) return;

      if (response['success'] == true) {
        final String defaultMessage = format != null
            ? '${_pendingExportFormatLabel(format)} export requested successfully'
            : 'Export request sent successfully';
        final message = response['message'] ?? defaultMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Export failed'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _buildExportErrorMessage(
              e.toString().replaceFirst('Exception: ', ''),
              format: format,
            ),
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  String _pendingExportFormatKey(_PendingExportFormat format) {
    switch (format) {
      case _PendingExportFormat.csv:
        return 'csv';
      case _PendingExportFormat.excel:
        return 'excel';
      case _PendingExportFormat.pdf:
        return 'pdf';
    }
  }

  String _pendingExportFormatLabel(_PendingExportFormat format) {
    switch (format) {
      case _PendingExportFormat.csv:
        return 'CSV';
      case _PendingExportFormat.excel:
        return 'Excel';
      case _PendingExportFormat.pdf:
        return 'PDF';
    }
  }

  String _buildExportErrorMessage(
    String error, {
    _PendingExportFormat? format,
  }) {
    if (format == null) {
      return 'Export failed: $error';
    }
    return '${_pendingExportFormatLabel(format)} export failed: $error';
  }

  Widget _buildTable(List<Map<String, dynamic>> items, {required bool isMobile}) {
    final horizontalPadding = widget.embedInDashboard
        ? (isMobile ? 8.0 : 12.0)
        : (isMobile ? 16.0 : 24.0);
    final verticalPadding = widget.embedInDashboard
        ? (isMobile ? 8.0 : 12.0)
        : (isMobile ? 12.0 : 20.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        verticalPadding,
        horizontalPadding,
        widget.embedInDashboard ? (isMobile ? 12.0 : 16.0) : (isMobile ? 16.0 : 24.0),
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTableActionBar(isMobile: isMobile),
                    const SizedBox(height: 12),
                    ...items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _buildMobileApprovalCard(
                        items: items,
                        index: index,
                        item: item,
                      );
                    }).toList(),
                  ],
                )
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.borderColor.withValues(alpha: 0.8),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTableActionBar(isMobile: isMobile),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.borderColor.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildBulkHeaderCheckbox(items),
                              ),
                              _buildTableHeaderCell('Date & Time\nCreated By', flex: 12),
                              _buildTableHeaderCell('Type', flex: 8),
                              _buildTableHeaderCell('From → To', flex: 16),
                              Expanded(
                                flex: 8,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Mode',
                                      textAlign: TextAlign.left,
                                      style: AppTheme.labelMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        letterSpacing: 0.3,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _buildTableHeaderCell('Amount', flex: 7),
                              _buildTableHeaderCell('Purpose', flex: 12),
                              _buildTableHeaderCell('Status', flex: 8),
                              _buildTableHeaderCell('Actions', flex: 22, align: TextAlign.center),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return _buildDesktopApprovalRow(
                            items: items,
                            index: index,
                            item: item,
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(
    String title, {
    required int flex,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: align == TextAlign.center
            ? Alignment.center
            : align == TextAlign.right
                ? Alignment.centerRight
                : Alignment.centerLeft,
        child: Text(
          title,
          textAlign: align,
          style: AppTheme.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.3,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopApprovalRow({
    required List<Map<String, dynamic>> items,
    required int index,
    required Map<String, dynamic> item,
  }) {
    final createdAt = _parseDateTime(item['createdAt']) ?? DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy').format(createdAt);
    final timeStr = DateFormat('hh:mm a').format(createdAt);
    final createdBy = (item['createdByName'] ?? item['createdBy'])?.toString() ?? '-';
    final from = (item['from'] ?? '-').toString();
    final to = (item['to'] ?? '-').toString();
    final purpose = (item['purpose'] ?? '-').toString();
    final amount = (item['amount'] ?? '₹0').toString();
    final mode = (item['mode'] ?? 'N/A').toString();
    final status = (item['status'] ?? 'Pending').toString();
    final type = (item['type'] ?? 'N/A').toString();
    final itemId = item['id']?.toString() ?? '';
    final isSelected = _selectedItemId != null &&
        item['id']?.toString() == _selectedItemId.toString();
    final bool isBulkSelectable = _canApproveItem(item) && itemId.isNotEmpty;
    final bool isBulkSelected = isBulkSelectable && _bulkSelectedIds.contains(itemId);

    final Color baseRowColor = index.isEven
        ? Colors.transparent
        : AppTheme.surfaceColor.withValues(alpha: 0.35);
    final Color rowColor =
        isSelected ? AppTheme.primaryColor.withValues(alpha: 0.12) : baseRowColor;

    final borderColor = AppTheme.borderColor.withValues(alpha: 0.45);
    final bool isLast = index == items.length - 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: null,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        mouseCursor: MouseCursor.defer,
        child: Container(
          decoration: BoxDecoration(
            color: rowColor,
            border: Border(
              bottom: BorderSide(
                color: borderColor,
                width: isLast ? 0 : 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                child: Checkbox(
                  value: isBulkSelected,
                  onChanged: (!_isBulkActionInProgress && isBulkSelectable)
                      ? (checked) => _updateBulkSelection(item, checked ?? false)
                      : null,
                ),
              ),
              Expanded(
                flex: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dateStr,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'By: $createdBy',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 8,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getTypeColor(type).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      type,
                      style: AppTheme.bodySmall.copyWith(
                        color: _getTypeColor(type),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      flex: 1,
                      child: Text(
                        from,
                        style: AppTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 12,
                        color: AppTheme.textSecondary.withOpacity(0.7),
                      ),
                    ),
                    Flexible(
                      flex: 1,
                      child: Text(
                        to,
                        style: AppTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 8,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                  child: _buildModeChip(mode),
                  ),
                ),
              ),
              Expanded(
                flex: 7,
                child: Text(
                  amount,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  purpose,
                  style: AppTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildStatusBadge(status),
                  ],
                ),
              ),
              Expanded(
                flex: 22,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _buildActions(item),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileApprovalCard({
    required List<Map<String, dynamic>> items,
    required int index,
    required Map<String, dynamic> item,
  }) {
    final createdAt = _parseDateTime(item['createdAt']) ?? DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy').format(createdAt);
    final timeStr = DateFormat('hh:mm a').format(createdAt);
    final createdBy = (item['createdByName'] ?? item['createdBy'])?.toString() ?? '-';
    final amount = (item['amount'] ?? '₹0').toString();
    final mode = (item['mode'] ?? 'N/A').toString();
    final status = (item['status'] ?? 'Pending').toString();
    final type = (item['type'] ?? 'N/A').toString();
    final purpose = (item['purpose'] ?? '-').toString();
    final from = (item['from'] ?? '-').toString();
    final to = (item['to'] ?? '-').toString();
    final itemId = item['id']?.toString() ?? '';
    final bool isBulkSelectable = _canApproveItem(item) && itemId.isNotEmpty;
    final bool isBulkSelected = isBulkSelectable && _bulkSelectedIds.contains(itemId);

    final isSelected = _selectedItemId != null &&
        item['id']?.toString() == _selectedItemId.toString();

    final borderColor = isSelected
        ? AppTheme.primaryColor.withValues(alpha: 0.6)
        : AppTheme.borderColor.withValues(alpha: 0.6);

    return Card(
      margin: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 12),
      elevation: 0,
      color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: null,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        mouseCursor: MouseCursor.defer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: isBulkSelected,
                    onChanged: (!_isBulkActionInProgress && isBulkSelectable)
                        ? (checked) => _updateBulkSelection(item, checked ?? false)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$dateStr • $timeStr',
                              style: AppTheme.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'By: $createdBy',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getTypeColor(type).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            type,
                            style: AppTheme.bodySmall.copyWith(
                              color: _getTypeColor(type),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMobileDetailRow(label: 'From', value: from),
              _buildMobileDetailRow(label: 'To', value: to),
              _buildMobileDetailRow(label: 'Mode', value: mode),
              _buildMobileDetailRow(label: 'Amount', value: amount),
              if (purpose.isNotEmpty && purpose != '-')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    purpose,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
              _buildStatusBadge(status),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildModeChip(mode),
                ),
              ),
                ],
              ),
              const SizedBox(height: 12),
              _buildActions(item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDetailRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '$label:',
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  void _handleRowTap(List<Map<String, dynamic>> items, Map<String, dynamic> item) {
    _selectItem(item, showInline: true);
  }

  Future<void> _showDetailDialog(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> initialItem,
  ) async {
    if (!mounted || items.isEmpty) {
      return;
    }

    final initialId = initialItem['id']?.toString();
    int currentIndex = items.indexWhere((entry) => entry['id']?.toString() == initialId);
    if (currentIndex == -1) {
      final fallbackIndex = items.indexOf(initialItem);
      currentIndex = fallbackIndex == -1 ? 0 : fallbackIndex;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final activeItem = items[currentIndex];
            final media = MediaQuery.of(dialogContext);
            final maxWidth = media.size.width > 900 ? 760.0 : media.size.width * 0.92;
            final contentPadding = media.size.width > 600 ? 28.0 : 20.0;

            void handleNavigate(int offset) {
              final nextIndex = currentIndex + offset;
              if (nextIndex < 0 || nextIndex >= items.length) {
                return;
              }
              final nextItem = items[nextIndex];
              _selectItem(nextItem, showInline: false);
              setDialogState(() {
                currentIndex = nextIndex;
              });
            }

            final actionState = _deriveDetailActionState(activeItem);
            final bool canNavigatePrevious = currentIndex > 0;
            final bool canNavigateNext = currentIndex < items.length - 1;

            void handleApprovalSuccess() {
              final approvedId = activeItem['id']?.toString() ?? '';
              if (approvedId.isEmpty) {
                return;
              }

              items.removeWhere((entry) => entry['id']?.toString() == approvedId);

              if (items.isEmpty) {
                Navigator.of(dialogContext).pop();
                return;
              }

              if (currentIndex >= items.length) {
                Navigator.of(dialogContext).pop();
                return;
              }

              final nextSelection = items[currentIndex];
              _selectItem(nextSelection, showInline: false);
              setDialogState(() {});
            }

            return Shortcuts(
              shortcuts: <ShortcutActivator, Intent>{
                const SingleActivator(LogicalKeyboardKey.digit1): const _ApproveIntent(),
                const SingleActivator(LogicalKeyboardKey.numpad1): const _ApproveIntent(),
                const SingleActivator(LogicalKeyboardKey.keyA): const _ApproveIntent(),
                const SingleActivator(LogicalKeyboardKey.digit2): const _RejectIntent(),
                const SingleActivator(LogicalKeyboardKey.numpad2): const _RejectIntent(),
                const SingleActivator(LogicalKeyboardKey.keyR): const _RejectIntent(),
                const SingleActivator(LogicalKeyboardKey.digit3): const _FlagIntent(),
                const SingleActivator(LogicalKeyboardKey.numpad3): const _FlagIntent(),
                const SingleActivator(LogicalKeyboardKey.keyF): const _FlagIntent(),
                const SingleActivator(LogicalKeyboardKey.digit4): const _DeleteIntent(),
                const SingleActivator(LogicalKeyboardKey.numpad4): const _DeleteIntent(),
                const SingleActivator(LogicalKeyboardKey.keyD): const _DeleteIntent(),
                const SingleActivator(LogicalKeyboardKey.digit5): const _EditIntent(),
                const SingleActivator(LogicalKeyboardKey.numpad5): const _EditIntent(),
                const SingleActivator(LogicalKeyboardKey.keyE): const _EditIntent(),
                const SingleActivator(LogicalKeyboardKey.arrowLeft): const _PreviousIntent(),
                const SingleActivator(LogicalKeyboardKey.arrowUp): const _PreviousIntent(),
                const SingleActivator(LogicalKeyboardKey.arrowRight): const _NextIntent(),
                const SingleActivator(LogicalKeyboardKey.arrowDown): const _NextIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _ApproveIntent: CallbackAction<_ApproveIntent>(
                    onInvoke: (intent) {
                      if (actionState.canApprove) {
                        _approveItem(activeItem).then((success) {
                          if (success) {
                            handleApprovalSuccess();
                          }
                        });
                      }
                      return null;
                    },
                  ),
                  _RejectIntent: CallbackAction<_RejectIntent>(
                    onInvoke: (intent) {
                      if (actionState.canReject) {
                        _rejectItem(activeItem);
                      }
                      return null;
                    },
                  ),
                  _FlagIntent: CallbackAction<_FlagIntent>(
                    onInvoke: (intent) {
                      if (actionState.canFlag) {
                        _flagItem(activeItem);
                      }
                      return null;
                    },
                  ),
                  _DeleteIntent: CallbackAction<_DeleteIntent>(
                    onInvoke: (intent) {
                      if (actionState.canDelete) {
                        _deleteItem(activeItem);
                      }
                      return null;
                    },
                  ),
                  _EditIntent: CallbackAction<_EditIntent>(
                    onInvoke: (intent) {
                      if (actionState.canEdit) {
                        _editItem(activeItem);
                      }
                      return null;
                    },
                  ),
                  _PreviousIntent: CallbackAction<_PreviousIntent>(
                    onInvoke: (intent) {
                      if (canNavigatePrevious) {
                        handleNavigate(-1);
                      }
                      return null;
                    },
                  ),
                  _NextIntent: CallbackAction<_NextIntent>(
                    onInvoke: (intent) {
                      if (canNavigateNext) {
                        handleNavigate(1);
                      }
                      return null;
                    },
                  ),
                },
                child: Focus(
                  autofocus: true,
                  child: Dialog(
                    insetPadding: EdgeInsets.symmetric(
                      horizontal: media.size.width > 600 ? 32 : 16,
                      vertical: media.size.height > 600 ? 24 : 16,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    backgroundColor: AppTheme.surfaceColor,
                    surfaceTintColor: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth,
                        minWidth: media.size.width > 600 ? 420 : media.size.width * 0.86,
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(contentPadding),
                        child: _buildDetailCardContent(
                          activeItem,
                          items,
                          maxWidth,
                          headerTrailing: null,
                          onPrevious: () => handleNavigate(-1),
                          onNext: () => handleNavigate(1),
                          currentIndex: currentIndex,
                          onApproveSuccess: handleApprovalSuccess,
                          showProofSection: true,
                          showTitle: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModeChip(String mode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        mode,
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailCardContent(
    Map<String, dynamic> selected,
    List<Map<String, dynamic>> items,
    double maxWidth, {
    Widget? headerTrailing,
    VoidCallback? onPrevious,
    VoidCallback? onNext,
    int? currentIndex,
    VoidCallback? onApproveSuccess,
    bool showProofSection = true,
    bool showTitle = true,
  }) {
    final bool stackVertically = maxWidth < 720;
    final imageUrl = selected['proofUrl'] as String?;
    final notes = _extractNotes(selected);
    final approvedBy = _extractApprovedBy(selected);

    final details = <Widget>[
      _buildDetailInfoRow('From', selected['from']),
      _buildDetailInfoRow('To', selected['to']),
      _buildDetailInfoRow('Mode', selected['mode']),
      _buildDetailInfoRow('Status', selected['status']),
      _buildDetailInfoRow('Created', selected['date']),
      if (approvedBy != null) _buildDetailInfoRow('Approved By', approvedBy),
      if (selected['purpose'] != null)
        _buildDetailInfoRow('Purpose', selected['purpose']),
      if (selected['customerName'] != null)
        _buildDetailInfoRow('Customer', selected['customerName']),
      if (selected['voucherNumber'] != null)
        _buildDetailInfoRow('Voucher No.', selected['voucherNumber']),
      if (selected['category'] != null)
        _buildDetailInfoRow('Category', selected['category']),
      if (selected['autoPay'] != null)
        _buildDetailInfoRow(
          'Auto Pay',
          selected['autoPay'] == true ? 'Enabled' : 'Disabled',
        ),
      if (notes != null) _buildDetailInfoRow('Notes', notes),
    ];
    final typeValue = selected['type'];
    final String typeLabel = typeValue?.toString().trim() ?? '';
    if (typeLabel.isNotEmpty) {
      details.add(_buildDetailInfoRow('Type', typeLabel));
    }
    final String fromName = (selected['from'] ?? '').toString().trim();
    final String? fromAvatarUrl = _extractFromAvatar(selected);
    final String? fromEmail = _extractFromEmail(selected);
    String? amountLabel;
    final dynamic amountValue = selected['amount'];
    if (amountValue is String) {
      final trimmed = amountValue.trim();
      if (trimmed.isNotEmpty) {
        amountLabel = trimmed;
      }
    } else if (amountValue != null) {
      amountLabel = amountValue.toString();
    }
    if (amountLabel != null && amountLabel!.toLowerCase() == 'null') {
      amountLabel = null;
    }

    final Widget? avatarWidget =
        fromName.isEmpty ? null : _buildProfileAvatar(fromName, imageUrl: fromAvatarUrl, size: 64);

    final Widget? typeChip = typeLabel.isNotEmpty
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              typeLabel,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : null;

    final Widget? proofSection = showProofSection
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Receipt / Proof',
                style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: imageUrl == null ? null : () => _copyProofUrlToClipboard(imageUrl),
                child: _buildDetailImage(imageUrl),
              ),
            ],
          )
        : null;

    final detailsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details..add(const SizedBox(height: 8)),
    );

    final bool hasMetaHeader =
        avatarWidget != null || fromName.isNotEmpty || fromEmail != null || typeChip != null || amountLabel != null;

    final List<Widget> headerChildren = [];

    if (showTitle) {
      headerChildren.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _buildRecordTitle(selected),
                style: AppTheme.headingMedium.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (headerTrailing != null) headerTrailing,
          ],
        ),
      );
    } else if (headerTrailing != null) {
      headerChildren.add(
        Align(
          alignment: Alignment.topRight,
          child: headerTrailing,
        ),
      );
    }

    if (hasMetaHeader) {
      headerChildren.add(const SizedBox(height: 16));
      headerChildren.add(
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (avatarWidget != null) ...[
                avatarWidget,
                const SizedBox(width: 14),
              ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    if (fromName.isNotEmpty)
                  Text(
                        fromName,
                      style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    if (fromEmail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          fromEmail,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                      ),
                    ),
                ],
              ),
            ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (typeChip != null) typeChip,
                  if (typeChip != null && amountLabel != null) const SizedBox(height: 12),
                  if (amountLabel != null)
                    Text(
                      amountLabel,
                      style: AppTheme.headingMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (headerChildren.isNotEmpty) {
      headerChildren.add(const SizedBox(height: 24));
    }

    final List<Widget> bodySections = [];
    if (proofSection != null) {
      bodySections.add(
        stackVertically
            ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              proofSection,
              const SizedBox(height: 24),
              detailsSection,
            ],
          )
            : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: proofSection),
              const SizedBox(width: 28),
              Expanded(
                child: SingleChildScrollView(
                  primary: false,
                  child: detailsSection,
                ),
              ),
            ],
          ),
      );
    } else {
      bodySections.add(detailsSection);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...headerChildren,
        ...bodySections,
        const SizedBox(height: 24),
        _buildDetailActionSection(
          selected,
          items,
          onPrevious: onPrevious,
          onNext: onNext,
          currentIndex: currentIndex,
          onApproveSuccess: onApproveSuccess,
        ),
      ],
    );
  }

  Widget _buildDetailImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        height: 220,
        decoration: _detailImageDecoration(),
        child: Center(
          child: Text(
            'No proof image available',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: _detailImageDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 4 / 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return Container(
                color: AppTheme.surfaceColor,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppTheme.surfaceColor,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined, color: AppTheme.errorColor),
                      const SizedBox(height: 8),
                      Text(
                        'Unable to load image',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  BoxDecoration _detailImageDecoration() {
    return BoxDecoration(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.surfaceColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Widget _buildInlineDetailSection(
    List<Map<String, dynamic>> items, {
    required bool isMobile,
  }) {
    final selected = _getSelectedItem();
    if (selected == null) {
      return const SizedBox.shrink();
    }

    final horizontalMargin = widget.embedInDashboard
        ? (isMobile ? 8.0 : 12.0)
        : (isMobile ? 16.0 : 24.0);
    final cardPadding = EdgeInsets.all(isMobile ? 16 : 24);
    final maxWidth = MediaQuery.of(context).size.width - (horizontalMargin * 2);

    return Container(
      key: ValueKey(selected['id'] ?? selected.hashCode),
      margin: EdgeInsets.fromLTRB(
        horizontalMargin,
        isMobile ? 10 : 20,
        horizontalMargin,
        isMobile ? 12 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: cardPadding,
        child: _buildDetailCardContent(
          selected,
          items,
          maxWidth,
          headerTrailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close detail view',
            onPressed: _closeDetailPanel,
          ),
          onPrevious: () => _navigateRelative(items, -1),
          onNext: () => _navigateRelative(items, 1),
          currentIndex: _selectedIndex,
        ),
      ),
    );
  }

  Widget _buildDetailInfoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(String name, {String? imageUrl, double size = 44}) {
    final String initials = _buildInitials(name);
    final BorderRadius borderRadius = BorderRadius.circular(size * 0.15);

    Widget avatarContent;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      avatarContent = ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialsAvatar(size, initials, borderRadius);
          },
        ),
      );
    } else {
      avatarContent = _buildInitialsAvatar(size, initials, borderRadius);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: avatarContent,
    );
  }

  Widget _buildInitialsAvatar(double size, String initials, BorderRadius borderRadius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.12),
        borderRadius: borderRadius,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTheme.bodyMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryDark,
          fontSize: size * 0.45,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _buildInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    final parts = trimmed.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    final first = parts.first.characters.take(1).toString();
    final last = parts.last.characters.take(1).toString();
    return (first + last).toUpperCase();
  }

  String? _extractFromAvatar(Map<String, dynamic> item) {
    final candidates = [
      item['fromAvatar'],
      item['fromAvatarUrl'],
      item['fromImage'],
      item['fromPhoto'],
      item['fromProfileImage'],
      item['fromProfilePic'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }

    final raw = item['raw'];
    if (raw is Map<String, dynamic>) {
      final nestedMaps = [
        raw['fromUser'],
        raw['createdBy'],
        raw['sender'],
        raw['user'],
        raw['owner'],
      ];
      for (final nested in nestedMaps) {
        if (nested is Map<String, dynamic>) {
          final imageUrl = ProfileImageHelper.extractImageUrl(nested);
          if (imageUrl != null) {
            return imageUrl;
          }
        } else if (nested is String && nested.trim().startsWith('http')) {
          return nested.trim();
        }
      }
    }
    return null;
  }

  String? _extractFromEmail(Map<String, dynamic> item) {
    final directCandidates = [
      item['fromEmail'],
      item['createdByEmail'],
      item['email'],
    ];
    for (final candidate in directCandidates) {
      final normalized = _normalizeEmail(candidate);
      if (normalized != null) {
        return normalized;
      }
    }

    final raw = item['raw'];
    if (raw is Map<String, dynamic>) {
      final rawCandidates = [
        raw['email'],
        raw['fromEmail'],
        raw['senderEmail'],
        raw['createdByEmail'],
        raw['contactEmail'],
        raw['userEmail'],
      ];
      for (final candidate in rawCandidates) {
        final normalized = _normalizeEmail(candidate);
        if (normalized != null) {
          return normalized;
        }
      }

      final nestedMaps = [
        raw['fromUser'],
        raw['createdBy'],
        raw['sender'],
        raw['user'],
        raw['owner'],
        raw['collectedBy'],
        raw['initiatedBy'],
        raw['userId'],
        raw['assignedReceiver'],
      ];
      for (final nested in nestedMaps) {
        if (nested is Map<String, dynamic>) {
          final normalized = _normalizeEmail(
            nested['email'] ?? nested['mail'] ?? nested['contactEmail'],
          );
          if (normalized != null) {
            return normalized;
          }
        }
      }
    }
    return null;
  }

  String _buildRecordTitle(Map<String, dynamic> item) {
    final typeLabel = (item['type'] ?? 'Record').toString();
    final identifier = _resolveRecordIdentifier(item);
    if (identifier != null && identifier.isNotEmpty) {
      return 'Detail for $typeLabel #$identifier';
    }
    return 'Detail for $typeLabel';
  }

  String? _resolveRecordIdentifier(Map<String, dynamic> item) {
    final raw = item['raw'];
    final candidates = <dynamic>[
      item['referenceId'],
      item['transactionId'],
      item['voucherNumber'],
      item['id'],
    ];
    if (raw is Map<String, dynamic>) {
      candidates.addAll([
        raw['transactionId'],
        raw['referenceId'],
        raw['referenceNumber'],
        raw['voucherNumber'],
        raw['receiptNumber'],
        raw['_id'],
        raw['id'],
      ]);
    }

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final value = candidate.toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return null;
  }

  String? _extractNotes(Map<String, dynamic> item) {
    final topLevelNotes = item['notes'];
    if (topLevelNotes is String && topLevelNotes.trim().isNotEmpty) {
      return topLevelNotes.trim();
    }

    final raw = item['raw'];
    if (raw is Map<String, dynamic>) {
      final possibleKeys = ['notes', 'note', 'comments', 'comment', 'remarks', 'description'];
      for (final key in possibleKeys) {
        final value = raw[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return null;
  }

  String? _extractApprovedBy(Map<String, dynamic> item) {
    final direct = item['approvedByName'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    final raw = item['raw'];
    if (raw is Map<String, dynamic>) {
      final candidate = raw['approvedBy'] ?? raw['approvedByName'];
      if (candidate is Map<String, dynamic>) {
        final name = candidate['name'] ?? candidate['fullName'] ?? candidate['displayName'];
        if (name is String && name.trim().isNotEmpty) {
          return name.trim();
        }
      } else if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  Future<void> _copyProofUrlToClipboard(String url) async {
    if (url.isEmpty) {
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proof link copied to clipboard'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to copy link: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _buildDetailActionSection(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> items, {
    VoidCallback? onPrevious,
    VoidCallback? onNext,
    int? currentIndex,
    VoidCallback? onApproveSuccess,
  }) {
    final actionState = _deriveDetailActionState(item);
    final String itemId = item['id']?.toString() ?? '';

    final bool allowPrevious = onPrevious != null;
    final bool allowNext = onNext != null;
    final bool canNavigatePrevious = allowPrevious &&
        (currentIndex != null ? currentIndex > 0 : _canNavigate(items, -1));
    final bool canNavigateNext = allowNext &&
        (currentIndex != null ? currentIndex < items.length - 1 : _canNavigate(items, 1));

    final navigationItemId = itemId.isEmpty ? 'navigation' : 'navigation-$itemId';

    final previousButton = _buildActionChip(
      itemId: navigationItemId,
      actionKey: 'previous',
      icon: Icons.arrow_back_ios_new,
      label: 'Previous',
      color: AppTheme.textSecondary,
      enabled: canNavigatePrevious,
      shortcutHint: '← / ↑',
      onPressed: canNavigatePrevious && onPrevious != null
          ? () async {
              onPrevious();
            }
          : null,
    );

    final actionButtons = <Widget>[
      _buildActionChip(
        itemId: itemId,
        actionKey: 'approve',
        icon: Icons.check_circle_outline,
        label: 'Approve',
        color: AppTheme.secondaryColor,
        enabled: actionState.canApprove,
        shortcutHint: 'Num1 / A',
        onPressed: actionState.canApprove
            ? () async {
                final success = await _approveItem(item);
                if (success) {
                  onApproveSuccess?.call();
                }
              }
            : null,
      ),
      _buildActionChip(
        itemId: itemId,
        actionKey: 'reject',
        icon: Icons.cancel_outlined,
        label: 'Reject',
        color: AppTheme.errorColor,
        enabled: actionState.canReject,
        shortcutHint: 'Num2 / R',
        onPressed: actionState.canReject ? () async => _rejectItem(item) : null,
      ),
      _buildActionChip(
        itemId: itemId,
        actionKey: 'flag',
        icon: Icons.flag_outlined,
        label: actionState.isFlagged ? 'Flagged' : 'Flag',
        color: Colors.orange.shade600,
        keepColorWhenDisabled: actionState.isFlagged,
        enabled: actionState.canFlag,
        shortcutHint: 'Num3 / F',
        onPressed: actionState.canFlag ? () async => _flagItem(item) : null,
      ),
      _buildActionChip(
        itemId: itemId,
        actionKey: 'edit',
        icon: Icons.edit_outlined,
        label: 'Edit',
        color: AppTheme.primaryColor,
        enabled: actionState.canEdit,
        shortcutHint: 'Num5 / E',
        onPressed: actionState.canEdit ? () async => _editItem(item) : null,
      ),
      _buildActionChip(
        itemId: itemId,
        actionKey: 'delete',
        icon: Icons.delete_outline,
        label: 'Delete',
        color: AppTheme.errorColor.withValues(alpha: 0.85),
        enabled: actionState.canDelete,
        shortcutHint: 'Num4 / D',
        onPressed: actionState.canDelete ? () async => _deleteItem(item) : null,
      ),
    ];

    Widget buildActionRow() => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < actionButtons.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                actionButtons[i],
              ],
            ],
          ),
    );

    final nextButton = _buildActionChip(
      itemId: navigationItemId,
      actionKey: 'next',
      icon: Icons.arrow_forward_ios,
      label: 'Next',
      color: AppTheme.textSecondary,
      enabled: canNavigateNext,
      iconOnLeft: false,
      shortcutHint: '→ / ↓',
      onPressed: canNavigateNext && onNext != null
          ? () async {
              onNext();
            }
          : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 640;
            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      previousButton,
                      nextButton,
                    ],
                  ),
                  const SizedBox(height: 16),
                  buildActionRow(),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: previousButton,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: buildActionRow(),
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: nextButton,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary.withValues(alpha: 0.74),
              fontWeight: FontWeight.w500,
            ),
            children: [
              TextSpan(
                text: 'Keyboard shortcuts: ',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textPrimary.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildShortcutInlineSpan('Previous', '(← / ↑)'),
              const TextSpan(text: '   •   '),
              _buildShortcutInlineSpan('Approve', '(Num1 / A)'),
              const TextSpan(text: '   •   '),
              _buildShortcutInlineSpan('Reject', '(Num2 / R)'),
              const TextSpan(text: '   •   '),
              _buildShortcutInlineSpan('Flag', '(Num3 / F)'),
              const TextSpan(text: '   •   '),
              _buildShortcutInlineSpan('Edit', '(Num5 / E)'),
              const TextSpan(text: '   •   '),
              _buildShortcutInlineSpan('Delete', '(Num4 / D)'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  InlineSpan _buildShortcutInlineSpan(String action, String keys) {
    return TextSpan(
      children: [
        TextSpan(
          text: '$action ',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textPrimary.withValues(alpha: 0.86),
            fontWeight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: keys,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary.withValues(alpha: 0.78),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  _DetailActionState _deriveDetailActionState(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'Pending').toString();
    final normalizedStatus = _normalizeStatusValue(status);
    final bool isApprovedOrAccounted = _isApprovedOrAccounted(status);
    final bool isFlagged = normalizedStatus == 'flagged';
    
    // IMPORTANT: If status is Approved or Completed, disable ALL action buttons
    // No actions should be allowed on approved/completed items in self wallet
    if (isApprovedOrAccounted) {
      return _DetailActionState(
        canApprove: false,
        canUnapprove: false, // Disable unapprove too
        canReject: false,
        canFlag: false,
        canEdit: false,
        canDelete: false,
        isFlagged: isFlagged,
      );
    }
    
    final bool canFlag = !isFlagged && !isApprovedOrAccounted;

    return _DetailActionState(
      canApprove: !isApprovedOrAccounted,
      canUnapprove: isApprovedOrAccounted,
      canReject: !isApprovedOrAccounted,
      canFlag: canFlag,
      canEdit: !isApprovedOrAccounted,
      canDelete: !isApprovedOrAccounted,
      isFlagged: isFlagged,
    );
  }

  bool _canNavigate(List<Map<String, dynamic>> items, int offset) {
    if (_selectedItemId == null) {
      return false;
    }
    final currentIndex = items.indexWhere(
      (item) => item['id']?.toString() == _selectedItemId.toString(),
    );
    if (currentIndex == -1) {
      return false;
    }
    final nextIndex = currentIndex + offset;
    return nextIndex >= 0 && nextIndex < items.length;
  }

  void _navigateRelative(List<Map<String, dynamic>> items, int offset) {
    if (!_canNavigate(items, offset)) {
      return;
    }
    final currentIndex = _selectedIndex ??
        items.indexWhere(
          (item) => item['id']?.toString() == _selectedItemId.toString(),
        );
    if (currentIndex == -1) {
      return;
    }
    final nextItem = items[currentIndex + offset];
    _selectItem(nextItem, showInline: _showDetailPanel);
  }

  void _closeDetailPanel() {
    setState(() {
      _showDetailPanel = false;
      _selectedItemId = null;
      _selectedIndex = null;
    });
  }

  void _selectItem(
    Map<String, dynamic> item, {
    bool showInline = true,
  }) {
    final itemId = item['id']?.toString();
    final filtered = _filteredItems;
    final index = itemId == null
        ? -1
        : filtered.indexWhere((entry) => entry['id']?.toString() == itemId);

    setState(() {
      _selectedItemId = itemId;
      _showDetailPanel = showInline;
      _selectedIndex = index >= 0 ? index : null;
    });
  }

  double _parseAmount(dynamic value) {
    if (value == null) {
      return 0.0;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final normalized = value.replaceAll(RegExp(r'[^0-9\.\-]'), '');
      if (normalized.isEmpty) {
        return 0.0;
      }
      return double.tryParse(normalized) ?? 0.0;
    }
    return 0.0;
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  String? _normalizeEmail(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty && trimmed.contains('@')) {
        return trimmed;
      }
    }
    return null;
  }

  Widget _buildTableActionBar({required bool isMobile}) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.end,
        children: [
          _buildBulkApproveButton(),
          _buildBulkRejectButton(),
          _buildSmartViewButton(isMobile: isMobile),
        ],
      ),
    );
  }

  Widget _buildBulkApproveButton() {
    final hasBulkSelection = _bulkSelectedIds.isNotEmpty;
    final bool canTriggerBulkApprove = hasBulkSelection && !_isBulkActionInProgress && !_isLoading;
    final String approveSelectedLabel = hasBulkSelection
        ? 'Approve Selected (${_bulkSelectedIds.length})'
        : 'Approve Selected';

    return FilledButton.icon(
      onPressed: canTriggerBulkApprove ? _approveSelectedItems : null,
      icon: _isBulkActionInProgress
          ? SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.done_all, size: 18),
      label: Text(approveSelectedLabel),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBulkRejectButton() {
    final hasBulkSelection = _bulkSelectedIds.isNotEmpty;
    final bool canTriggerBulkReject = hasBulkSelection && !_isBulkActionInProgress && !_isLoading;
    final String rejectSelectedLabel = hasBulkSelection
        ? 'Reject Selected (${_bulkSelectedIds.length})'
        : 'Reject Selected';

    return FilledButton.icon(
      onPressed: canTriggerBulkReject ? _rejectSelectedItems : null,
      icon: _isBulkActionInProgress
          ? SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.cancel_outlined, size: 18),
      label: Text(rejectSelectedLabel),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: AppTheme.errorColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<String?> _promptBulkRejectionReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Selected Records'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Rejection Reason',
              hintText: 'Enter reason for rejection...',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result?.trim();
  }

  Future<void> _openSmartView() async {
    final filtered = _filteredItems;
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Smart View is unavailable. No records found.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    Map<String, dynamic>? target;

    if (_selectedItemId != null) {
      final selectedId = _selectedItemId.toString();
      for (final item in filtered) {
        if (item['id']?.toString() == selectedId) {
          target = item;
          break;
        }
      }
    }

    if (target == null) {
      for (final item in filtered) {
        final status = _normalizeStatusValue((item['status'] ?? '').toString());
        if (status == 'flagged') {
          target = item;
          break;
        }
      }
    }

    if (target == null) {
      for (final item in filtered) {
        final status = _normalizeStatusValue((item['status'] ?? '').toString());
        if (status == 'pending') {
          target = item;
          break;
        }
      }
    }

    target ??= filtered.first;
    await _showDetailDialog(filtered, target);
  }

  Widget _buildSmartViewButton({required bool isMobile}) {
    return ElevatedButton.icon(
      onPressed: _openSmartView,
      icon: const Icon(Icons.auto_awesome_outlined, size: 18),
      label: Text(
        'Smart View',
        style: AppTheme.labelMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: isMobile ? 10 : 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 2.5,
      ),
    );
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        return DateTime.parse(value.trim());
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _formatDateLabel(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final dateStr = DateFormat('dd MMM yyyy').format(dateTime);
    final timeStr = DateFormat('hh:mm a').format(dateTime);
    return '$dateStr\n$timeStr';
  }

  String _normalizeMode(dynamic mode) {
    if (mode is String && mode.trim().isNotEmpty) {
      return mode.trim();
    }
    if (mode is Map<String, dynamic>) {
      final possibleKeys = ['name', 'label', 'mode', 'type'];
      for (final key in possibleKeys) {
        final value = mode[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return 'N/A';
  }

  /// Normalize expense status - convert "Unaccounted" to "Unapprove" for expenses
  /// This ensures expenses show "Unapprove" instead of "Unaccounted" status
  String _normalizeExpenseStatus(String status) {
    final normalized = status.trim();
    // Convert "Unaccounted" to "Unapprove" for expenses
    if (normalized.toLowerCase() == 'unaccounted') {
      return 'Unapprove';
    }
    return normalized;
  }

  String? _extractProofUrl(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final candidates = [
        payload['proofUrl'],
        payload['receiptUrl'],
        payload['proof'],
        payload['documentUrl'],
        payload['attachmentUrl'],
        payload['imageUrl'],
      ];
      for (final candidate in candidates) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          return _resolveMediaUrl(candidate.trim());
        }
      }
      final attachments = payload['attachments'];
      if (attachments is List && attachments.isNotEmpty) {
        final first = attachments.first;
        if (first is String && first.trim().isNotEmpty) {
          return _resolveMediaUrl(first.trim());
        }
        if (first is Map<String, dynamic>) {
          final url = first['url'] ?? first['path'];
          if (url is String && url.trim().isNotEmpty) {
            return _resolveMediaUrl(url.trim());
          }
        }
      }
    } else if (payload is String && payload.trim().isNotEmpty) {
      return _resolveMediaUrl(payload.trim());
    }
    return null;
  }

  String? _resolveMediaUrl(String url) {
    if (url.isEmpty) return null;
    if (url.startsWith('http')) {
      return url;
    }
    final baseUri = Uri.parse(ApiConstants.baseUrl);
    final origin = '${baseUri.scheme}://${baseUri.authority}';
    if (url.startsWith('/')) {
      return '$origin$url';
    }
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    return '$origin$basePath/$url';
  }

  Map<String, dynamic> _formatCollection(dynamic collection) {
    final collectedBy = collection['collectedBy'];
    final isSystemCollection = collection['isSystemCollection'] == true || collectedBy == null;
    final isSystematicEntry = collection['isSystematicEntry'] == true || collection['collectionType'] == 'systematic';
    
    // Get 'from' field (collector name) - fallback to collectedBy if from is not set
    final fromField = collection['from'];
    final fromName = fromField is Map 
        ? (fromField['name'] ?? 'Unknown')
        : (collectedBy is Map ? (collectedBy['name'] ?? 'Unknown') : 'Unknown');
    
    // Created by: System if system collection or systematic entry, otherwise collector
    final createdByName = (isSystemCollection || isSystematicEntry)
        ? 'System' 
        : (collectedBy is Map ? (collectedBy['name'] ?? 'Unknown') : 'Unknown');
    
    final collectedByUserId = collectedBy is Map ? (collectedBy['_id'] ?? collectedBy['id']) : collectedBy;
    final collectedByRole = collectedBy is Map ? (collectedBy['role'] ?? '') : '';
    final collectedByEmail = collectedBy is Map ? _normalizeEmail(collectedBy['email'] ?? collectedBy['mail']) : null;
    final receiver = collection['assignedReceiver'];
    final receiverUserId = receiver is Map ? (receiver['_id'] ?? receiver['id']) : receiver;
    final amountValue = _parseAmount(collection['amount']);
    final createdAt = _parseDateTime(collection['createdAt'] ?? collection['date']);
    final proofUrl = _extractProofUrl(collection);
    final approvedBy = collection['approvedBy'];
    final approvedByName = approvedBy is Map
        ? (approvedBy['name'] ?? approvedBy['fullName'] ?? approvedBy['displayName'])
        : (approvedBy is String ? approvedBy : null);
    final paymentMode = collection['paymentModeId'] ?? collection['paymentMode'];
    final autoPay = paymentMode is Map ? (paymentMode['autoPay'] ?? false) : false;
    
    return {
      'id': collection['_id'] ?? collection['id'],
      'type': 'Collections',
      'from': fromName, // From field (collector name)
      'fromId': collectedByUserId,
      'fromRole': collectedByRole,
      'fromEmail': collectedByEmail,
      'createdByName': createdByName, // Created by (System or collector)
      'to': receiver is Map ? (receiver['name'] ?? 'Unknown') : 'Unknown',
      'toId': receiverUserId,
      'amount': _formatCurrency(amountValue),
      'amountValue': amountValue,
      'mode': _normalizeMode(collection['mode']),
      'purpose': collection['customerName'] ?? 'Customer Payment',
      'date': _formatDateLabel(createdAt),
      'createdAt': createdAt,
      'autoPay': autoPay,
      'customerName': collection['customerName'],
      'voucherNumber': collection['voucherNumber'],
      'status': collection['status'] ?? 'Pending',
      'createdBySuperAdmin': isSystemCollection ? false : (collectedByRole == 'SuperAdmin'),
      'isReceiver': _currentUserId != null && receiverUserId != null && 
                    receiverUserId.toString() == _currentUserId.toString(),
      'isCreator': _currentUserId != null && collectedByUserId != null && 
                   collectedByUserId.toString() == _currentUserId.toString(),
      'approvedByName': approvedByName,
      'proofUrl': proofUrl,
      'raw': collection,
    };
  }

  Map<String, dynamic> _formatTransaction(dynamic transaction) {
    final initiatedBy = transaction['initiatedBy'];
    final initiatedByRole = initiatedBy is Map ? (initiatedBy['role'] ?? '') : '';
    final receiver = transaction['receiver'];
    final receiverUserId = receiver is Map ? (receiver['_id'] ?? receiver['id']) : receiver;
    final sender = transaction['sender'];
    final senderUserId = sender is Map ? (sender['_id'] ?? sender['id']) : sender;
    final senderEmail = sender is Map ? _normalizeEmail(sender['email'] ?? sender['mail']) : null;
    final amountValue = _parseAmount(transaction['amount']);
    final createdAt = _parseDateTime(transaction['createdAt'] ?? transaction['date']);
    final proofUrl = _extractProofUrl(transaction);
    final approvedBy = transaction['approvedBy'];
    final approvedByName = approvedBy is Map
        ? (approvedBy['name'] ?? approvedBy['fullName'] ?? approvedBy['displayName'])
        : (approvedBy is String ? approvedBy : null);
    
    return {
      'id': transaction['_id'] ?? transaction['id'],
      'type': 'Transactions',
      'from': sender is Map ? (sender['name'] ?? 'Unknown') : 'Unknown',
      'fromId': senderUserId,
      'fromEmail': senderEmail,
      'to': receiver is Map ? (receiver['name'] ?? 'Unknown') : 'Unknown',
      'toId': receiverUserId,
      'amount': _formatCurrency(amountValue),
      'amountValue': amountValue,
      'mode': _normalizeMode(transaction['mode']),
      'purpose': transaction['purpose'] ?? 'Transfer',
      'date': _formatDateLabel(createdAt),
      'createdAt': createdAt,
      'status': transaction['status'] ?? 'Pending',
      'createdBySuperAdmin': initiatedByRole == 'SuperAdmin',
      'createdByName': initiatedBy is Map ? (initiatedBy['name'] ?? 'Unknown') : 'Unknown',
      'isReceiver': _currentUserId != null && receiverUserId != null && 
                    receiverUserId.toString() == _currentUserId.toString(),
      'approvedByName': approvedByName,
      'proofUrl': proofUrl,
      'raw': transaction,
    };
  }

  Map<String, dynamic> _formatExpense(dynamic expense) {
    final createdBy = expense['createdBy'];
    final expenseUser = expense['userId'];
    final createdByUserId = createdBy is Map ? (createdBy['_id'] ?? createdBy['id']) : createdBy;
    final createdByRole = createdBy is Map ? (createdBy['role'] ?? '') : '';
    final createdByEmail = createdBy is Map
        ? _normalizeEmail(createdBy['email'] ?? createdBy['mail'])
        : (expenseUser is Map ? _normalizeEmail(expenseUser['email'] ?? expenseUser['mail']) : null);
    final expenseUserId = expenseUser is Map ? (expenseUser['_id'] ?? expenseUser['id']) : expenseUser;
    final amountValue = _parseAmount(expense['amount']);
    final createdAt = _parseDateTime(expense['createdAt'] ?? expense['date']);
    final proofUrl = _extractProofUrl(expense);
    final approvedBy = expense['approvedBy'];
    final approvedByName = approvedBy is Map
        ? (approvedBy['name'] ?? approvedBy['fullName'] ?? approvedBy['displayName'])
        : (approvedBy is String ? approvedBy : null);
    
    final createdByName = createdBy is Map
        ? (createdBy['name'] ?? 'Unknown')
        : (expenseUser is Map ? (expenseUser['name'] ?? 'Unknown') : 'Unknown');
    
    // For Expenses, show expense category in "to" field instead of user name
    final expenseCategory = expense['category'] ?? expense['expenseType'] ?? 'Misc';
    final expenseCategoryName = expenseCategory.toString().trim();
    
    // For Purpose field, show expense category/type (e.g., "Travel", "Tea") instead of description
    // This makes it clear what type of expense it is
    final purposeText = expenseCategoryName.isNotEmpty ? expenseCategoryName : 'Expense';
    
    return {
      'id': expense['_id'] ?? expense['id'],
      'type': 'Expenses',
      'from': createdByName,
      'fromId': createdByUserId,
      'fromRole': createdByRole,
      'fromEmail': createdByEmail,
      'to': expenseCategoryName,
      'toId': expenseUserId,
      'amount': _formatCurrency(amountValue),
      'amountValue': amountValue,
      'mode': _normalizeMode(expense['mode']),
      'purpose': purposeText,
      'date': _formatDateLabel(createdAt),
      'createdAt': createdAt,
      'category': expenseCategory.toString(),
      // For Expenses: Convert "Unaccounted" status to "Unapprove" for display
      'status': _normalizeExpenseStatus(expense['status'] ?? 'Pending'),
      'createdBySuperAdmin': createdByRole == 'SuperAdmin',
      'createdByName': createdByName,
      'isReceiver': _currentUserId != null && expenseUserId != null && 
                    expenseUserId.toString() == _currentUserId.toString(),
      'approvedByName': approvedByName,
      'proofUrl': proofUrl,
      'raw': expense,
    };
  }

  List<Map<String, dynamic>> _applyFiltersTo(
    List<Map<String, dynamic>> source, {
    required String typeFilter,
    required String statusFilter,
    required String modeFilter,
    Set<String>? statusShortcuts,
  }) {
    Iterable<Map<String, dynamic>> items = source;

    final isAdminOrSuperAdmin = _currentUserRole == 'Admin' || _currentUserRole == 'SuperAdmin';

    // For Smart Approvals: Users with smart_approvals permission should see ALL pending items
    // Skip the restrictive filtering for these users
    if (_hasSmartApprovalsPermission) {
      // User has Smart Approvals permission - show all items without filtering by receiver
      // This allows them to see and approve all pending items
      print('✅ [SMART APPROVALS] User has smart_approvals permission - showing all items');
    } else if (isAdminOrSuperAdmin) {
      // For Admin/SuperAdmin: Show items NOT created by SuperAdmin
      // BUT also show Expenses created by SuperAdmin (they need to approve expenses for other users)
      // AND also show Collections created by SuperAdmin (they need to approve collections)
      items = items.where((item) {
        final itemType = (item['type'] ?? '').toString();
        final createdBySuperAdmin = item['createdBySuperAdmin'] == true;
        
        // Always show Expenses, even if created by SuperAdmin
        if (itemType == 'Expenses') {
          return true;
        }
        
        // Always show Collections, even if created by SuperAdmin (they need approval)
        if (itemType == 'Collections') {
          return true;
        }
        
        // For Transactions, exclude those created by SuperAdmin
        return createdBySuperAdmin != true;
      });
    } else {
      // For regular users without Smart Approvals permission: Only show items where they are the receiver
      items = items.where(
        (item) => item['createdBySuperAdmin'] == true && item['isReceiver'] == true,
      );
    }

    final Set<String> effectiveShortcuts = statusShortcuts ?? const <String>{};

    if (typeFilter != _allFilterValue) {
      items = items.where((item) => (item['type'] ?? '').toString() == typeFilter);
    }
    if (effectiveShortcuts.isNotEmpty) {
      final normalizedShortcuts = effectiveShortcuts
          .map((status) => status.toLowerCase().trim())
          .toSet();
      items = items.where((item) {
        final itemStatus = (item['status'] ?? '').toString().toLowerCase().trim();
        final itemType = (item['type'] ?? '').toString();
        
        // For Collections, "Unaccounted" status should match "Pending" filter
        if (itemType == 'Collections' && normalizedShortcuts.contains('pending')) {
          return itemStatus == 'pending' || itemStatus == 'unaccounted';
        }
        
        // For Expenses, "Unapprove" status should match "Pending" filter
        if (itemType == 'Expenses' && normalizedShortcuts.contains('pending')) {
          return itemStatus == 'pending' || itemStatus == 'unapprove' || itemStatus == 'unaccounted';
        }
        
        // Check if status matches any of the shortcuts
        final matches = normalizedShortcuts.contains(itemStatus);
        
        // Debug logging for Flagged filter
        if (normalizedShortcuts.contains('flagged')) {
          print('🔍 [FLAGGED FILTER] Checking item: type=$itemType, status=$itemStatus, matches=$matches');
        }
        
        return matches;
      });
    } else if (statusFilter != _allFilterValue) {
      items = items.where((item) {
        final itemStatus = (item['status'] ?? '').toString();
        final itemType = (item['type'] ?? '').toString();
        
        // For Collections, "Unaccounted" status should match "Pending" filter
        if (itemType == 'Collections' && statusFilter == 'Pending') {
          return itemStatus == 'Pending' || itemStatus == 'Unaccounted';
        }
        
        // For Expenses, "Unapprove" status should match "Pending" filter
        if (itemType == 'Expenses' && statusFilter == 'Pending') {
          return itemStatus == 'Pending' || itemStatus == 'Unapprove' || itemStatus == 'Unaccounted';
        }
        
        return itemStatus == statusFilter;
      });
    }
    if (modeFilter != _allFilterValue) {
      items = items.where((item) => (item['mode'] ?? '').toString() == modeFilter);
    }

    final filteredList = items.toList();
    
    // Debug logging for Smart Approvals filtering
    if (_hasSmartApprovalsPermission) {
      print('\n🔍 [SMART APPROVALS] Filtering Results:');
      print('   Items before filtering: ${source.length}');
      print('   Items after filtering: ${filteredList.length}');
      print('   Status Filter: $statusFilter');
      print('   Status Shortcuts: $statusShortcuts');
      print('   Type Filter: $typeFilter');
      print('   Mode Filter: $modeFilter');
      if (filteredList.isEmpty && source.isNotEmpty) {
        print('   ⚠️  WARNING: Items were filtered out!');
      }
      print('=====================================\n');
    }
    
    return filteredList;
  }

  List<Map<String, dynamic>> get _filteredItems => _applyFiltersTo(
        _pendingItems,
        typeFilter: _selectedType,
        statusFilter: _selectedStatus,
        modeFilter: _selectedMode,
        statusShortcuts: _activeStatusShortcuts,
      );

  bool get _isUsingDefaultFilters =>
      _selectedType == _allFilterValue &&
      _selectedStatus == _allFilterValue &&
      _selectedMode == _allFilterValue &&
      _activeStatusShortcuts.length == 1 &&
      _activeStatusShortcuts.contains(_defaultStatusShortcut);

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final filteredItems = _filteredItems;
    final hasSelection = _selectedItemId != null &&
        filteredItems.any((item) => item['id'] == _selectedItemId);
    final detailVisible = _showDetailPanel && hasSelection;

    final listSection = _buildTable(
      filteredItems,
      isMobile: isMobile,
    );

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (filteredItems.isEmpty) {
      body = _buildEmptyState();
    } else {
      body = listSection;
    }

    final detailSection = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: detailVisible
          ? _buildInlineDetailSection(filteredItems, isMobile: isMobile)
          : const SizedBox.shrink(),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilterToolbar(
          isMobile: isMobile,
          isTablet: isTablet,
          itemCount: filteredItems.length,
        ),
        detailSection,
        Expanded(child: body),
      ],
    );

    if (widget.embedInDashboard) {
      final availableHeight = MediaQuery.of(context).size.height -
          (MediaQuery.of(context).padding.top + kToolbarHeight);
      return SizedBox(
        height: availableHeight,
        child: content,
      );
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
        title: const Text('Smart Approvals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final navigator = Navigator.of(context);
              try {
                await AuthService.logout();
              } catch (e) {
                // Ignore errors and continue with logout flow
              }
              if (!mounted) return;
              navigator.pushReplacementNamed('/login');
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildStatusBadge(String status) {
    Color chipColor;
    
    if (status == 'Completed' || status == 'Approved') {
      chipColor = AppTheme.secondaryColor;
    } else if (status == 'Pending') {
      chipColor = AppTheme.warningColor;
    } else if (status == 'Rejected') {
      chipColor = AppTheme.errorColor;
    } else if (status == 'Flagged') {
      chipColor = AppTheme.warningColor;
    } else {
      chipColor = AppTheme.textSecondary;
    }

    return Text(
      status,
      style: AppTheme.bodySmall.copyWith(
        color: chipColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildActions(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'Pending').toString();
    final normalizedStatus = _normalizeStatusValue(status);
    final bool isApproved = normalizedStatus == 'approved' || normalizedStatus == 'completed';
    final bool isRejected = normalizedStatus == 'rejected';
    final bool isFlagged = normalizedStatus == 'flagged';
    final bool isAccounted = normalizedStatus == 'accounted';
    final String itemId = item['id']?.toString() ?? '';
    
    // Get item type (Transactions, Collections, Expenses)
    final itemType = (item['type'] ?? '').toString().toLowerCase();
    final String permissionPrefix;
    if (itemType == 'transactions') {
      permissionPrefix = 'transaction';
    } else if (itemType == 'collections') {
      permissionPrefix = 'collection';
    } else if (itemType == 'expenses') {
      permissionPrefix = 'expense';
    } else {
      permissionPrefix = 'transaction'; // Default fallback
    }
    
    // Check if user is the creator (for collections, creator can only delete)
    final bool isCreator = item['isCreator'] == true;
    final bool isReceiver = item['isReceiver'] == true;
    
    // For Collections: If user is creator, they can only delete (not approve/reject/flag)
    // Assigned Receiver (if different from creator) can do all actions
    final bool isReceiverButNotCreator = isReceiver && !isCreator;
    
    // Check permissions for each action
    final bool hasApprovePermission = _actionPermissions['$permissionPrefix.approve'] ?? false;
    final bool hasRejectPermission = _actionPermissions['$permissionPrefix.reject'] ?? false;
    final bool hasFlagPermission = _actionPermissions['$permissionPrefix.flag'] ?? false;
    final bool hasEditPermission = _actionPermissions['$permissionPrefix.edit'] ?? false;
    final bool hasDeletePermission = _actionPermissions['$permissionPrefix.delete'] ?? false;
    
    // IMPORTANT: If status is Approved or Completed, disable ALL action buttons
    // No actions should be allowed on approved/completed items in self wallet
    if (isApproved || normalizedStatus == 'completed') {
      // All buttons disabled when approved/completed
      final buttons = <Widget>[];
      return SizedBox(
        height: 40,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: buttons,
          ),
        ),
      );
    }
    
    // For Collections: Creator can only delete, not approve/reject/flag
    // Assigned Receiver (if different from creator) can do all actions
    // For Transactions: Only the receiver can approve
    // For other types: Use normal permission checks
    final bool canApprove = itemType == 'collections'
        ? (!isCreator && (isReceiverButNotCreator || hasApprovePermission) && !isApproved && !isAccounted && !_isBulkActionInProgress)
        : itemType == 'transactions'
            ? (isReceiver && !isApproved && !isAccounted && !_isBulkActionInProgress)
            : (hasApprovePermission && !isApproved && !isAccounted && !_isBulkActionInProgress);
    final bool canReject = itemType == 'collections'
        ? (!isCreator && (isReceiverButNotCreator || hasRejectPermission) && !isRejected)
        : (hasRejectPermission && !isRejected);
    final bool canFlag = itemType == 'collections'
        ? (!isCreator && (isReceiverButNotCreator || hasFlagPermission) && !isFlagged)
        : (hasFlagPermission && !isFlagged);
    final bool canUnapprove = itemType == 'collections'
        ? (!isCreator && (isReceiverButNotCreator || hasApprovePermission) && (isApproved || normalizedStatus == 'accounted'))
        : (hasApprovePermission && (isApproved || normalizedStatus == 'accounted'));
    final bool canEdit = hasEditPermission && !isApproved && !isAccounted;
    // Creator can delete their own collections (if status allows)
    final bool canDelete = itemType == 'collections'
        ? ((isCreator || hasDeletePermission || isReceiverButNotCreator) && !isApproved && !isAccounted)
        : (hasDeletePermission && !isApproved && !isAccounted);

    final buttons = <Widget>[
      _buildTableActionButton(
        itemId: itemId,
        actionKey: 'approve',
        icon: Icons.check_circle_outline,
        tooltip: 'Approve',
        color: Colors.green.shade600,
        enabled: canApprove,
        onPressed: canApprove
            ? () async {
                await _approveItem(item);
              }
            : null,
      ),
      _buildTableActionButton(
        itemId: itemId,
        actionKey: 'unapprove',
        icon: Icons.undo,
        tooltip: 'Unapprove',
        color: Colors.orange.shade600,
        enabled: canUnapprove,
        onPressed: canUnapprove ? () async => _handleUnapprove(item) : null,
      ),
      _buildTableActionButton(
        itemId: itemId,
        actionKey: 'reject',
        icon: Icons.cancel_outlined,
        tooltip: 'Reject',
        color: Colors.red.shade600,
        enabled: canReject,
        onPressed: canReject ? () async => _rejectItem(item) : null,
      ),
      _buildTableActionButton(
        itemId: itemId,
        actionKey: 'flag',
        icon: Icons.flag_outlined,
        tooltip: 'Flag',
        color: Colors.orange.shade600,
        enabled: canFlag,
        onPressed: canFlag ? () async => _flagItem(item) : null,
      ),
      _buildTableActionButton(
        itemId: itemId,
        actionKey: 'edit',
        icon: Icons.edit_outlined,
        tooltip: 'Edit',
        color: Colors.indigo.shade500,
        enabled: canEdit,
        onPressed: canEdit ? () async => _editItem(item) : null,
      ),
      _buildTableActionButton(
        itemId: itemId,
        actionKey: 'delete',
        icon: Icons.delete_outline,
        tooltip: 'Delete',
        color: Colors.red.shade600,
        enabled: canDelete,
        onPressed: canDelete ? () async => _deleteItem(item) : null,
      ),
    ];

    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
        for (int i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
              buttons[i],
            ],
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Collections':
        return AppTheme.secondaryColor;
      case 'Transactions':
        return AppTheme.primaryColor;
      case 'Expenses':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  Future<Map<String, dynamic>> _executeApprovalRequest({
    required String id,
    required String type,
  }) async {
    if (type == 'Collections') {
      return await CollectionService.approveCollection(id);
    }
    if (type == 'Transactions') {
      return await TransactionService.approveTransaction(id);
    }
    if (type == 'Expenses') {
      return await ExpenseService.approveExpense(id);
    }
    return {
      'success': false,
      'message': 'Unsupported approval type: $type',
    };
  }

  Future<Map<String, dynamic>> _executeRejectionRequest({
    required String id,
    required String type,
    String? reason,
  }) async {
    final String? rejectionReason = (reason == null || reason.isEmpty) ? null : reason;
    if (type == 'Collections') {
      return await CollectionService.rejectCollection(id, rejectionReason);
    }
    if (type == 'Transactions') {
      return await TransactionService.rejectTransaction(id, rejectionReason);
    }
    if (type == 'Expenses') {
      return await ExpenseService.rejectExpense(id, rejectionReason);
    }
    return {
      'success': false,
      'message': 'Unsupported rejection type: $type',
    };
  }

  Future<void> _approveSelectedItems() async {
    if (_bulkSelectedIds.isEmpty || _isBulkActionInProgress) {
      return;
    }

    setState(() {
      _isBulkActionInProgress = true;
    });

    final selectedItems = _pendingItems.where((item) {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) {
        return false;
      }
      return _bulkSelectedIds.contains(id) && _canApproveItem(item);
    }).toList();

    if (selectedItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No eligible records selected for approval'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _isBulkActionInProgress = false;
        });
      }
      return;
    }

    final List<String> approvedIds = [];
    final Map<String, String> failedMessages = {};

    for (final item in selectedItems) {
      final id = item['id']?.toString() ?? '';
      final type = item['type']?.toString() ?? '';
      if (id.isEmpty || type.isEmpty) {
        failedMessages[id.isEmpty ? 'unknown' : id] = 'Missing identifier or type';
        continue;
      }

      try {
        final result = await _executeApprovalRequest(id: id, type: type);
        if (result['success'] == true) {
          approvedIds.add(id);
        } else {
          final message = result['message']?.toString() ?? 'Approval failed';
          failedMessages[id] = message;
        }
      } catch (e) {
        failedMessages[id] = e.toString().replaceFirst('Exception: ', '');
      }
    }

    if (!mounted) {
      return;
    }

    if (approvedIds.isNotEmpty) {
      final successMessage = approvedIds.length == 1
          ? '1 record approved successfully'
          : '${approvedIds.length} records approved successfully';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    }

    if (failedMessages.isNotEmpty) {
      final failureCount = failedMessages.length;
      final firstMessage = failedMessages.values.first;
      final failureMessage = failureCount == 1
          ? firstMessage
          : '$failureCount records failed. Latest error: $firstMessage';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failureMessage),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }

    final failureIds = failedMessages.keys.where((id) => id != 'unknown').toSet();

    setState(() {
      _isBulkActionInProgress = false;
      _bulkSelectedIds.removeAll(approvedIds);
    });

    if (approvedIds.isNotEmpty) {
      await _loadPendingItems();
      if (mounted && failureIds.isNotEmpty) {
        final availableIds = _pendingItems
            .map((entry) => entry['id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet();
        final idsToRestore = failureIds.where(availableIds.contains).toSet();
        if (idsToRestore.isNotEmpty) {
          setState(() {
            _bulkSelectedIds.addAll(idsToRestore);
          });
        }
      }
    }
  }

  Future<void> _rejectSelectedItems() async {
    if (_bulkSelectedIds.isEmpty || _isBulkActionInProgress) {
      return;
    }

    final selectedItems = _pendingItems.where((item) {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) {
        return false;
      }
      return _bulkSelectedIds.contains(id) && _canRejectItem(item);
    }).toList();

    if (selectedItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No eligible records selected for rejection'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
      return;
    }

    final String? rejectionReason = await _promptBulkRejectionReason();
    if (rejectionReason == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isBulkActionInProgress = true;
    });

    final List<String> rejectedIds = [];
    final Map<String, String> failedMessages = {};

    for (final item in selectedItems) {
      final id = item['id']?.toString() ?? '';
      final type = item['type']?.toString() ?? '';
      if (id.isEmpty || type.isEmpty) {
        failedMessages[id.isEmpty ? 'unknown' : id] = 'Missing identifier or type';
        continue;
      }

      try {
        final result = await _executeRejectionRequest(
          id: id,
          type: type,
          reason: rejectionReason,
        );
        if (result['success'] == true) {
          rejectedIds.add(id);
        } else {
          final message = result['message']?.toString() ?? 'Rejection failed';
          failedMessages[id] = message;
        }
      } catch (e) {
        failedMessages[id] = e.toString().replaceFirst('Exception: ', '');
      }
    }

    if (!mounted) {
      return;
    }

    if (rejectedIds.isNotEmpty) {
      final successMessage = rejectedIds.length == 1
          ? '1 record rejected successfully'
          : '${rejectedIds.length} records rejected successfully';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }

    if (failedMessages.isNotEmpty) {
      final failureCount = failedMessages.length;
      final firstMessage = failedMessages.values.first;
      final failureMessage = failureCount == 1
          ? firstMessage
          : '$failureCount records failed. Latest error: $firstMessage';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failureMessage),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }

    final failureIds = failedMessages.keys.where((id) => id != 'unknown').toSet();

    setState(() {
      _isBulkActionInProgress = false;
      _bulkSelectedIds.removeAll(rejectedIds);
    });

    if (rejectedIds.isNotEmpty) {
      await _loadPendingItems();
      if (mounted && failureIds.isNotEmpty) {
        final availableIds = _pendingItems
            .map((entry) => entry['id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet();
        final idsToRestore = failureIds.where(availableIds.contains).toSet();
        if (idsToRestore.isNotEmpty) {
          setState(() {
            _bulkSelectedIds.addAll(idsToRestore);
          });
        }
      }
    }
  }

  Future<bool> _approveItem(Map<String, dynamic> item) async {
    final String id = item['id']?.toString() ?? '';
    final String type = item['type']?.toString() ?? '';
    if (id.isEmpty || type.isEmpty) {
      return false;
    }

    final List<Map<String, dynamic>> filteredBefore = List<Map<String, dynamic>>.from(_filteredItems);
    final bool keepDetailVisible = _showDetailPanel;
    final String? nextItemId = _resolveNextItemId(filteredBefore, id);

    _setActionInProgress(id, 'approve');

    try {
      final result = await _executeApprovalRequest(id: id, type: type);

      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _bulkSelectedIds.remove(id);
            _applyLocalApprovalState(id);
          });
          _focusNextItemAfterApproval(
            nextItemId: nextItemId,
            keepDetailVisible: keepDetailVisible,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '${item['type']} approved successfully'),
              backgroundColor: AppTheme.secondaryColor,
            ),
          );
          // Auto-refresh the list after successful approval
          if (mounted) {
            await _loadPendingItems();
          }
          return true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to approve ${item['type']}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return false;
    } finally {
      _clearActionInProgress();
    }
    return false;
  }

  void _applyLocalApprovalState(String approvedId) {
    final int index = _pendingItems.indexWhere(
      (entry) => entry['id']?.toString() == approvedId,
    );
    if (index == -1) {
      return;
    }

    final Map<String, dynamic> updatedItem = _pendingItems.removeAt(index);
    updatedItem['status'] = 'Approved';
    final rawPayload = updatedItem['raw'];
    if (rawPayload is Map<String, dynamic>) {
      rawPayload['status'] = 'Approved';
    }
    _pendingItems.add(updatedItem);
  }

  String? _resolveNextItemId(List<Map<String, dynamic>> items, String approvedId) {
    if (items.isEmpty) {
      return null;
    }
    final int currentIndex = items.indexWhere(
      (entry) => entry['id']?.toString() == approvedId,
    );
    if (currentIndex == -1) {
      return null;
    }
    if (currentIndex + 1 < items.length) {
      final nextItem = items[currentIndex + 1];
      final dynamic nextId = nextItem['id'];
      if (nextId != null && nextId.toString().isNotEmpty) {
        return nextId.toString();
      }
    }
    return null;
  }

  void _focusNextItemAfterApproval({
    required String? nextItemId,
    required bool keepDetailVisible,
  }) {
    if (!mounted) {
      return;
    }

    if (nextItemId == null) {
      if (keepDetailVisible) {
        _closeDetailPanel();
      } else {
        setState(() {
          _selectedItemId = null;
          _selectedIndex = null;
        });
      }
      return;
    }

    final filteredItems = _filteredItems;
    for (final entry in filteredItems) {
      if (entry['id']?.toString() == nextItemId) {
        _selectItem(entry, showInline: keepDetailVisible);
        return;
      }
    }

    if (keepDetailVisible) {
      _closeDetailPanel();
    } else {
      setState(() {
        _selectedItemId = null;
        _selectedIndex = null;
      });
    }
  }

  void _rejectItem(Map<String, dynamic> item) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject ${item['type']}'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'Enter reason for rejection...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _rejectItemConfirmed(item, reasonController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectItemConfirmed(Map<String, dynamic> item, String reason) async {
    try {
      final String id = item['id']?.toString() ?? '';
      final String type = item['type']?.toString() ?? '';
      if (id.isEmpty || type.isEmpty) {
        return;
      }

      _setActionInProgress(id, 'reject');
      
      Map<String, dynamic> result;
      if (type == 'Collections') {
        result = await CollectionService.rejectCollection(id, reason.isEmpty ? null : reason);
      } else if (type == 'Transactions') {
        result = await TransactionService.rejectTransaction(id, reason.isEmpty ? null : reason);
      } else if (type == 'Expenses') {
        result = await ExpenseService.rejectExpense(id, reason.isEmpty ? null : reason);
      } else {
        return;
      }

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '${item['type']} rejected'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          _loadPendingItems(); // Refresh list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to reject ${item['type']}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      _clearActionInProgress();
    }
  }

  void _flagItem(Map<String, dynamic> item) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flag for Review'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Flag Reason',
            hintText: 'Enter reason for flagging...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _flagItemConfirmed(item, reasonController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor),
            child: const Text('Flag'),
          ),
        ],
      ),
    );
  }

  Future<void> _flagItemConfirmed(Map<String, dynamic> item, String reason) async {
    if (reason.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide a flag reason'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    try {
      final String id = item['id']?.toString() ?? '';
      final String type = item['type']?.toString() ?? '';
      if (id.isEmpty || type.isEmpty) {
        return;
      }

      _setActionInProgress(id, 'flag');
      
      Map<String, dynamic> result;
      if (type == 'Collections') {
        result = await CollectionService.flagCollection(id, reason);
      } else if (type == 'Transactions') {
        result = await TransactionService.flagTransaction(id, reason);
      } else if (type == 'Expenses') {
        result = await ExpenseService.flagExpense(id, reason);
      } else {
        return;
      }

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '${item['type']} flagged for review'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
          _loadPendingItems(); // Refresh list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to flag ${item['type']}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      _clearActionInProgress();
    }
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final dynamic idValue = item['id'];
    final String id = idValue?.toString()?.trim() ?? '';
    final String type = item['type']?.toString() ?? '';
    
    // Validate ID - check for null, empty, or invalid values
    if (id.isEmpty || 
        id == 'null' || 
        id == 'undefined' || 
        type.isEmpty ||
        idValue == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot edit item: Invalid or missing ID'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    final edits = await _showEditDialog(item);
    if (!mounted || edits == null) {
      return;
    }

    double? parseAmount(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String && value.trim().isNotEmpty) {
        return double.tryParse(value.trim());
      }
      return null;
    }

    String? sanitizeString(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return value.toString();
    }

    _setActionInProgress(id, 'edit');

    try {
      Map<String, dynamic> result;
      if (type == 'Collections') {
        final String? notesValue = edits['notes'] as String?;
        result = await CollectionService.editCollection(
          id,
          customerName: sanitizeString(edits['customerName']),
          amount: parseAmount(edits['amount']),
          mode: sanitizeString(edits['mode']),
          notes: notesValue?.trim(),
        );
      } else if (type == 'Transactions') {
        final String? proofValue = edits['proofUrl'] as String?;
        result = await TransactionService.editTransaction(
          id,
          amount: parseAmount(edits['amount']),
          mode: sanitizeString(edits['mode']),
          purpose: sanitizeString(edits['purpose']),
          proofUrl: proofValue?.trim(),
        );
      } else if (type == 'Expenses') {
        final String? descriptionValue = edits['description'] as String?;
        final String? proofValue = edits['proofUrl'] as String?;
        result = await ExpenseService.updateExpense(
          id,
          category: sanitizeString(edits['category']),
          amount: parseAmount(edits['amount']),
          mode: sanitizeString(edits['mode']),
          description: descriptionValue?.trim(),
          proofUrl: proofValue?.trim(),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Edit not supported for item type $type'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '$type updated successfully'),
              backgroundColor: AppTheme.secondaryColor,
            ),
          );
          await _loadPendingItems();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to update $type'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      _clearActionInProgress();
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final String id = item['id']?.toString() ?? '';
    final String type = item['type']?.toString() ?? '';
    if (id.isEmpty || type.isEmpty) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $type'),
        content: Text('Are you sure you want to delete this $type entry? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    _setActionInProgress(id, 'delete');

    try {
      Map<String, dynamic> result;
      if (type == 'Collections') {
        result = await CollectionService.deleteCollection(id);
      } else if (type == 'Transactions') {
        result = await TransactionService.deleteTransaction(id);
      } else if (type == 'Expenses') {
        result = await ExpenseService.deleteExpense(id);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete not supported for item type $type'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '$type deleted successfully'),
              backgroundColor: AppTheme.secondaryColor,
            ),
          );
          await _loadPendingItems();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to delete $type'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      _clearActionInProgress();
    }
  }

  Future<Map<String, dynamic>?> _showEditDialog(Map<String, dynamic> item) async {
    final String type = item['type']?.toString() ?? '';
    if (type.isEmpty) {
      return null;
    }

    final raw = item['raw'] is Map
        ? Map<String, dynamic>.from(item['raw'] as Map)
        : <String, dynamic>{};
    final amountValue = item['amountValue'] is num ? (item['amountValue'] as num).toDouble() : null;
    final amountController = TextEditingController(
      text: amountValue != null ? amountValue.toString() : '',
    );
    final modeController = TextEditingController(text: item['mode']?.toString() ?? '');
    final notesController = TextEditingController(text: raw['notes']?.toString() ?? '');
    final customerNameController = TextEditingController(
      text: raw['customerName']?.toString() ?? item['purpose']?.toString() ?? '',
    );
    final purposeController = TextEditingController(text: raw['purpose']?.toString() ?? item['purpose']?.toString() ?? '');
    final proofController = TextEditingController(text: raw['proofUrl']?.toString() ?? '');
    final categoryController = TextEditingController(text: raw['category']?.toString() ?? '');
    final descriptionController = TextEditingController(text: raw['description']?.toString() ?? '');

    final formKey = GlobalKey<FormState>();

    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          final List<Widget> fields = [];
          final Set<String> modeSuggestions = {
            ..._defaultModeSuggestions,
            if (item['mode'] != null && item['mode'].toString().trim().isNotEmpty)
              item['mode'].toString().trim(),
            ..._availableModes.where((value) => value != _allFilterValue),
          }..removeWhere((value) => value.trim().isEmpty);
          final List<String> sortedModeSuggestions = modeSuggestions.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          fields.add(
            TextFormField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter amount';
                }
                final parsed = double.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
          );

          fields.add(const SizedBox(height: 12));
          fields.add(
            TextFormField(
              controller: modeController,
              decoration: InputDecoration(
                labelText: 'Mode',
                suffixIcon: sortedModeSuggestions.isEmpty
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: 'Select mode',
                        itemBuilder: (context) => sortedModeSuggestions
                            .map(
                              (option) => PopupMenuItem<String>(
                                value: option,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        option,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_autoPayModes.contains(option)) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'AutoPay',
                                          style: AppTheme.bodySmall.copyWith(
                                            fontSize: 11,
                                            letterSpacing: 0.3,
                                            color: AppTheme.secondaryColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onSelected: (value) {
                          modeController.text = value;
                        },
                        icon: const Icon(Icons.unfold_more),
                      ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter mode';
                }
                return null;
              },
            ),
          );

          if (type == 'Collections') {
            fields.add(const SizedBox(height: 12));
            fields.add(
              TextFormField(
                controller: customerNameController,
                decoration: const InputDecoration(labelText: 'Customer Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter customer name';
                  }
                  return null;
                },
              ),
            );

            fields.add(const SizedBox(height: 12));
            fields.add(
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 2,
              ),
            );
          } else if (type == 'Transactions') {
            fields.add(const SizedBox(height: 12));
            fields.add(
              TextFormField(
                controller: purposeController,
                decoration: const InputDecoration(labelText: 'Purpose'),
                maxLines: 2,
              ),
            );

            fields.add(const SizedBox(height: 12));
            fields.add(
              TextFormField(
                controller: proofController,
                decoration: const InputDecoration(labelText: 'Proof URL (optional)'),
              ),
            );
          } else if (type == 'Expenses') {
            fields.add(const SizedBox(height: 12));
            fields.add(
              TextFormField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter category';
                  }
                  return null;
                },
              ),
            );

            fields.add(const SizedBox(height: 12));
            fields.add(
              TextFormField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
              ),
            );

            fields.add(const SizedBox(height: 12));
            fields.add(
              TextFormField(
                controller: proofController,
                decoration: const InputDecoration(labelText: 'Proof URL (optional)'),
              ),
            );
          }

          return AlertDialog(
            title: Text('Edit $type'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: fields,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }

                  final result = <String, dynamic>{
                    'amount': amountController.text.trim(),
                    'mode': modeController.text.trim(),
                  };

                  if (type == 'Collections') {
                    result['customerName'] = customerNameController.text.trim();
                    result['notes'] = notesController.text.trim();
                  } else if (type == 'Transactions') {
                    result['purpose'] = purposeController.text.trim();
                    result['proofUrl'] = proofController.text.trim();
                  } else if (type == 'Expenses') {
                    result['category'] = categoryController.text.trim();
                    result['description'] = descriptionController.text;
                    result['proofUrl'] = proofController.text.trim();
                  }

                  Navigator.of(dialogContext).pop(result);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    } finally {
      amountController.dispose();
      modeController.dispose();
      notesController.dispose();
      customerNameController.dispose();
      purposeController.dispose();
      proofController.dispose();
      categoryController.dispose();
      descriptionController.dispose();
    }
  }

  Widget _buildActionChip({
    required String itemId,
    required String actionKey,
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
    required Future<void> Function()? onPressed,
    bool keepColorWhenDisabled = false,
    bool iconOnLeft = true,
    String? trailingLabel,
    String? shortcutHint,
  }) {
    final bool busy = _isActionInProgress(itemId, actionKey);
    final bool isEnabled = enabled && onPressed != null;

    final bool shouldUseColor = isEnabled || (keepColorWhenDisabled && !busy);
    final Color foregroundColor = shouldUseColor
        ? color
        : AppTheme.textSecondary.withValues(alpha: 0.55);
    final BorderRadius borderRadius = BorderRadius.circular(12);

    final Widget chip = Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: !isEnabled || busy
            ? null
            : () async {
                await onPressed!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Opacity(
            opacity: (!isEnabled || busy) && !keepColorWhenDisabled ? 0.4 : 1.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: () {
                final textWidgets = <Widget>[
                  Text(
                    label,
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: foregroundColor,
                    ),
                  ),
                  if (trailingLabel != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      trailingLabel,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: foregroundColor,
                      ),
                    ),
                  ],
                ];

                final iconWidget = busy
                    ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                    ),
                  )
                    : Icon(
                    icon,
                    size: 18,
                    color: foregroundColor,
                      );

                if (iconOnLeft) {
                  return [
                    iconWidget,
                const SizedBox(width: 6),
                    ...textWidgets,
                  ];
                }

                return [
                  ...textWidgets,
                  const SizedBox(width: 6),
                  iconWidget,
                ];
              }(),
            ),
          ),
        ),
      ),
    );

    return chip;
  }

  Widget _buildTableActionButton({
    required String itemId,
    required String actionKey,
    required IconData icon,
    required String tooltip,
    required Color color,
    required bool enabled,
    required Future<void> Function()? onPressed,
  }) {
    final bool busy = _isActionInProgress(itemId, actionKey);
    final bool canTap = enabled && onPressed != null && !busy;
    final Color iconColor = canTap || (busy && enabled)
        ? color
        : AppTheme.textSecondary.withValues(alpha: 0.4);

    return IconButton(
      tooltip: tooltip,
      onPressed: canTap
          ? () async {
              await onPressed!();
            }
          : null,
      iconSize: 20,
      splashRadius: 22,
      icon: busy
          ? SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              ),
            )
          : Icon(icon, color: iconColor),
    );
  }
}

class _DetailActionState {
  const _DetailActionState({
    required this.canApprove,
    required this.canUnapprove,
    required this.canReject,
    required this.canFlag,
    required this.canEdit,
    required this.canDelete,
    required this.isFlagged,
  });

  final bool canApprove;
  final bool canUnapprove;
  final bool canReject;
  final bool canFlag;
  final bool canEdit;
  final bool canDelete;
  final bool isFlagged;
}