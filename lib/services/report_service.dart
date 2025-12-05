import 'api_service.dart';
import '../utils/api_constants.dart';

class ReportService {
  /// Get reports with optional filters
  static Future<Map<String, dynamic>> getReports({
    String? startDate,
    String? endDate,
    String? mode,
    String? status,
    String? category,
  }) async {
    try {
      final queryParams = <String, String>{};
      
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (mode != null && mode != 'All') queryParams['mode'] = mode;
      if (status != null && status != 'All') queryParams['status'] = status;
      if (category != null && category != 'All') queryParams['category'] = category;

      final response = await ApiService.get(
        ApiConstants.getReports,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      return {
        'success': true,
        'report': response['report'] ?? {},
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'report': {},
      };
    }
  }

  /// Get person-wise reports
  static Future<Map<String, dynamic>> getPersonWiseReports({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final response = await ApiService.get(
        ApiConstants.getPersonWiseReports,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      return {
        'success': true,
        'personWiseReports': response['personWiseReports'] ?? [],
        'count': response['count'] ?? 0,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'personWiseReports': [],
        'count': 0,
      };
    }
  }

  /// Save current report
  static Future<Map<String, dynamic>> saveReport({
    required String reportName,
    Map<String, dynamic>? filters,
    bool includeFullData = false,
    bool isTemplate = false,
    List<String>? tags,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'reportName': reportName,
        'includeFullData': includeFullData,
        'isTemplate': isTemplate,
      };

      if (filters != null) body['filters'] = filters;
      if (tags != null) body['tags'] = tags;
      if (notes != null) body['notes'] = notes;

      final response = await ApiService.post(
        ApiConstants.saveReport,
        body,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Report saved successfully',
        'report': response['report'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Get all saved reports
  static Future<Map<String, dynamic>> getSavedReports({
    String? type,
    bool? template,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (type != null) queryParams['type'] = type;
      if (template != null) queryParams['template'] = template.toString();

      final response = await ApiService.get(
        ApiConstants.getSavedReports,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      return {
        'success': true,
        'reports': response['reports'] ?? [],
        'count': response['count'] ?? 0,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'reports': [],
        'count': 0,
      };
    }
  }

  /// Get specific saved report
  static Future<Map<String, dynamic>> getSavedReport(String reportId) async {
    try {
      final response = await ApiService.get(
        ApiConstants.getSavedReport(reportId),
      );

      return {
        'success': true,
        'report': response['report'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Update saved report
  static Future<Map<String, dynamic>> updateSavedReport(
    String reportId, {
    String? reportName,
    Map<String, dynamic>? filters,
    String? notes,
    List<String>? tags,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (reportName != null) body['reportName'] = reportName;
      if (filters != null) body['filters'] = filters;
      if (notes != null) body['notes'] = notes;
      if (tags != null) body['tags'] = tags;

      final response = await ApiService.put(
        ApiConstants.updateSavedReport(reportId),
        body,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Report updated successfully',
        'report': response['report'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Delete saved report
  static Future<Map<String, dynamic>> deleteSavedReport(String reportId) async {
    try {
      final response = await ApiService.delete(
        ApiConstants.deleteSavedReport(reportId),
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Report deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Duplicate saved report
  static Future<Map<String, dynamic>> duplicateSavedReport(String reportId) async {
    try {
      final response = await ApiService.post(
        ApiConstants.duplicateSavedReport(reportId),
        {},
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Report duplicated successfully',
        'report': response['report'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Get report templates
  static Future<Map<String, dynamic>> getReportTemplates() async {
    try {
      final response = await ApiService.get(
        ApiConstants.getReportTemplates,
      );

      return {
        'success': true,
        'templates': response['templates'] ?? [],
        'count': response['count'] ?? 0,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'templates': [],
        'count': 0,
      };
    }
  }
}

