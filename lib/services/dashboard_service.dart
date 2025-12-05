import 'api_service.dart';
import '../utils/api_constants.dart';

class DashboardService {
  /// Get dashboard data
  static Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await ApiService.get(ApiConstants.getDashboard);
      
      return {
        'success': true,
        'dashboard': response['dashboard'] ?? {},
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'dashboard': {},
      };
    }
  }

  /// Get dashboard summary (financial summary, status counts, flagged items)
  static Future<Map<String, dynamic>> getDashboardSummary({String? userId}) async {
    try {
      final queryParams = <String, String>{};
      if (userId != null && userId.isNotEmpty) {
        queryParams['userId'] = userId;
      }
      
      final response = await ApiService.get(
        ApiConstants.getDashboardSummary,
        queryParams: queryParams.isEmpty ? null : queryParams,
      );
      
      return {
        'success': response['success'] == true,
        'data': response['data'] ?? {},
        'message': response['message'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'data': {},
      };
    }
  }
}

