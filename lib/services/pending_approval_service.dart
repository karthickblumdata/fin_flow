import 'api_service.dart';
import '../utils/api_constants.dart';

class PendingApprovalService {
  static Future<Map<String, dynamic>> getPendingApprovals({
    String? type,
    String? status,
    String? mode,
    int? page,
    int? limit,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};

      if (type != null && type.isNotEmpty) {
        queryParams['type'] = type;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (mode != null && mode.isNotEmpty) {
        queryParams['mode'] = mode;
      }
      if (page != null && page > 0) {
        queryParams['page'] = page.toString();
      }
      if (limit != null && limit > 0) {
        queryParams['limit'] = limit.toString();
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await ApiService.get(
        ApiConstants.getPendingApprovals,
        queryParams: queryParams.isEmpty ? null : queryParams,
      );

      return response;
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> exportPendingApprovals(Map<String, dynamic> payload) async {
    try {
      final response = await ApiService.post(
        ApiConstants.exportPendingApprovals,
        payload,
      );

      return {
        'success': response['success'] == null ? true : response['success'] == true,
        'message': response['message'],
        'data': response['data'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }
}
