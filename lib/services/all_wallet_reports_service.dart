import 'api_service.dart';
import '../utils/api_constants.dart';

class AllWalletReportsService {
  /// Get aggregated totals for all users (Cash In, Cash Out, Balance)
  static Future<Map<String, dynamic>> getAllWalletReportsTotals() async {
    try {
      print('📊 [ALL WALLET REPORTS] Frontend: Requesting totals...');
      
      final response = await ApiService.get(ApiConstants.getAllWalletReportsTotals);
      
      if (response['success'] == true && response['totals'] != null) {
        final totals = response['totals'] as Map<String, dynamic>;
        
        print('📊 [ALL WALLET REPORTS] Frontend: Received response: success=true, totals=${totals.toString()}');
        
        return {
          'success': true,
          'totals': {
            'totalCashIn': (totals['totalCashIn'] ?? 0.0).toDouble(),
            'totalCashOut': (totals['totalCashOut'] ?? 0.0).toDouble(),
            'totalBalance': (totals['totalBalance'] ?? 0.0).toDouble(),
            'userCount': totals['userCount'] ?? 0,
            'lastUpdated': totals['lastUpdated'] ?? DateTime.now().toIso8601String(),
          },
        };
      }
      
      return {
        'success': false,
        'message': response['message'] ?? 'Failed to fetch wallet reports totals',
        'totals': null,
      };
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [ALL WALLET REPORTS] Frontend: Error: $errorMessage');
      return {
        'success': false,
        'message': errorMessage.isNotEmpty ? errorMessage : 'Failed to fetch wallet reports totals',
        'totals': null,
      };
    }
  }

  /// Get wallet report for a specific user
  static Future<Map<String, dynamic>> getUserWalletReport(String userId) async {
    try {
      print('📊 [ALL WALLET REPORTS] Frontend: Requesting report for userId: $userId');
      
      if (userId.isEmpty) {
        return {
          'success': false,
          'message': 'User ID is required',
          'report': null,
        };
      }
      
      final response = await ApiService.get(ApiConstants.getUserWalletReport(userId));
      
      if (response['success'] == true && response['report'] != null) {
        final report = response['report'] as Map<String, dynamic>;
        
        print('📊 [ALL WALLET REPORTS] Frontend: Received response: success=true, userId=${response['userId']}, report=${report.toString()}');
        
        return {
          'success': true,
          'userId': response['userId'] ?? userId,
          'userName': response['userName'] ?? 'Unknown',
          'report': {
            'cashIn': (report['cashIn'] ?? 0.0).toDouble(),
            'cashOut': (report['cashOut'] ?? 0.0).toDouble(),
            'balance': (report['balance'] ?? 0.0).toDouble(),
          },
          'lastUpdated': response['lastUpdated'] ?? DateTime.now().toIso8601String(),
        };
      }
      
      return {
        'success': false,
        'message': response['message'] ?? 'Failed to fetch user wallet report',
        'report': null,
      };
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [ALL WALLET REPORTS] Frontend: Error: $errorMessage');
      return {
        'success': false,
        'message': errorMessage.isNotEmpty ? errorMessage : 'Failed to fetch user wallet report',
        'report': null,
      };
    }
  }

  /// Get all wallet reports with optional filters
  /// Supports single user, multiple users (comma-separated), or all users (null)
  static Future<Map<String, dynamic>> getAllWalletReportsWithFilters({
    List<String>? userIds,
    String? userId, // Deprecated: Use userIds instead, kept for backward compatibility
    DateTime? startDate,
    DateTime? endDate,
    String? accountId,
  }) async {
    try {
      final queryParams = <String, String>{};
      
      // Support both new userIds parameter and legacy userId parameter
      List<String>? finalUserIds = userIds;
      if (finalUserIds == null && userId != null && userId.isNotEmpty) {
        // Legacy support: convert single userId to list
        finalUserIds = [userId];
      }
      
      if (finalUserIds != null && finalUserIds.isNotEmpty) {
        if (finalUserIds.length == 1) {
          // Single user: send as single userId
          queryParams['userId'] = finalUserIds.first;
        } else {
          // Multiple users: send as comma-separated string
          queryParams['userId'] = finalUserIds.join(',');
        }
      }
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      if (accountId != null && accountId.isNotEmpty) {
        queryParams['accountId'] = accountId;
      }
      
      print('═══════════════════════════════════════════════════════════');
      print('📊 [ALL WALLET REPORTS] Frontend: API Request');
      print('   Endpoint: ${ApiConstants.getAllWalletReports}');
      print('   Query Parameters:');
      print('     - userIds: ${finalUserIds?.join(", ") ?? 'null'} (${finalUserIds?.length ?? 0} user(s))');
      print('     - userId (query param): ${queryParams['userId'] ?? 'null'}');
      print('     - startDate: ${startDate?.toIso8601String() ?? 'null'}');
      print('     - endDate: ${endDate?.toIso8601String() ?? 'null'}');
      print('     - accountId: ${accountId ?? 'null'}');
      print('   Full QueryParams: $queryParams');
      print('═══════════════════════════════════════════════════════════');
      
      final response = await ApiService.get(
        ApiConstants.getAllWalletReports,
        queryParams: queryParams.isEmpty ? null : queryParams,
      );
      
      if (response['success'] == true && response['report'] != null) {
        final report = response['report'] as Map<String, dynamic>;
        
        // Extract transactions array if available
        final transactions = response['transactions'] as List<dynamic>? ?? [];
        
        print('═══════════════════════════════════════════════════════════');
        print('✅ [ALL WALLET REPORTS] Frontend: API Response Received');
        print('   success: true');
        print('   report:');
        print('     - cashIn: ${report['cashIn'] ?? 0}');
        print('     - cashOut: ${report['cashOut'] ?? 0}');
        print('     - balance: ${report['balance'] ?? 0}');
        print('     - addAmountCount: ${report['addAmountCount'] ?? 0}');
        print('     - addAmountTotal: ${report['addAmountTotal'] ?? 0}');
        print('     - withdrawCount: ${report['withdrawCount'] ?? 0}');
        print('     - withdrawTotal: ${report['withdrawTotal'] ?? 0}');
        print('   userCount: ${response['userCount'] ?? 0}');
        print('   transactionCount: ${response['transactionCount'] ?? 0}');
        print('   transactions: ${transactions.length} entries');
        print('   filters: ${response['filters'] ?? 'null'}');
        print('   lastUpdated: ${response['lastUpdated'] ?? 'null'}');
        print('═══════════════════════════════════════════════════════════');
        
        return {
          'success': true,
          'report': {
            'cashIn': (report['cashIn'] ?? 0.0).toDouble(),
            'cashOut': (report['cashOut'] ?? 0.0).toDouble(),
            'balance': (report['balance'] ?? 0.0).toDouble(),
            'addAmountCount': (report['addAmountCount'] ?? 0),
            'addAmountTotal': (report['addAmountTotal'] ?? 0.0).toDouble(),
            'withdrawCount': (report['withdrawCount'] ?? 0),
            'withdrawTotal': (report['withdrawTotal'] ?? 0.0).toDouble(),
          },
          'transactions': transactions,
          'filters': {
            'userId': response['filters']?['userId'] ?? queryParams['userId'],
            'userIds': finalUserIds,
            'startDate': response['filters']?['startDate'] ?? startDate?.toIso8601String(),
            'endDate': response['filters']?['endDate'] ?? endDate?.toIso8601String(),
          },
          'userCount': response['userCount'] ?? 0,
          'transactionCount': response['transactionCount'] ?? 0,
          'lastUpdated': response['lastUpdated'] ?? DateTime.now().toIso8601String(),
        };
      }
      
      return {
        'success': false,
        'message': response['message'] ?? 'Failed to fetch wallet reports',
        'report': null,
      };
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      print('❌ [ALL WALLET REPORTS] Frontend: Error: $errorMessage');
      return {
        'success': false,
        'message': errorMessage.isNotEmpty ? errorMessage : 'Failed to fetch wallet reports',
        'report': null,
      };
    }
  }
}

