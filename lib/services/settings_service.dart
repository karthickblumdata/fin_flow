import '../models/action_button_setting.dart';
import '../utils/api_constants.dart';
import 'api_service.dart';

class SettingsService {
  static Future<List<ActionButtonSetting>> fetchActionButtonSettings() async {
    try {
      final response = await ApiService.get(ApiConstants.getActionButtonSettings);

      if (response['success'] == true && response['settings'] is List) {
        final List<dynamic> rawSettings = response['settings'] as List<dynamic>;
        return rawSettings
            .whereType<Map<String, dynamic>>()
            .map(ActionButtonSetting.fromJson)
            .toList();
      }

      // Check if it's an authorization error
      final errorMessage = response['message'] ?? '';
      if (errorMessage.contains('not authorized') || 
          errorMessage.contains('authorized to access')) {
        // Return empty list for authorization errors - caller should use defaults
        return [];
      }

      throw Exception(errorMessage.isNotEmpty 
          ? errorMessage 
          : 'Failed to load action button settings');
    } catch (e) {
      final errorString = e.toString();
      // If it's an authorization error, return empty list instead of throwing
      if (errorString.contains('not authorized') || 
          errorString.contains('authorized to access')) {
        return [];
      }
      // Re-throw other errors
      throw e;
    }
  }

  static Future<List<ActionButtonSetting>> updateActionButtonSettings(
    List<ActionButtonSetting> settings,
  ) async {
    final response = await ApiService.put(ApiConstants.updateActionButtonSettings, {
      'settings': settings.map((setting) => setting.toJson()).toList(),
    });

    if (response['success'] == true && response['settings'] is List) {
      final List<dynamic> rawSettings = response['settings'] as List<dynamic>;
      return rawSettings
          .whereType<Map<String, dynamic>>()
          .map(ActionButtonSetting.fromJson)
          .toList();
    }

    throw Exception(response['message'] ?? 'Failed to update action button settings');
  }

  static Future<List<ActionButtonSetting>> resetActionButtonSettings() async {
    final response = await ApiService.post(
      ApiConstants.resetActionButtonSettings,
      const <String, dynamic>{},
    );

    if (response['success'] == true && response['settings'] is List) {
      final List<dynamic> rawSettings = response['settings'] as List<dynamic>;
      return rawSettings
          .whereType<Map<String, dynamic>>()
          .map(ActionButtonSetting.fromJson)
          .toList();
    }

    throw Exception(response['message'] ?? 'Failed to reset action button settings');
  }
}


