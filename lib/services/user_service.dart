import 'api_service.dart';
import '../utils/api_constants.dart';

class UserService {
  /// Get all users (Admin/SuperAdmin only)
  static Future<Map<String, dynamic>> getUsers() async {
    try {
      final response = await ApiService.get(ApiConstants.getUsers);

      return {
        'success': true,
        'users': response['users'] ?? [],
        'count': response['count'] ?? 0,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'users': [],
        'count': 0,
      };
    }
  }

  /// Delete a user (SuperAdmin only)
  static Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      final response = await ApiService.delete(
        ApiConstants.deleteUser(userId),
      );

      // Check if response has success field (from backend)
      if (response['success'] == true) {
        return {
          'success': true,
          'message': response['message'] ?? 'User deleted successfully',
        };
      } else {
        // Backend returned success: false
        return {
          'success': false,
          'message': response['message'] ?? 'Failed to delete user',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Update user (SuperAdmin only)
  static Future<Map<String, dynamic>> updateUser({
    required String userId,
    String? name,
    String? email,
    String? role,
    String? profileImage,
    String? dateOfBirth,
    String? address,
    String? state,
    String? pinCode,
    bool? isVerified,
    bool? isNonWalletUser,
  }) async {
    try {
      // Map frontend role to backend role
      String? backendRole = role;
      if (role != null && role == 'Super Admin') {
        backendRole = 'SuperAdmin';
      }
      // All other roles remain as-is (dynamic roles)

      final body = <String, dynamic>{};
      if (name != null && name.trim().isNotEmpty) {
        body['name'] = name.trim();
      }
      if (email != null && email.trim().isNotEmpty) {
        body['email'] = email.trim();
      }
      if (backendRole != null) {
        body['role'] = backendRole;
      }
      if (profileImage != null && profileImage.trim().isNotEmpty) {
        body['profileImage'] = profileImage.trim();
      }
      if (dateOfBirth != null && dateOfBirth.trim().isNotEmpty) {
        body['dateOfBirth'] = dateOfBirth.trim();
      }
      if (address != null && address.trim().isNotEmpty) {
        body['address'] = address.trim();
      }
      if (state != null && state.trim().isNotEmpty) {
        body['state'] = state.trim();
      }
      if (pinCode != null && pinCode.trim().isNotEmpty) {
        body['pinCode'] = pinCode.trim();
      }
      if (isVerified != null) {
        body['isVerified'] = isVerified;
      }
      if (isNonWalletUser != null) {
        body['isNonWalletUser'] = isNonWalletUser;
      }

      // Don't send empty body
      if (body.isEmpty) {
        return {
          'success': false,
          'message': 'No fields to update',
        };
      }

      final response = await ApiService.put(
        ApiConstants.updateUser(userId),
        body,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'User updated successfully',
        'user': response['user'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }
}
