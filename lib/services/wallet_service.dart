import 'api_service.dart';
import '../utils/api_constants.dart';

class WalletService {
  /// Get wallet balance
  static Future<Map<String, dynamic>> getWallet() async {
    try {
      final response = await ApiService.get(ApiConstants.getWallet);
      
      if (response['wallet'] != null) {
        final wallet = response['wallet'] as Map<String, dynamic>;
        
        // Ensure totalBalance is calculated if not present
        if (wallet['totalBalance'] == null) {
          final cashBalance = (wallet['cashBalance'] ?? 0.0).toDouble();
          final upiBalance = (wallet['upiBalance'] ?? 0.0).toDouble();
          final bankBalance = (wallet['bankBalance'] ?? 0.0).toDouble();
          wallet['totalBalance'] = cashBalance + upiBalance + bankBalance;
        }
        
        return {
          'success': true,
          'wallet': wallet,
        };
      }
      
      return {
        'success': false,
        'message': 'Wallet data not found',
        'wallet': null,
      };
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      return {
        'success': false,
        'message': errorMessage.isNotEmpty ? errorMessage : 'Failed to fetch wallet balance',
        'wallet': null,
      };
    }
  }

  /// Add amount to wallet (SuperAdmin can add to any wallet, others to their own)
  static Future<Map<String, dynamic>> addAmount({
    required String mode,
    required double amount,
    String? notes,
    String? userId,
  }) async {
    try {
      // Validation
      if (amount <= 0) {
        return {
          'success': false,
          'message': 'Amount must be greater than zero',
        };
      }

      if (mode.isEmpty) {
        return {
          'success': false,
          'message': 'Payment mode is required',
        };
      }

      final body = <String, dynamic>{
        'mode': mode,
        'amount': amount,
      };
      
      if (notes != null && notes.isNotEmpty) {
        body['notes'] = notes;
      }
      
      if (userId != null && userId.isNotEmpty) {
        body['userId'] = userId;
      }

      final response = await ApiService.post(ApiConstants.addWallet, body);

      return {
        'success': true,
        'message': response['message'] ?? 'Amount added successfully',
        'wallet': response['wallet'],
      };
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      return {
        'success': false,
        'message': errorMessage.isNotEmpty ? errorMessage : 'Failed to add amount to wallet',
      };
    }
  }

  /// Withdraw amount from wallet (SuperAdmin only)
  static Future<Map<String, dynamic>> withdrawAmount(
      String mode, double amount, String notes) async {
    try {
      // Validation
      if (amount <= 0) {
        return {
          'success': false,
          'message': 'Amount must be greater than zero',
        };
      }

      if (mode.isEmpty) {
        return {
          'success': false,
          'message': 'Payment mode is required',
        };
      }

      final response = await ApiService.post(ApiConstants.withdrawWallet, {
        'mode': mode,
        'amount': amount,
        'notes': notes,
      });

      return {
        'success': true,
        'message': response['message'] ?? 'Amount withdrawn successfully',
        'wallet': response['wallet'],
      };
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      return {
        'success': false,
        'message': errorMessage.isNotEmpty ? errorMessage : 'Failed to withdraw amount from wallet',
      };
    }
  }

  /// Reset wallet balances to zero
  static Future<Map<String, dynamic>> resetWallet({String? notes, String? userId}) async {
    try {
      final body = <String, dynamic>{};
      if (notes != null && notes.isNotEmpty) {
        body['notes'] = notes;
      }
      if (userId != null && userId.isNotEmpty) {
        body['userId'] = userId;
      }

      final response = await ApiService.post(ApiConstants.resetWallet, body);

      return {
        'success': true,
        'message': response['message'] ?? 'Wallet balances reset successfully',
        'wallet': response['wallet'],
        'oldBalances': response['oldBalances'],
      };
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      return {
        'success': false,
        'message': errorMessage.isNotEmpty ? errorMessage : 'Failed to reset wallet balances',
      };
    }
  }

  /// Get all user wallets (SuperAdmin only)
  static Future<Map<String, dynamic>> getAllWallets() async {
    try {
      final response = await ApiService.get(ApiConstants.getAllWallets);
      
      // Check if response indicates an error (403 permission denied, etc.)
      if (response['success'] == false) {
        return {
          'success': false,
          'message': response['message'] ?? 'Failed to load wallets',
          'wallets': [],
          'count': 0,
        };
      }
      
      return {
        'success': true,
        'wallets': response['wallets'] ?? [],
        'count': response['count'] ?? 0,
      };
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [WALLET SERVICE] Error in getAllWallets: $errorMessage');
      return {
        'success': false,
        'message': errorMessage.isNotEmpty ? errorMessage : 'Failed to load wallets. Please check your permissions.',
        'wallets': [],
        'count': 0,
      };
    }
  }

  /// Get self wallet report (logged-in user's own wallet)
  static Future<Map<String, dynamic>> getSelfWalletReport({
    DateTime? startDate,
    DateTime? endDate,
    String? mode,
    String? status,
    String? type,
  }) async {
    try {
      final queryParams = <String, String>{};

      // Add date range parameters
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      // Add mode parameter (exclude 'All')
      if (mode != null && mode.isNotEmpty && mode != 'All') {
        queryParams['mode'] = mode;
      }

      // Add status parameter
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      // Add type parameter
      if (type != null && type.isNotEmpty) {
        queryParams['type'] = type;
      }

      // Make API call
      print('[SELF WALLET] 📡 API Call: ${ApiConstants.getSelfWalletReport} | Params: $queryParams');
      
      final response = await ApiService.get(
        ApiConstants.getSelfWalletReport,
        queryParams: queryParams.isEmpty ? null : queryParams,
      );

      print('[SELF WALLET] 📥 Response: success=${response['success']}, dataCount=${response['data'] is List ? (response['data'] as List).length : 0}');

      // Check success - handle both bool true and truthy values
      final bool success = response['success'] == true || 
                           response['success'] == 1 ||
                           (response['success'] is String && response['success'].toLowerCase() == 'true');

      // Parse data
      final data = response['data'] is List
          ? List<Map<String, dynamic>>.from(
              (response['data'] as List).map(
                (item) => item is Map
                    ? Map<String, dynamic>.from(item as Map)
                    : <String, dynamic>{},
              ),
            )
          : <Map<String, dynamic>>[];

      // Parse wallet
      final walletRaw = response['wallet'];
      final wallet = walletRaw is Map
          ? Map<String, dynamic>.from(walletRaw as Map)
          : <String, dynamic>{
              'cashBalance': 0.0,
              'upiBalance': 0.0,
              'bankBalance': 0.0,
              'totalBalance': 0.0,
            };

      // Parse summary
      final summaryRaw = response['summary'];
      final summary = summaryRaw is Map
          ? Map<String, dynamic>.from(summaryRaw as Map)
          : <String, dynamic>{
              'cashIn': 0.0,
              'cashOut': 0.0,
              'balance': 0.0,
            };

      // Parse breakdown
      final breakdownRaw = response['breakdown'];
      final breakdown = breakdownRaw is Map
          ? Map<String, dynamic>.from(breakdownRaw as Map)
          : <String, dynamic>{
              'Expenses': {
                'Approved': {'count': 0, 'amount': 0.0},
                'Unapproved': {'count': 0, 'amount': 0.0},
                'Flagged': {'count': 0, 'amount': 0.0},
                'Rejected': {'count': 0, 'amount': 0.0},
              },
              'Transactions': {
                'Approved': {'count': 0, 'amount': 0.0},
                'Unapproved': {'count': 0, 'amount': 0.0},
                'Flagged': {'count': 0, 'amount': 0.0},
                'Rejected': {'count': 0, 'amount': 0.0},
              },
              'Collections': {
                'Accounted': {'count': 0, 'amount': 0.0},
                'Unaccounted': {'count': 0, 'amount': 0.0},
                'Flagged': {'count': 0, 'amount': 0.0},
                'Rejected': {'count': 0, 'amount': 0.0},
              },
              'WalletTransactions': {
                'Add': {'count': 0, 'amount': 0.0},
                'Withdraw': {'count': 0, 'amount': 0.0},
              },
            };

      final cashIn = summary['cashIn'] ?? 0.0;
      final cashOut = summary['cashOut'] ?? 0.0;
      final balance = summary['balance'] ?? wallet['totalBalance'] ?? 0.0;
      print('[SELF WALLET] ✅ Parsed: success=$success, data=${data.length}, CashIn=$cashIn, CashOut=$cashOut, Balance=$balance');
      
      return {
        'success': success,
        'data': data,
        'wallet': wallet,
        'summary': summary,
        'breakdown': breakdown,
        'count': response['count'] ?? data.length,
        'message': response['message'],
      };
    } catch (e, stackTrace) {
      print('[SELF WALLET] ❌ Exception: ${e.toString()} (${e.runtimeType})');
      
      // Provide more detailed error message
      String errorMessage = 'Failed to load wallet data';
      if (e.toString().contains('Failed to connect')) {
        errorMessage = 'Cannot connect to server. Please check your internet connection.';
      } else if (e.toString().contains('401') || e.toString().contains('Authentication')) {
        errorMessage = 'Authentication failed. Please login again.';
      } else {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      
    return {
        'success': false,
        'message': errorMessage,
        'error': e.toString(),
        'data': [],
      'wallet': <String, dynamic>{
        'cashBalance': 0.0,
        'upiBalance': 0.0,
        'bankBalance': 0.0,
        'totalBalance': 0.0,
      },
      'summary': <String, dynamic>{
        'cashIn': 0.0,
        'cashOut': 0.0,
        'balance': 0.0,
      },
      'breakdown': <String, dynamic>{
        'Expenses': {
          'Approved': {'count': 0, 'amount': 0.0},
          'Unapproved': {'count': 0, 'amount': 0.0},
          'Flagged': {'count': 0, 'amount': 0.0},
          'Rejected': {'count': 0, 'amount': 0.0},
        },
        'Transactions': {
          'Approved': {'count': 0, 'amount': 0.0},
          'Unapproved': {'count': 0, 'amount': 0.0},
          'Flagged': {'count': 0, 'amount': 0.0},
          'Rejected': {'count': 0, 'amount': 0.0},
        },
        'Collections': {
          'Accounted': {'count': 0, 'amount': 0.0},
          'Unaccounted': {'count': 0, 'amount': 0.0},
          'Flagged': {'count': 0, 'amount': 0.0},
          'Rejected': {'count': 0, 'amount': 0.0},
        },
          'WalletTransactions': {
            'Add': {'count': 0, 'amount': 0.0},
            'Withdraw': {'count': 0, 'amount': 0.0},
        },
      },
      'count': 0,
    };
    }
  }

  /// Get all wallet report (SuperAdmin only - all users' data)
  /// Backend API call removed - returns empty data
  static Future<Map<String, dynamic>> getAllWalletReport({
    List<String>? userIds,
    DateTime? startDate,
    DateTime? endDate,
    String? mode,
    String? status,
    String? type,
    String? accountId,
    String? userRole,
  }) async {
    // Backend API call removed - using empty data with all amounts set to zero
    return {
      'success': true,
      'data': <Map<String, dynamic>>[],
      'wallet': null,
      'walletSummary': <String, dynamic>{
        'cashBalance': 0.0,
        'upiBalance': 0.0,
        'bankBalance': 0.0,
        'totalBalance': 0.0,
        'cashIn': 0.0,
        'cashOut': 0.0,
        'walletCount': 0,
      },
      'summary': <String, dynamic>{
        'cashIn': 0.0,
        'cashOut': 0.0,
        'balance': 0.0,
      },
      'breakdown': <String, dynamic>{
        'Expenses': {
          'Approved': {'count': 0, 'amount': 0.0},
          'Unapproved': {'count': 0, 'amount': 0.0},
          'Flagged': {'count': 0, 'amount': 0.0},
          'Rejected': {'count': 0, 'amount': 0.0},
        },
        'Transactions': {
          'Approved': {'count': 0, 'amount': 0.0},
          'Unapproved': {'count': 0, 'amount': 0.0},
          'Flagged': {'count': 0, 'amount': 0.0},
          'Rejected': {'count': 0, 'amount': 0.0},
        },
        'Collections': {
          'Accounted': {'count': 0, 'amount': 0.0},
          'Unaccounted': {'count': 0, 'amount': 0.0},
          'Flagged': {'count': 0, 'amount': 0.0},
          'Rejected': {'count': 0, 'amount': 0.0},
        },
      },
      'count': 0,
      'filterMode': 'all',
      'message': null,
    };
  }

  /// Get wallet activity report (DEPRECATED - use getSelfWalletReport or getAllWalletReport)
  /// This method is kept for backward compatibility
  static Future<Map<String, dynamic>> getWalletReport({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    String? mode,
    String? status,
    String? type,
    String? accountId,
    String? userRole,
  }) async {
    try {
      final queryParams = <String, String>{};

      if (userId != null && userId.isNotEmpty) {
        queryParams['userId'] = userId;
      }
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      if (mode != null && mode.isNotEmpty) {
        queryParams['mode'] = mode;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (type != null && type.isNotEmpty) {
        queryParams['type'] = type;
      }
      if (accountId != null && accountId.isNotEmpty) {
        queryParams['accountId'] = accountId;
      }
      if (userRole != null && userRole.isNotEmpty) {
        queryParams['userRole'] = userRole;
      }

      final response = await ApiService.get(
        ApiConstants.getWalletReport,
        queryParams: queryParams.isEmpty ? null : queryParams,
      );

      final bool success = response['success'] != null
          ? response['success'] == true
          : true;

      final data = response['data'] is List
          ? List<Map<String, dynamic>>.from(
              (response['data'] as List).map((item) => item is Map ? Map<String, dynamic>.from(item as Map) : <String, dynamic>{}),
            )
          : <Map<String, dynamic>>[];

      final summaryRaw = response['summary'];
      final breakdownRaw = response['breakdown'];
      final walletRaw = response['wallet'];
      final walletSummaryRaw = response['walletSummary'];

      return {
        'success': success,
        'data': data,
        'wallet': walletRaw is Map ? Map<String, dynamic>.from(walletRaw as Map) : null,
        'walletSummary': walletSummaryRaw is Map ? Map<String, dynamic>.from(walletSummaryRaw as Map) : null,
        'summary': summaryRaw is Map ? Map<String, dynamic>.from(summaryRaw as Map) : <String, dynamic>{},
        'breakdown': breakdownRaw is Map ? Map<String, dynamic>.from(breakdownRaw as Map) : <String, dynamic>{},
        'count': response['count'] ?? 0,
        'message': response['message'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'data': [],
        'summary': <String, dynamic>{},
        'breakdown': <String, dynamic>{},
        'count': 0,
      };
    }
  }

  /// Get wallet transaction history
  static Future<Map<String, dynamic>> getWalletTransactions({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    String? mode,
    String? type, // 'add', 'withdraw', 'transfer'
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, String>{};

      if (userId != null && userId.isNotEmpty) {
        queryParams['userId'] = userId;
      }
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      if (mode != null && mode.isNotEmpty) {
        queryParams['mode'] = mode;
      }
      if (type != null && type.isNotEmpty) {
        queryParams['type'] = type;
      }
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }
      if (offset != null) {
        queryParams['offset'] = offset.toString();
      }

      final response = await ApiService.get(
        ApiConstants.getWalletTransactions,
        queryParams: queryParams.isEmpty ? null : queryParams,
      );

      final transactions = response['transactions'] is List
          ? List<Map<String, dynamic>>.from(
              (response['transactions'] as List).map(
                (item) => item is Map
                    ? Map<String, dynamic>.from(item as Map)
                    : <String, dynamic>{},
              ),
            )
          : <Map<String, dynamic>>[];

      return {
        'success': true,
        'transactions': transactions,
        'count': response['count'] ?? transactions.length,
        'total': response['total'] ?? transactions.length,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'transactions': [],
        'count': 0,
        'total': 0,
      };
    }
  }

  /// Get specific wallet transaction by ID
  static Future<Map<String, dynamic>> getWalletTransactionById(String id) async {
    try {
      final response = await ApiService.get(
        ApiConstants.walletTransactionById(id),
      );

      return {
        'success': true,
        'transaction': response['transaction'] ?? response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'transaction': null,
      };
    }
  }

  /// Transfer amount between payment modes (e.g., Cash to UPI)
  static Future<Map<String, dynamic>> transferBetweenModes({
    required String fromMode,
    required String toMode,
    required double amount,
    String? notes,
  }) async {
    try {
      if (fromMode == toMode) {
        return {
          'success': false,
          'message': 'Source and destination modes cannot be the same',
        };
      }

      if (amount <= 0) {
        return {
          'success': false,
          'message': 'Amount must be greater than zero',
        };
      }

      final response = await ApiService.post(ApiConstants.transferBetweenModes, {
        'fromMode': fromMode,
        'toMode': toMode,
        'amount': amount,
        'notes': notes ?? 'Transfer between payment modes',
      });

      return {
        'success': true,
        'message': response['message'] ?? 'Transfer completed successfully',
        'wallet': response['wallet'],
        'transaction': response['transaction'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Transfer amount between users (SuperAdmin only)
  static Future<Map<String, dynamic>> transferBetweenUsers({
    required String fromUserId,
    required String toUserId,
    required String mode,
    required double amount,
    String? notes,
  }) async {
    try {
      if (fromUserId == toUserId) {
        return {
          'success': false,
          'message': 'Source and destination users cannot be the same',
        };
      }

      if (amount <= 0) {
        return {
          'success': false,
          'message': 'Amount must be greater than zero',
        };
      }

      final response = await ApiService.post(ApiConstants.transferBetweenUsers, {
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'mode': mode,
        'amount': amount,
        'notes': notes ?? 'Transfer between users',
      });

      return {
        'success': true,
        'message': response['message'] ?? 'Transfer completed successfully',
        'fromWallet': response['fromWallet'],
        'toWallet': response['toWallet'],
        'transaction': response['transaction'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Add amount to account (SuperAdmin only)
  static Future<Map<String, dynamic>> addAmountToAccount({
    required String accountId,
    required double amount,
    String? remark,
  }) async {
    try {
      // Validation
      if (amount <= 0) {
        return {
          'success': false,
          'message': 'Amount must be greater than zero',
        };
      }

      if (accountId.isEmpty) {
        return {
          'success': false,
          'message': 'Account selection is required',
        };
      }

      final response = await ApiService.post(ApiConstants.addAmountToAccount, {
        'accountId': accountId,
        'amount': amount,
        'remark': remark ?? '',
      });

      return {
        'success': true,
        'message': response['message'] ?? 'Amount added to account successfully',
        'wallet': response['wallet'],
        'transaction': response['transaction'],
      };
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      return {
        'success': false,
        'message': errorMessage.isNotEmpty ? errorMessage : 'Failed to add amount to account',
      };
    }
  }

  /// Withdraw amount from account (SuperAdmin only)
  static Future<Map<String, dynamic>> withdrawFromAccount({
    required String accountId,
    required double amount,
    String? remark,
  }) async {
    try {
      // Validation
      if (amount <= 0) {
        return {
          'success': false,
          'message': 'Amount must be greater than zero',
        };
      }

      if (accountId.isEmpty) {
        return {
          'success': false,
          'message': 'Account selection is required',
        };
      }

      final response = await ApiService.post(ApiConstants.withdrawFromAccount, {
        'accountId': accountId,
        'amount': amount,
        'remark': remark ?? '',
      });

      return {
        'success': true,
        'message': response['message'] ?? 'Amount withdrawn from account successfully',
        'wallet': response['wallet'],
        'transaction': response['transaction'],
      };
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      return {
        'success': false,
        'message': errorMessage.isNotEmpty ? errorMessage : 'Failed to withdraw amount from account',
      };
    }
  }

  /// Get wallet settings/configuration
  static Future<Map<String, dynamic>> getWalletSettings() async {
    try {
      final response = await ApiService.get(ApiConstants.getWalletSettings);
      return {
        'success': true,
        'settings': response['settings'] ?? response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'settings': null,
      };
    }
  }

  /// Update wallet settings
  static Future<Map<String, dynamic>> updateWalletSettings({
    required Map<String, dynamic> settings,
  }) async {
    try {
      final response = await ApiService.put(
        ApiConstants.updateWalletSettings,
        settings,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Settings updated successfully',
        'settings': response['settings'] ?? response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Export wallet report
  static Future<Map<String, dynamic>> exportWalletReport({
    String format = 'csv', // 'csv', 'excel', 'pdf'
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    String? mode,
    String? status,
    String? type,
  }) async {
    try {
      final queryParams = <String, String>{
        'format': format,
      };

      if (userId != null && userId.isNotEmpty) {
        queryParams['userId'] = userId;
      }
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      if (mode != null && mode.isNotEmpty) {
        queryParams['mode'] = mode;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (type != null && type.isNotEmpty) {
        queryParams['type'] = type;
      }

      final response = await ApiService.get(
        ApiConstants.exportWalletReport,
        queryParams: queryParams,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Report exported successfully',
        'downloadUrl': response['downloadUrl'] ?? response['url'],
        'fileFormat': format,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Get wallet analytics data
  static Future<Map<String, dynamic>> getWalletAnalytics({
    DateTime? startDate,
    DateTime? endDate,
    String? groupBy, // 'day', 'week', 'month', 'year'
    String? userId,
  }) async {
    try {
      final queryParams = <String, String>{};

      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      if (groupBy != null && groupBy.isNotEmpty) {
        queryParams['groupBy'] = groupBy;
      }
      if (userId != null && userId.isNotEmpty) {
        queryParams['userId'] = userId;
      }

      final response = await ApiService.get(
        ApiConstants.getWalletAnalytics,
        queryParams: queryParams.isEmpty ? null : queryParams,
      );

      return {
        'success': true,
        'analytics': response['analytics'] ?? response['data'] ?? response,
        'summary': response['summary'] ?? <String, dynamic>{},
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'analytics': null,
        'summary': <String, dynamic>{},
      };
    }
  }
}
