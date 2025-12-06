import 'api_service.dart';
import '../utils/api_constants.dart';

class CustomFieldService {
  /// Get all custom fields
  static Future<Map<String, dynamic>> getCustomFields() async {
    try {
      final response = await ApiService.get(
        ApiConstants.getCustomFields,
      );

      return {
        'success': true,
        'customFields': response['customFields'] ?? [],
        'count': response['count'] ?? 0,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'customFields': [],
        'count': 0,
      };
    }
  }

  /// Create new custom field
  static Future<Map<String, dynamic>> createCustomField({
    required String name,
    bool isActive = true,
  }) async {
    try {
      final requestData = <String, dynamic>{
        'name': name.trim(),
        'isActive': isActive,
      };

      final response = await ApiService.post(
        ApiConstants.createCustomField,
        requestData,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Custom field created successfully',
        'customField': response['customField'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Update custom field
  static Future<Map<String, dynamic>> updateCustomField(
    String customFieldId, {
    String? name,
    bool? isActive,
    bool? useInCollections,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null && name.trim().isNotEmpty) body['name'] = name.trim();
      if (isActive != null) body['isActive'] = isActive;
      if (useInCollections != null) body['useInCollections'] = useInCollections;

      final response = await ApiService.put(
        ApiConstants.updateCustomField(customFieldId),
        body,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Custom field updated successfully',
        'customField': response['customField'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Delete custom field
  static Future<Map<String, dynamic>> deleteCustomField(String customFieldId) async {
    try {
      final response = await ApiService.delete(
        ApiConstants.deleteCustomField(customFieldId),
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Custom field deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }
}

