import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'role_service.dart';
import 'api_service.dart';
import '../utils/api_constants.dart';

class PermissionService {
  static const String _cachePrefix = 'permissions_cache_';
  static const String _cacheTimestampPrefix = 'permissions_cache_timestamp_';
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Load and cache permissions for a role from API
  static Future<List<String>> loadRolePermissions(String roleName) async {
    try {
      // Check cache first
      final cached = await getCachedPermissions(roleName);
      if (cached != null) {
        // Refresh in background
        _refreshPermissionsInBackground(roleName);
        return cached;
      }

      // Load from API
      final result = await RoleService.getRolePermissions(roleName);
      if (result['success'] == true) {
        final permissions = List<String>.from(result['permissions'] ?? []);
        await cachePermissions(roleName, permissions);
        return permissions;
      }

      return [];
    } catch (e) {
      // Try to return cached permissions on error
      final cached = await getCachedPermissions(roleName);
      return cached ?? [];
    }
  }

  /// Check if user has a specific permission
  static Future<bool> hasPermission(String permissionId) async {
    final role = await _getCurrentUserRole();
    if (role == null) return false;

    final permissions = await loadRolePermissions(role);
    return permissions.contains(permissionId);
  }

  /// Check if user has any permission in a group (e.g., 'wallet.self')
  static Future<bool> hasAnyPermissionInGroup(String groupPrefix) async {
    final role = await _getCurrentUserRole();
    if (role == null) return false;

    final permissions = await loadRolePermissions(role);
    return permissions.any((p) => p.startsWith(groupPrefix));
  }

  /// Get all permissions for current user's role
  static Future<List<String>> getCurrentUserPermissions() async {
    final role = await _getCurrentUserRole();
    if (role == null) return [];
    return await loadRolePermissions(role);
  }

  /// Cache permissions in SharedPreferences
  static Future<void> cachePermissions(String roleName, List<String> permissions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$roleName';
      final timestampKey = '$_cacheTimestampPrefix$roleName';

      await prefs.setStringList(cacheKey, permissions);
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Silently fail caching
    }
  }

  /// Get cached permissions
  static Future<List<String>?> getCachedPermissions(String roleName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$roleName';
      final timestampKey = '$_cacheTimestampPrefix$roleName';

      final cachedPermissions = prefs.getStringList(cacheKey);
      final timestamp = prefs.getInt(timestampKey);

      if (cachedPermissions == null || timestamp == null) {
        return null;
      }

      // Check if cache is expired
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      if (now.difference(cacheTime) > _cacheExpiry) {
        return null; // Cache expired
      }

      return cachedPermissions;
    } catch (e) {
      return null;
    }
  }

  /// Clear cache for a specific role
  static Future<void> clearCacheForRole(String roleName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$roleName';
      final timestampKey = '$_cacheTimestampPrefix$roleName';

      await prefs.remove(cacheKey);
      await prefs.remove(timestampKey);
    } catch (e) {
      // Silently fail
    }
  }

  /// Clear all permission caches
  static Future<void> clearAllCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cachePrefix) || key.startsWith(_cacheTimestampPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Refresh permissions in background
  static void _refreshPermissionsInBackground(String roleName) async {
    try {
      final result = await RoleService.getRolePermissions(roleName);
      if (result['success'] == true) {
        final permissions = List<String>.from(result['permissions'] ?? []);
        await cachePermissions(roleName, permissions);
      }
    } catch (e) {
      // Silently fail background refresh
    }
  }

  /// Get current user role from SharedPreferences
  static Future<String?> _getCurrentUserRole() async {
    try {
      return await AuthService.getUserRole();
    } catch (e) {
      return null;
    }
  }

  // ========== User Permission Management ==========

  /// Get user permissions (role + user-specific)
  static Future<Map<String, dynamic>> getUserPermissions(String userId) async {
    try {
      final response = await ApiService.get(ApiConstants.getUserPermissions(userId));
      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get user permissions: $e'
      };
    }
  }

  /// Update user-specific permissions
  static Future<Map<String, dynamic>> updateUserPermissions(
    String userId,
    List<String> permissions,
  ) async {
    try {
      final response = await ApiService.put(
        ApiConstants.updateUserPermissions(userId),
        {'userSpecificPermissions': permissions},
      );
      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update user permissions: $e'
      };
    }
  }

  // ========== Permission CRUD Operations ==========

  /// Get all available permissions
  static Future<Map<String, dynamic>> getAllPermissions() async {
    try {
      final response = await ApiService.get(ApiConstants.getAllPermissions);
      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get permissions: $e'
      };
    }
  }

  /// Create a new permission
  static Future<Map<String, dynamic>> createPermission({
    required String permissionId,
    required String label,
    String? description,
    required String category,
  }) async {
    try {
      final response = await ApiService.post(
        ApiConstants.createPermission,
        {
          'permissionId': permissionId,
          'label': label,
          'description': description,
          'category': category,
        },
      );
      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create permission: $e'
      };
    }
  }

  /// Update a permission
  static Future<Map<String, dynamic>> updatePermission(
    String permissionId, {
    String? label,
    String? description,
    String? category,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (label != null) body['label'] = label;
      if (description != null) body['description'] = description;
      if (category != null) body['category'] = category;

      final response = await ApiService.put(
        ApiConstants.updatePermission(permissionId),
        body,
      );
      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update permission: $e'
      };
    }
  }

  /// Delete a permission
  static Future<Map<String, dynamic>> deletePermission(String permissionId) async {
    try {
      final response = await ApiService.delete(ApiConstants.deletePermission(permissionId));
      return response;
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete permission: $e'
      };
    }
  }

  /// Check if user has permission (checks both role and user-specific)
  static Future<bool> hasPermissionForUser(String userId, String permissionId) async {
    try {
      final result = await getUserPermissions(userId);
      if (result['success'] == true) {
        final rolePermissions = List<String>.from(result['rolePermissions'] ?? []);
        final userPermissions = List<String>.from(result['userSpecificPermissions'] ?? []);
        return rolePermissions.contains(permissionId) || userPermissions.contains(permissionId);
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

