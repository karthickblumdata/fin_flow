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

  /// Update user permissions (SuperAdmin or user with assign permission)
  /// [permissions] - List of permission IDs to assign to the user
  static Future<Map<String, dynamic>> updateUserPermissions({
    required String userId,
    required List<String> permissions,
  }) async {
    try {
      final response = await ApiService.put(
        ApiConstants.updateUserPermissions(userId),
        {
          'userSpecificPermissions': permissions,
        },
      );

      if (response['success'] == true) {
        return {
          'success': true,
          'message': response['message'] ?? 'User permissions updated successfully',
          'user': response['user'],
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Failed to update user permissions',
          'missingPermissions': response['missingPermissions'] ?? [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Update user assignments (assigned users)
  static Future<Map<String, dynamic>> updateUserAssignments({
    required String userId,
    required List<String> assignedUserIds,
  }) async {
    try {
      // Log what we're sending
      print('\n📤 [API REQUEST] Sending User Assignments Update:');
      print('   Endpoint: ${ApiConstants.updateUserAssignments(userId)}');
      print('   Target User ID: $userId');
      print('   Assigned User IDs Count: ${assignedUserIds.length}');
      print('   Assigned User IDs: $assignedUserIds');
      print('   Request Body: { "assignedUserIds": $assignedUserIds }');
      
      final requestBody = {
        'assignedUserIds': assignedUserIds,
      };
      
      print('   ✅ Request prepared, sending to backend...');
      
      final response = await ApiService.put(
        ApiConstants.updateUserAssignments(userId),
        requestBody,
      );
      
      print('   📥 [API RESPONSE] Received response:');
      print('   Success: ${response['success']}');
      print('   Message: ${response['message']}');
      
      if (response['user'] != null) {
        final user = response['user'] as Map<String, dynamic>?;
        print('   User assignedUsers count: ${(user?['assignedUsers'] as List?)?.length ?? 0}');
      }

      if (response['success'] == true) {
        return {
          'success': true,
          'message': response['message'] ?? 'User assignments updated successfully',
          'user': response['user'],
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Failed to update user assignments',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }
}
