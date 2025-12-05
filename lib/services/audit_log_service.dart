import 'api_service.dart';
import '../utils/api_constants.dart';

class AuditLogService {
  /// Get audit logs with filters
  static Future<Map<String, dynamic>> getAuditLogs({
    int page = 1,
    int limit = 50,
    String? actionType,
    String? entityType,
    String? userId,
    String? startDate,
    String? endDate,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (actionType != null) queryParams['actionType'] = actionType;
      if (entityType != null) queryParams['entityType'] = entityType;
      if (userId != null) queryParams['userId'] = userId;
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (search != null) queryParams['search'] = search;

      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');

      final response = await ApiService.get('${ApiConstants.getAuditLogs}?$queryString');

      return {
        'success': true,
        'auditLogs': response['auditLogs'] ?? [],
        'total': response['total'] ?? 0,
        'page': response['page'] ?? page,
        'limit': response['limit'] ?? limit,
        'totalPages': response['totalPages'] ?? 0,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'auditLogs': [],
        'total': 0,
        'page': page,
        'limit': limit,
        'totalPages': 0,
      };
    }
  }

  /// Get recent activity (consolidated view)
  static Future<Map<String, dynamic>> getRecentActivity({int limit = 50}) async {
    try {
      final response = await ApiService.get(
        '${ApiConstants.getRecentActivity}?limit=$limit'
      );

      return {
        'success': true,
        'activities': response['activities'] ?? [],
        'count': response['count'] ?? 0,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'activities': [],
        'count': 0,
      };
    }
  }

  /// Get user activity summary (all user operations)
  static Future<Map<String, dynamic>> getUserActivity(String userId) async {
    try {
      final response = await ApiService.get(ApiConstants.getUserActivity(userId));

      return {
        'success': true,
        'user': response['user'],
        'wallet': response['wallet'],
        'auditLogs': response['auditLogs'] ?? [],
        'transactions': response['transactions'] ?? [],
        'collections': response['collections'] ?? [],
        'expenses': response['expenses'] ?? [],
        'summary': response['summary'] ?? {},
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'user': null,
        'wallet': null,
        'auditLogs': [],
        'transactions': [],
        'collections': [],
        'expenses': [],
        'summary': {},
      };
    }
  }
}

