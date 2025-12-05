import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../utils/file_download_helper.dart';
import '../../services/transaction_service.dart';
import '../../services/collection_service.dart';
import '../../services/expense_service.dart';
import '../../services/expense_type_service.dart';
import '../../services/report_service.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatelessWidget {
  final bool embedInDashboard;
  const ReportsScreen({super.key, this.embedInDashboard = false});

  @override
  Widget build(BuildContext context) {
    return _ReportsScreenContent(embedInDashboard: embedInDashboard);
  }
}

class _ReportsScreenContent extends StatefulWidget {
  final bool embedInDashboard;
  const _ReportsScreenContent({this.embedInDashboard = false});

  @override
  State<_ReportsScreenContent> createState() => _ReportsScreenContentState();
}

class _ReportsScreenContentState extends State<_ReportsScreenContent> {
  String? _selectedInitiatedBy;
  String? _selectedTransferTo;
  String? _selectedPurpose;
  String? _selectedMode;
  String? _selectedType;
  String? _selectedCollectionType;
  String? _selectedStatus;
  String? _selectedCategory; // NEW: Expense category filter
  DateTime? _fromDate;
  DateTime? _toDate;
  
  bool _isLoading = true;
  bool _isReceivingRealtimeUpdate = false; // NEW: Realtime update indicator
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _expenseTypes = []; // NEW: Expense types list
  
  // Summary data
  double _totalInflow = 0.0;
  double _totalOutflow = 0.0;
  double _totalExpenses = 0.0;
  double _filteredExpenseBalance = 0.0; // NEW: Filtered expense balance
  int _pendingApprovals = 0;

  // Saved reports
  List<Map<String, dynamic>> _savedReports = [];
  bool _isLoadingSavedReports = false;
  
  // Auto-refresh configuration
  Timer? _autoRefreshTimer;
  static const Duration _autoRefreshInterval = Duration(seconds: 30); // Refresh every 30 seconds
  static const Duration _debounceRefreshDelay = Duration(seconds: 2); // Debounce to prevent rapid refreshes
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    // Set default to current day
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, now.day);
    _toDate = DateTime(now.year, now.month, now.day);
    _loadData();
    _loadUsers();
    _loadExpenseTypes(); // NEW: Load expense types
    _setupSocketListeners();
    _loadSavedReports();
    
    // Start auto-refresh timer
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    // Clean up socket listeners
    SocketService.offExpenseReportStatsUpdate();
    SocketService.offExpenseReportUpdate();
    SocketService.offExpenseUpdate();
    super.dispose();
  }

  /// Setup socket listeners for real-time report updates
  void _setupSocketListeners() async {
    // Check if user is SuperAdmin
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');
      
      if (userRole == 'SuperAdmin') {
        // Listen for lightweight stats updates (triggers refresh)
        SocketService.onExpenseReportStatsUpdate((data) {
          if (mounted) {
            print('🔄 Refreshing report due to stats update');
            _autoRefreshReport();
          }
        });

        // Listen for full report updates (optional - for future use)
        SocketService.onExpenseReportUpdate((data) {
          if (mounted) {
            print('🔄 Refreshing report due to full update');
            _autoRefreshReport();
          }
        });

        // Listen for individual expense updates (triggers refresh)
        SocketService.onExpenseUpdate((data) {
          if (mounted) {
            print('🔄 Refreshing report due to expense update: ${data['event']}');
            _autoRefreshReport();
          }
        });
      }
    } catch (e) {
      print('Error setting up socket listeners: $e');
    }
  }

  /// Auto-refresh method with debouncing to prevent excessive API calls
  /// This method ensures expense report data is refreshed when changes occur
  void _autoRefreshReport() {
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
    
    // Show real-time update indicator
    setState(() {
      _isReceivingRealtimeUpdate = true;
    });
    
    // Refresh expense report data
    _loadData().then((_) {
      if (mounted) {
        setState(() {
          _isReceivingRealtimeUpdate = false;
        });
      }
    });
  }

  /// Start the auto-refresh timer
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _autoRefreshReport();
    });
  }

  /// Stop the auto-refresh timer
  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> _loadUsers() async {
    try {
      final result = await UserService.getUsers();
      if (result['success'] == true && mounted) {
        final users = result['users'] as List<dynamic>? ?? [];
        // Filter for active users only (isVerified == true)
        final activeUsers = users.where((u) {
          final isVerified = u['isVerified'] ?? false;
          return isVerified == true;
        }).toList();
        setState(() {
          _users = activeUsers.map((u) => {
            'id': u['_id'] ?? u['id'],
            'name': u['name'] ?? 'Unknown',
            'role': u['role'] ?? 'Staff',
          }).toList();
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  /// Load expense types for category filter
  Future<void> _loadExpenseTypes() async {
    try {
      final result = await ExpenseTypeService.getExpenseTypes();
      if (result['success'] == true && mounted) {
        final expenseTypes = result['expenseTypes'] as List<dynamic>? ?? [];
        setState(() {
          _expenseTypes = expenseTypes
              .where((et) => et['isActive'] == true)
              .map((et) => Map<String, dynamic>.from(et))
              .toList();
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Format dates for API
      final fromDateStr = _fromDate != null 
          ? DateFormat('yyyy-MM-dd').format(_fromDate!)
          : null;
      final toDateStr = _toDate != null
          ? DateFormat('yyyy-MM-dd').format(_toDate!)
          : null;

      // Use unified report endpoint
      final reportResult = await ReportService.getReports(
        startDate: fromDateStr,
        endDate: toDateStr,
        mode: _selectedMode == 'All' || _selectedMode == null ? null : _selectedMode,
        status: _selectedStatus == 'All' || _selectedStatus == null ? null : _selectedStatus,
        category: _selectedCategory == 'All' || _selectedCategory == null ? null : _selectedCategory,
      );

      if (mounted && reportResult['success'] == true) {
        final report = reportResult['report'] as Map<String, dynamic>? ?? {};
        
        // Extract data from report
        final transactionsData = report['transactions'] as Map<String, dynamic>? ?? {};
        final collectionsData = report['collections'] as Map<String, dynamic>? ?? {};
        final expensesData = report['expenses'] as Map<String, dynamic>? ?? {};
        
        final transactions = transactionsData['data'] as List<dynamic>? ?? [];
        final collections = collectionsData['data'] as List<dynamic>? ?? [];
        final expenses = expensesData['data'] as List<dynamic>? ?? [];

        // Combine all into unified table
        final allData = <Map<String, dynamic>>[];
        
        // Add transactions
        for (var tx in transactions) {
          allData.add(_formatTransaction(tx));
        }
        
        // Add collections
        for (var col in collections) {
          allData.add(_formatCollection(col));
        }
        
        // Add expenses
        for (var exp in expenses) {
          allData.add(_formatExpense(exp));
        }

        // Get summary from API if available
        final summary = report['summary'] as Map<String, dynamic>?;
        final collectionsTotal = (collectionsData['total'] as num?)?.toDouble() ?? 0.0;
        final expensesTotal = (expensesData['total'] as num?)?.toDouble() ?? 0.0;
        final transactionsTotal = (transactionsData['total'] as num?)?.toDouble() ?? 0.0;

        // Calculate summary from report data or use API summary
        double totalInflow = 0.0;
        double totalOutflow = 0.0;
        double totalExpenses = 0.0;
        int pendingApprovals = 0;

        // Use API summary if available (includes cash in/out)
        if (summary != null) {
          totalInflow = (summary['cashIn'] as num?)?.toDouble() ?? 0.0;
          totalOutflow = (summary['cashOut'] as num?)?.toDouble() ?? 0.0;
          totalExpenses = (summary['totalExpenses'] as num?)?.toDouble() ?? expensesTotal;
        } else {
          // Fallback: calculate manually
          for (var item in allData) {
            final amount = item['amountValue'] as double? ?? 0.0;
            final type = item['type'] as String? ?? '';
            final status = item['status'] as String? ?? '';

            if (status == 'Pending' || status == 'Flagged') {
              pendingApprovals++;
            }

            if (type == 'Collection' && (status == 'Verified' || status == 'Approved')) {
              totalInflow += amount;
            } else if (type == 'Expense' && (status == 'Approved' || status == 'Completed')) {
              totalExpenses += amount;
              totalOutflow += amount;
            } else if (type == 'Transfer' && (status == 'Approved' || status == 'Completed')) {
              totalOutflow += amount;
            }
          }
        }

        // Calculate filtered expense balance if category filter is applied
        double filteredExpenseBalance = 0.0;
        if (_selectedCategory != null && _selectedCategory != 'All') {
          for (var item in allData) {
            if (item['type'] == 'Expense' && item['category'] == _selectedCategory) {
              filteredExpenseBalance += item['amountValue'] as double? ?? 0.0;
            }
          }
        } else {
          filteredExpenseBalance = totalExpenses;
        }

        setState(() {
          _allTransactions = allData;
          _totalInflow = totalInflow;
          _totalOutflow = totalOutflow;
          _totalExpenses = totalExpenses;
          _filteredExpenseBalance = filteredExpenseBalance;
          _pendingApprovals = pendingApprovals;
          _isLoading = false;
        });
      } else {
        // Fallback to old method if report endpoint fails
        if (mounted) {
          await _loadDataFallback();
        }
      }
    } catch (e) {
      print('Error loading report data: $e');
      // Fallback to old method on error
      if (mounted) {
        await _loadDataFallback();
      }
    }
  }

  /// Fallback method using separate service calls (old method)
  Future<void> _loadDataFallback() async {
    try {
      // Format dates for API
      final fromDateStr = _fromDate != null 
          ? DateFormat('yyyy-MM-dd').format(_fromDate!)
          : null;
      final toDateStr = _toDate != null
          ? DateFormat('yyyy-MM-dd').format(_toDate!)
          : null;

      // Load all data in parallel
      final results = await Future.wait([
        TransactionService.getTransactions(
          status: _selectedStatus == 'All' || _selectedStatus == null ? null : _selectedStatus,
          mode: _selectedMode == 'All' || _selectedMode == null ? null : _selectedMode,
        ),
        CollectionService.getCollections(
          status: _selectedStatus == 'All' || _selectedStatus == null ? null : _selectedStatus,
          mode: _selectedMode == 'All' || _selectedMode == null ? null : _selectedMode,
          startDate: fromDateStr,
          endDate: toDateStr,
        ),
        ExpenseService.getExpenses(
          status: _selectedStatus == 'All' || _selectedStatus == null ? null : _selectedStatus,
          mode: _selectedMode == 'All' || _selectedMode == null ? null : _selectedMode,
        ),
      ]);

      if (mounted) {
        final transactions = results[0]['transactions'] as List<dynamic>? ?? [];
        final collections = results[1]['collections'] as List<dynamic>? ?? [];
        final expenses = results[2]['expenses'] as List<dynamic>? ?? [];

        // Combine all into unified table
        final allData = <Map<String, dynamic>>[];
        
        // Add transactions
        for (var tx in transactions) {
          allData.add(_formatTransaction(tx));
        }
        
        // Add collections
        for (var col in collections) {
          allData.add(_formatCollection(col));
        }
        
        // Add expenses
        for (var exp in expenses) {
          allData.add(_formatExpense(exp));
        }

        // Calculate summary
        double totalInflow = 0.0;
        double totalOutflow = 0.0;
        double totalExpenses = 0.0;
        int pendingApprovals = 0;

        for (var item in allData) {
          final amount = item['amountValue'] as double? ?? 0.0;
          final type = item['type'] as String? ?? '';
          final status = item['status'] as String? ?? '';

          if (status == 'Pending' || status == 'Flagged') {
            pendingApprovals++;
          }

          if (type == 'Collection') {
            totalInflow += amount;
          } else if (type == 'Transfer') {
            totalOutflow += amount;
          } else if (type == 'Expense') {
            totalExpenses += amount;
            totalOutflow += amount;
          }
        }

        setState(() {
          _allTransactions = allData;
          _totalInflow = totalInflow;
          _totalOutflow = totalOutflow;
          _totalExpenses = totalExpenses;
          _pendingApprovals = pendingApprovals;
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

  Map<String, dynamic> _formatTransaction(dynamic tx) {
    final date = tx['createdAt'] != null 
        ? DateTime.parse(tx['createdAt']).toLocal()
        : DateTime.now();
    
    return {
      'id': tx['_id'] ?? tx['id'],
      'date': DateFormat('dd-MMM-yyyy').format(date),
      'dateTime': date,
      'time': DateFormat('hh:mm a').format(date),
      'initiatedBy': tx['initiatedBy'] != null 
          ? '${tx['initiatedBy']['name'] ?? 'Unknown'} (${tx['initiatedBy']['role'] ?? 'Staff'})'
          : 'Unknown',
      'sender': tx['sender'] != null 
          ? '${tx['sender']['name'] ?? 'Unknown'} (${tx['sender']['role'] ?? 'Staff'})'
          : 'Unknown',
      'receiver': tx['receiver'] != null 
          ? '${tx['receiver']['name'] ?? 'Unknown'} (${tx['receiver']['role'] ?? 'Staff'})'
          : 'Unknown',
      'transferTo': tx['receiver'] != null 
          ? '${tx['receiver']['name'] ?? 'Unknown'}'
          : 'Unknown',
      'purpose': tx['purpose'] ?? 'N/A',
      'description': tx['purpose'] ?? 'N/A',
      'type': 'Transfer',
      'collectionType': null,
      'mode': tx['mode'] ?? 'Unknown',
      'amount': '₹${_formatAmount((tx['amount'] ?? 0).toDouble())}',
      'amountValue': (tx['amount'] ?? 0).toDouble(),
      'status': tx['status'] ?? 'Pending',
      'autoPay': false,
    };
  }

  Map<String, dynamic> _formatCollection(dynamic col) {
    final date = col['createdAt'] != null 
        ? DateTime.parse(col['createdAt']).toLocal()
        : DateTime.now();
    
    // Check if this is a system collection (created by System)
    final isSystemCollection = col['isSystemCollection'] == true || col['collectedBy'] == null;
    
    // Get 'from' field (collector name) - fallback to collectedBy if from is not set
    final fromField = col['from'];
    final fromName = fromField != null && fromField is Map
        ? (fromField['name'] ?? 'Unknown')
        : (col['collectedBy'] != null ? (col['collectedBy']['name'] ?? 'Unknown') : 'Unknown');
    final fromRole = fromField != null && fromField is Map
        ? (fromField['role'] ?? 'Staff')
        : (col['collectedBy'] != null ? (col['collectedBy']['role'] ?? 'Staff') : 'Staff');
    
    // Created by: System if system collection, otherwise collector
    final createdByName = isSystemCollection 
        ? 'System'
        : (col['collectedBy'] != null ? (col['collectedBy']['name'] ?? 'Unknown') : 'Unknown');
    final createdByRole = isSystemCollection 
        ? 'System'
        : (col['collectedBy'] != null ? (col['collectedBy']['role'] ?? 'Staff') : 'Staff');
    
    return {
      'id': col['_id'] ?? col['id'],
      'date': DateFormat('dd-MMM-yyyy').format(date),
      'dateTime': date,
      'time': DateFormat('hh:mm a').format(date),
      'initiatedBy': '$createdByName ($createdByRole)',
      'sender': '$fromName ($fromRole)', // From field (collector)
      'receiver': col['assignedReceiver'] != null 
          ? '${col['assignedReceiver']['name'] ?? 'Unknown'} (${col['assignedReceiver']['role'] ?? 'Staff'})'
          : 'Unknown',
      'transferTo': col['assignedReceiver'] != null 
          ? '${col['assignedReceiver']['name'] ?? 'Unknown'}'
          : 'Unknown',
      'purpose': col['customerName'] ?? col['description'] ?? 'N/A',
      'description': col['description'] ?? col['customerName'] ?? 'N/A',
      'type': 'Collection',
      'collectionType': col['paymentMode']?['autoPay'] == true ? 'Auto' : (col['mode'] == 'Cash' ? 'Cash' : 'UPI-Bank'),
      'mode': col['mode'] ?? 'Unknown',
      'amount': '₹${_formatAmount((col['amount'] ?? 0).toDouble())}',
      'amountValue': (col['amount'] ?? 0).toDouble(),
      'status': col['status'] ?? 'Pending',
      'autoPay': col['paymentMode']?['autoPay'] ?? false,
      'voucherNo': col['voucherNo'],
      'customerName': col['customerName'],
    };
  }

  Map<String, dynamic> _formatExpense(dynamic exp) {
    final date = exp['createdAt'] != null 
        ? DateTime.parse(exp['createdAt']).toLocal()
        : DateTime.now();
    
    return {
      'id': exp['_id'] ?? exp['id'],
      'date': DateFormat('dd-MMM-yyyy').format(date),
      'dateTime': date,
      'time': DateFormat('hh:mm a').format(date),
      'initiatedBy': exp['userId'] != null 
          ? '${exp['userId']['name'] ?? 'Unknown'} (${exp['userId']['role'] ?? 'Staff'})'
          : 'Unknown',
      'sender': exp['userId'] != null 
          ? '${exp['userId']['name'] ?? 'Unknown'} (${exp['userId']['role'] ?? 'Staff'})'
          : 'Unknown',
      'receiver': 'N/A',
      'transferTo': 'N/A',
      'purpose': exp['description'] ?? 'N/A',
      'description': exp['description'] ?? 'N/A',
      'type': 'Expense',
      'category': exp['category'] ?? 'N/A', // NEW: Include category
      'collectionType': null,
      'mode': exp['mode'] ?? 'Unknown',
      'amount': '₹${_formatAmount((exp['amount'] ?? 0).toDouble())}',
      'amountValue': (exp['amount'] ?? 0).toDouble(),
      'status': exp['status'] ?? 'Pending',
      'autoPay': false,
    };
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// Collect current filters into a map
  Map<String, dynamic> _collectCurrentFilters() {
    return {
      'startDate': _fromDate != null 
          ? DateFormat('yyyy-MM-dd').format(_fromDate!)
          : null,
      'endDate': _toDate != null
          ? DateFormat('yyyy-MM-dd').format(_toDate!)
          : null,
      'mode': _selectedMode == 'All' || _selectedMode == null ? null : _selectedMode,
      'status': _selectedStatus == 'All' || _selectedStatus == null ? null : _selectedStatus,
      'type': _selectedType == 'All' || _selectedType == null ? null : _selectedType,
      'category': _selectedCategory == 'All' || _selectedCategory == null ? null : _selectedCategory,
      'initiatedBy': _selectedInitiatedBy,
      'transferTo': _selectedTransferTo,
      'purpose': _selectedPurpose,
      'collectionType': _selectedCollectionType,
    };
  }

  /// Save current report
  Future<void> _saveCurrentReport({String? reportName, bool includeFullData = false, bool isTemplate = false}) async {
    try {
      // Auto-generate report name if not provided
      final name = reportName ?? _generateReportName();
      
      final filters = _collectCurrentFilters();
      
      final result = await ReportService.saveReport(
        reportName: name,
        filters: filters,
        includeFullData: includeFullData,
        isTemplate: isTemplate,
      );

      if (mounted && result['success'] == true) {
        // Refresh saved reports list
        await _loadSavedReports();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Report saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to save report'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Generate report name from current filters
  String _generateReportName() {
    final parts = <String>[];
    
    if (_fromDate != null && _toDate != null) {
      final start = DateFormat('MMM yyyy').format(_fromDate!);
      final end = DateFormat('MMM yyyy').format(_toDate!);
      if (start == end) {
        parts.add(start);
      } else {
        parts.add('$start - $end');
      }
    }
    
    if (_selectedMode != null && _selectedMode != 'All') {
      parts.add(_selectedMode!);
    }
    
    if (_selectedStatus != null && _selectedStatus != 'All') {
      parts.add(_selectedStatus!);
    }
    
    return parts.isEmpty 
        ? 'Expense Report - ${DateFormat('dd MMM yyyy').format(DateTime.now())}'
        : 'Expense Report - ${parts.join(' ')}';
  }

  /// Load saved reports list
  Future<void> _loadSavedReports() async {
    if (_isLoadingSavedReports) return;
    
    setState(() {
      _isLoadingSavedReports = true;
    });

    try {
      final result = await ReportService.getSavedReports();
      
      if (mounted && result['success'] == true) {
        setState(() {
          _savedReports = (result['reports'] as List<dynamic>?)
              ?.map((r) => Map<String, dynamic>.from(r))
              .toList() ?? [];
          _isLoadingSavedReports = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingSavedReports = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSavedReports = false;
        });
      }
    }
  }

  /// Load a saved report and apply its filters
  Future<void> _loadSavedReport(Map<String, dynamic> savedReport) async {
    try {
      final filters = savedReport['filters'] as Map<String, dynamic>? ?? {};
      
      setState(() {
        // Apply date filters
        if (filters['startDate'] != null) {
          try {
            _fromDate = DateTime.parse(filters['startDate']);
          } catch (e) {
            _fromDate = null;
          }
        }
        
        if (filters['endDate'] != null) {
          try {
            _toDate = DateTime.parse(filters['endDate']);
          } catch (e) {
            _toDate = null;
          }
        }
        
        // Apply other filters
        _selectedMode = filters['mode'] ?? 'All';
        _selectedStatus = filters['status'] ?? 'All';
        _selectedType = filters['type'] ?? 'All';
        _selectedCategory = filters['category'] ?? 'All';
        _selectedInitiatedBy = filters['initiatedBy'];
        _selectedTransferTo = filters['transferTo'];
        _selectedPurpose = filters['purpose'];
        _selectedCollectionType = filters['collectionType'];
      });
      
      // Reload data with new filters
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report "${savedReport['reportName'] ?? 'Unknown'}" loaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Get saved reports (public method for external access)
  List<Map<String, dynamic>> getSavedReports() => _savedReports;

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _extractTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  // Filter transactions based on selected filters
  List<Map<String, dynamic>> get _filteredTransactions {
    return _allTransactions.where((transaction) {
      // Date filter
      if (_fromDate != null || _toDate != null) {
        final transactionDate = transaction['dateTime'] as DateTime;
        final transDate = DateTime(transactionDate.year, transactionDate.month, transactionDate.day);
        
        if (_fromDate != null) {
          final fromDate = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
          if (transDate.isBefore(fromDate)) return false;
        }
        
        if (_toDate != null) {
          final toDate = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);
          if (transDate.isAfter(toDate)) return false;
        }
      }

      // Initiated By filter
      if (_selectedInitiatedBy != null) {
        if (_selectedInitiatedBy == 'All') {
          // Show all if "All" is selected
        } else if (transaction['initiatedBy'] != _selectedInitiatedBy) {
          return false;
        }
      }

      // Transfer To filter
      if (_selectedTransferTo != null) {
        if (_selectedTransferTo == 'All') {
          // Show all if "All" is selected
        } else if (!transaction['transferTo'].toString().contains(_selectedTransferTo!)) {
          return false;
        }
      }

      // Purpose filter
      if (_selectedPurpose != null) {
        if (_selectedPurpose == 'All') {
          // Show all if "All" is selected
        } else if (transaction['purpose'] != _selectedPurpose) {
          return false;
        }
      }

      // Mode filter
      if (_selectedMode != null) {
        if (_selectedMode == 'All') {
          // Show all if "All" is selected
        } else if (transaction['mode'] != _selectedMode) {
          return false;
        }
      }

      // Type filter
      if (_selectedType != null) {
        if (_selectedType == 'All') {
          // Show all if "All" is selected
        } else if (transaction['type'] != _selectedType) {
          return false;
        }
      }

      // Collection Type filter
      if (_selectedCollectionType != null) {
        if (_selectedCollectionType == 'All') {
          // Show all if "All" is selected
        } else if (transaction['collectionType'] != _selectedCollectionType) {
          return false;
        }
      }

      // Status filter
      if (_selectedStatus != null) {
        if (_selectedStatus == 'All') {
          // Show all if "All" is selected
        } else if (transaction['status'] != _selectedStatus) {
          return false;
        }
      }

      // Category filter (for expenses)
      if (_selectedCategory != null) {
        if (_selectedCategory == 'All') {
          // Show all if "All" is selected
        } else if (transaction['type'] == 'Expense' && transaction['category'] != _selectedCategory) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<String> get _initiatedByOptions {
    final options = ['All'];
    for (var user in _users) {
      options.add('${user['name']} (${user['role']})');
    }
    return options;
  }
  
  List<String> get _transferToOptions {
    final options = ['All'];
    for (var user in _users) {
      options.add(user['name']);
    }
    return options;
  }
  final List<String> _purposeOptions = ['All', 'Customer Payment', 'Travel Advance', 'Office Supplies', 'Salary', 'Other'];
  final List<String> _modes = ['All', 'Cash', 'UPI', 'Bank'];
  final List<String> _types = ['All', 'Transfer', 'Collection', 'Expense'];
  final List<String> _collectionTypes = ['All', 'Cash', 'UPI-Bank', 'Auto'];
  final List<String> _statuses = ['All', 'Approved', 'Pending', 'Rejected'];
  
  /// Get expense category options
  List<String> get _categoryOptions {
    final options = ['All'];
    for (var type in _expenseTypes) {
      final name = type['name'] as String?;
      if (name != null && name.isNotEmpty) {
        options.add(name);
      }
    }
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final content = SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Filter Panel
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text('FILTER PANEL', style: AppTheme.headingSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    )),
                    const Spacer(),
                    if (_isReceivingRealtimeUpdate)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondaryColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Updating...',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // Row 1: Initiated By, Transfer To, Purpose
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        'Initiated By',
                        _selectedInitiatedBy,
                        _initiatedByOptions,
                        (value) {
                          setState(() {
                            _selectedInitiatedBy = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown(
                        'Transfer To',
                        _selectedTransferTo,
                        _transferToOptions,
                        (value) {
                          setState(() {
                            _selectedTransferTo = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown(
                        'Purpose',
                        _selectedPurpose,
                        _purposeOptions,
                        (value) {
                          setState(() {
                            _selectedPurpose = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 2: Mode, Type
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        'Mode',
                        _selectedMode,
                        _modes,
                        (value) {
                          setState(() {
                            _selectedMode = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown(
                        'Type',
                        _selectedType,
                        _types,
                        (value) {
                          setState(() {
                            _selectedType = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 3: Collection Type, Expense Category
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        'Collection Type',
                        _selectedCollectionType,
                        _collectionTypes,
                        (value) {
                          setState(() {
                            _selectedCollectionType = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown(
                        'Expense Category',
                        _selectedCategory,
                        _categoryOptions,
                        (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 4: Status
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        'Status',
                        _selectedStatus,
                        _statuses,
                        (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 5: Date Range
                Row(
                  children: [
                    Expanded(
                      child: _buildDateFilter(
                        'From Date',
                        _fromDate,
                        (date) {
                          setState(() {
                            _fromDate = date;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('–', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateFilter(
                        'To Date',
                        _toDate,
                        (date) {
                          setState(() {
                            _toDate = date;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _applyFilters(context),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Apply Filters'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _clearFilters(context),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset Filters'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: _buildSummaryCards(context),
          ),
          _buildReportTable(context),
        ],
      ),
    );

    if (widget.embedInDashboard) {
      return content;
    }
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/super-admin-dashboard');
            }
          },
        ),
        title: const Text('Reports & Analytics'),
        actions: [
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
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text('Select $label'),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Select $label',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDateFilter(
    String label,
    DateTime? date,
    ValueChanged<DateTime?> onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          suffixIcon: const Icon(Icons.calendar_today),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Text(
          date != null
              ? '${date.day}/${date.month}/${date.year}'
              : '//__',
          style: TextStyle(
            color: date != null ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final crossAxisCount = isMobile ? 2 : 4;
    final netBalance = _totalInflow - _totalOutflow;

    final cards = [
      _buildSummaryCard('Cash In', '₹${_formatAmount(_totalInflow)}', Icons.trending_up, AppTheme.secondaryColor),
      _buildSummaryCard('Cash Out', '₹${_formatAmount(_totalOutflow)}', Icons.trending_down, AppTheme.errorColor),
      _buildSummaryCard('Net Balance', '₹${_formatAmount(netBalance)}', Icons.account_balance, AppTheme.primaryColor),
      _buildSummaryCard('Total Expenses', '₹${_formatAmount(_totalExpenses)}', Icons.receipt_long, AppTheme.warningColor),
    ];

    // Add filtered expense balance card if category filter is applied
    if (_selectedCategory != null && _selectedCategory != 'All') {
      cards.add(_buildSummaryCard('Filtered Expenses', '₹${_formatAmount(_filteredExpenseBalance)}', Icons.filter_list, Colors.purple));
    }

    // Add pending approvals card
    cards.add(_buildSummaryCard('Pending Approvals', '$_pendingApprovals', Icons.hourglass_bottom, Colors.orange));

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isMobile ? 1.5 : 2.5,
      children: cards,
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: AppTheme.headingSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTable(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    
    if (_isLoading) {
      return Card(
        margin: EdgeInsets.all(isMobile ? 16 : 24),
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    
    final transactions = _filteredTransactions;

    return Card(
      margin: EdgeInsets.all(isMobile ? 16 : 24),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderColor, width: 1),
      ),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.table_chart, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text('TRANSACTION TABLE', style: AppTheme.headingSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    )),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _exportReport(context, format: 'PDF'),
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Export PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: BorderSide(color: AppTheme.errorColor),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _exportReport(context, format: 'Excel'),
                      icon: const Icon(Icons.description, size: 18),
                      label: const Text('Export Excel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.secondaryColor,
                        side: BorderSide(color: AppTheme.secondaryColor),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            child: isMobile
                ? _buildMobileTable(transactions)
                : _buildDesktopTable(context, transactions),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context, List<Map<String, dynamic>> transactions) {
    // Show ALL transactions - no limit
    final rowHeight = 56.0;
    final headerHeight = 52.0;
    
    // Check if we have transactions
    if (transactions.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'No transactions found',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
      );
    }
    
    // Calculate total table width needed for all columns
    final totalTableWidth = 100.0 + 90.0 + 120.0 + 120.0 + 120.0 + 120.0 + 130.0 + 100.0 + 120.0 + 120.0;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1.0,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalTableWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Table Header
              Container(
                height: headerHeight,
                width: totalTableWidth,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1.0,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _buildHeaderCell('Date', 100),
                    _buildHeaderCell('Time', 90),
                    _buildHeaderCell('Initiated By', 120),
                    _buildHeaderCell('Sender', 120),
                    _buildHeaderCell('Receiver', 120),
                    _buildHeaderCell('Transfer To', 120),
                    _buildHeaderCell('Purpose', 130),
                    _buildHeaderCell('Type', 100),
                    _buildHeaderCell('Collection Type', 120),
                    _buildHeaderCell('Mode', 120, isLast: true),
                  ],
                ),
              ),
              // Table Body - Show ALL rows
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: transactions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final transaction = entry.value;
                    final isLastRow = index == transactions.length - 1;

                    return Container(
                      height: rowHeight,
                      width: totalTableWidth,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isLastRow ? Colors.transparent : Colors.grey[200]!,
                            width: 0.5,
                          ),
                        ),
                        color: index.isEven ? Colors.white : Colors.grey[50],
                      ),
                      child: Row(
                        children: [
                          _buildDataCell(transaction['date'].toString(), 100),
                          _buildDataCell(
                            _extractTime(transaction['dateTime'] as DateTime),
                            90,
                          ),
                          _buildDataCell(transaction['initiatedBy'].toString(), 120),
                          _buildDataCell(transaction['sender']?.toString() ?? transaction['initiatedBy'].toString(), 120),
                          _buildDataCell(transaction['receiver']?.toString() ?? transaction['transferTo'].toString(), 120),
                          _buildDataCell(transaction['transferTo'].toString(), 120),
                          _buildDataCell(transaction['purpose'].toString(), 130),
                          _buildDataCell(transaction['type'].toString(), 100),
                          _buildDataCell(transaction['collectionType']?.toString() ?? 'N/A', 120),
                          _buildDataCell(transaction['mode'].toString(), 120, isLast: true),
                        ],
                      ),
                    );
                  }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileTable(List<Map<String, dynamic>> transactions) {
    // Show ALL transactions - no limit
    return SingleChildScrollView(
      child: Column(
        children: transactions.map((transaction) {
        final status = transaction['status'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: Colors.grey[300]!,
              width: 1.0,
            ),
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
                      '${transaction['date']} • ${_extractTime(transaction['dateTime'] as DateTime)}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMobileDetailRow('Date', transaction['date'].toString()),
                _buildMobileDetailRow('Time', _extractTime(transaction['dateTime'] as DateTime)),
                _buildMobileDetailRow('Initiated By', transaction['initiatedBy'].toString()),
                _buildMobileDetailRow('Sender', transaction['sender']?.toString() ?? transaction['initiatedBy'].toString()),
                _buildMobileDetailRow('Receiver', transaction['receiver']?.toString() ?? transaction['transferTo'].toString()),
                _buildMobileDetailRow('Transfer To', transaction['transferTo'].toString()),
                _buildMobileDetailRow('Purpose', transaction['purpose'].toString()),
                _buildMobileDetailRow('Type', transaction['type'].toString()),
                _buildMobileDetailRow('Collection Type', transaction['collectionType']?.toString() ?? 'N/A'),
                _buildMobileDetailRow('Mode', transaction['mode'].toString()),
                _buildMobileDetailRow('Auto Pay', transaction['autoPay'] == true ? 'Yes' : 'No'),
                _buildMobileDetailRow('Created By', transaction['createdBy'].toString()),
                _buildMobileDetailRow('Description', transaction['description']?.toString() ?? transaction['purpose'].toString()),
                if (transaction['voucherNo'] != null)
                  _buildMobileDetailRow('Voucher No', transaction['voucherNo'].toString()),
                if (transaction['customerName'] != null)
                  _buildMobileDetailRow('Customer Name', transaction['customerName'].toString()),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      transaction['amount'].toString(),
                      style: AppTheme.headingSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Viewing proof...')),
                        );
                      },
                      child: const Text('View Proof', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        }).toList(),
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width, {bool isLast = false}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          right: BorderSide(
            color: Colors.grey[200]!,
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, double width, {bool isLast = false}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          right: BorderSide(
            color: Colors.grey[200]!,
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }

  Widget _buildMobileDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStatusChip(String status) {
    Color chipColor;
    IconData icon;
    String displayText = status;
    
    if (status == 'Approved') {
      chipColor = AppTheme.secondaryColor;
      icon = Icons.check_circle;
      displayText = '✅ Approved';
    } else if (status == 'Pending') {
      chipColor = AppTheme.warningColor;
      icon = Icons.access_time;
      displayText = '⏳ Pending';
    } else if (status == 'Rejected') {
      chipColor = AppTheme.errorColor;
      icon = Icons.cancel;
      displayText = '❌ Rejected';
    } else {
      chipColor = AppTheme.errorColor;
      icon = Icons.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            displayText,
            style: AppTheme.bodySmall.copyWith(
              color: chipColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _applyFilters(BuildContext context) {
    _loadData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied filters - Showing ${_filteredTransactions.length} transaction(s)'),
        backgroundColor: AppTheme.secondaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearFilters(BuildContext context) {
    setState(() {
      _selectedInitiatedBy = null;
      _selectedTransferTo = null;
      _selectedPurpose = null;
      _selectedMode = null;
      _selectedType = null;
      _selectedCollectionType = null;
      _selectedStatus = null;
      _selectedCategory = null;
      // Reset to current day
      final now = DateTime.now();
      _fromDate = DateTime(now.year, now.month, now.day);
      _toDate = DateTime(now.year, now.month, now.day);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Filters reset to current day'),
        backgroundColor: AppTheme.primaryColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _exportReport(BuildContext context, {String format = 'PDF'}) async {
    final transactions = _filteredTransactions;
    
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      if (format == 'PDF') {
        // Generate CSV content for PDF (simplified - can be enhanced with PDF package)
        final csvContent = _generateCSV(transactions);
        await _downloadFile(csvContent, 'reports_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv', 'text/csv');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
            content: Text('Exported ${transactions.length} transactions as CSV'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      } else if (format == 'Excel') {
        // Generate CSV content for Excel
        final csvContent = _generateCSV(transactions);
        await _downloadFile(csvContent, 'reports_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv', 'text/csv');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${transactions.length} transactions as CSV (Excel compatible)'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  String _generateCSV(List<Map<String, dynamic>> transactions) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Date,Time,Initiated By,Sender,Receiver,Transfer To,Purpose,Type,Collection Type,Mode,Amount,Status');
    
    // Data rows
    for (var tx in transactions) {
      buffer.writeln([
        tx['date'] ?? '',
        tx['time'] ?? '',
        tx['initiatedBy'] ?? '',
        tx['sender'] ?? '',
        tx['receiver'] ?? '',
        tx['transferTo'] ?? '',
        '"${tx['purpose'] ?? ''}"',
        tx['type'] ?? '',
        tx['collectionType'] ?? 'N/A',
        tx['mode'] ?? '',
        tx['amountValue'] ?? 0,
        tx['status'] ?? '',
      ].join(','));
    }
    
    return buffer.toString();
  }

  Future<void> _downloadFile(String content, String filename, String mimeType) async {
    final result = await FileDownloadHelper.downloadFile(
      content: content,
      filename: filename,
      mimeType: mimeType,
    );
    
    if (mounted) {
      if (result != null && !result.startsWith('Error:')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result == 'Downloaded successfully' 
                ? 'File downloaded successfully' 
                : 'File saved to: $result'),
            backgroundColor: AppTheme.secondaryColor,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result ?? 'Failed to download file'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

