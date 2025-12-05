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
  static Future<Map<String, dynamic>> getAllWalletReportsWithFilters({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    String? accountId,
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
      if (accountId != null && accountId.isNotEmpty) {
        queryParams['accountId'] = accountId;
      }
      
      print('📊 [ALL WALLET REPORTS] Frontend: Requesting reports with filters: userId=${userId ?? 'null'}, startDate=${startDate?.toIso8601String() ?? 'null'}, endDate=${endDate?.toIso8601String() ?? 'null'}, accountId=${accountId ?? 'null'}');
      
      final response = await ApiService.get(
        ApiConstants.getAllWalletReports,
        queryParams: queryParams.isEmpty ? null : queryParams,
      );
      
      if (response['success'] == true && response['report'] != null) {
        final report = response['report'] as Map<String, dynamic>;
        
        print('📊 [ALL WALLET REPORTS] Frontend: Received response: success=true, report=${report.toString()}, userCount=${response['userCount'] ?? 0}');
        
        return {
          'success': true,
          'report': {
            'cashIn': (report['cashIn'] ?? 0.0).toDouble(),
            'cashOut': (report['cashOut'] ?? 0.0).toDouble(),
            'balance': (report['balance'] ?? 0.0).toDouble(),
          },
          'filters': {
            'userId': response['filters']?['userId'] ?? userId,
            'startDate': response['filters']?['startDate'] ?? startDate?.toIso8601String(),
            'endDate': response['filters']?['endDate'] ?? endDate?.toIso8601String(),
          },
          'userCount': response['userCount'] ?? 0,
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

