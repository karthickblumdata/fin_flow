import 'api_service.dart';
import '../utils/api_constants.dart';

class RoleService {
  /// Create a new role with permissions
  static Future<Map<String, dynamic>> createRole({
    required String roleName,
    required List<String> permissionIds,
    String? name,
  }) async {
    try {
      if (roleName.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Role name is required',
        };
      }

      final response = await ApiService.post(
        ApiConstants.createRole,
        {
          'roleName': roleName.trim(),
          'permissionIds': permissionIds,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        },
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Role created successfully',
        'role': response['role'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Get role permissions
  static Future<Map<String, dynamic>> getRolePermissions(String roleName) async {
    try {
      final response = await ApiService.get(
        ApiConstants.getRolePermissions(roleName),
      );

      return {
        'success': true,
        'permissions': response['permissions'] ?? [],
        'role': response['role'] ?? roleName,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'permissions': [],
      };
    }
  }

  /// Update role permissions
  static Future<Map<String, dynamic>> updateRolePermissions({
    required String roleName,
    required List<String> permissionIds,
    String? newName,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'permissionIds': permissionIds,
      };
      
      // Include new name if provided and different from current name
      if (newName != null && newName.trim().isNotEmpty && newName.trim() != roleName) {
        body['name'] = newName.trim();
      }
      
      final response = await ApiService.put(
        ApiConstants.updateRolePermissions(roleName),
        body,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Role permissions updated successfully',
        'role': response['role'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Get all roles
  static Future<Map<String, dynamic>> getAllRoles() async {
    try {
      final response = await ApiService.get(ApiConstants.getAllRoles);

      return {
        'success': true,
        'roles': response['roles'] ?? [],
        'count': response['count'] ?? 0,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'roles': [],
        'count': 0,
      };
    }
  }

  /// Check if a role exists
  static Future<bool> roleExists(String roleName) async {
    try {
      final result = await getAllRoles();
      if (result['success'] == true) {
        final roles = result['roles'] as List<dynamic>? ?? [];
        return roles.any((role) {
          final rn = role['roleName']?.toString().trim() ?? '';
          return rn.toLowerCase() == roleName.trim().toLowerCase();
        });
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

