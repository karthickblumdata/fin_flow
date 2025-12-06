import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../utils/api_constants.dart';
import 'socket_service.dart';

class AuthService {
  static const String _userRoleKey = 'user_role';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _userPermissionsKey = 'user_permissions';
  static const String _isNonWalletUserKey = 'is_non_wallet_user';

  /// Authenticate user with email and password
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await ApiService.post(
        ApiConstants.login,
        {
          'email': email,
          'password': password,
        },
        includeAuth: false, // Login doesn't require auth token
      );

      if (response['token'] != null && response['user'] != null) {
        // Store token and user info
        await ApiService.setToken(response['token']);
        
        final prefs = await SharedPreferences.getInstance();
        final user = response['user'];
        
        // Log raw response for debugging
        print('\n📥 ===== LOGIN RESPONSE RECEIVED =====');
        print('   Response Keys: ${response.keys.toList()}');
        print('   User Keys: ${user.keys.toList()}');
        print('   User Object: $user');
        print('   Has Permissions Key: ${user.containsKey('permissions')}');
        if (user.containsKey('permissions')) {
          print('   Permissions Type: ${user['permissions'].runtimeType}');
          print('   Permissions Value: ${user['permissions']}');
        }
        print('=====================================\n');
        
        // Map backend roles to frontend roles
        String backendRole = user['role'] ?? '';
        String frontendRole = backendRole;
        if (backendRole == 'SuperAdmin') frontendRole = 'Super Admin';
        // All other roles remain as-is (dynamic roles)
        
        await prefs.setString(_userRoleKey, backendRole); // Store backend role
        await prefs.setString(_userIdKey, user['_id'] ?? user['id'] ?? '');
        await prefs.setString(_userNameKey, user['name'] ?? '');
        await prefs.setString(_userEmailKey, user['email'] ?? email);
        
        // Store isNonWalletUser flag
        final isNonWalletUser = user['isNonWalletUser'] ?? false;
        await prefs.setBool(_isNonWalletUserKey, isNonWalletUser == true);
        
        // Store user permissions
        final permissions = user['permissions'] as List<dynamic>? ?? [];
        // Filter out invalid permissions (empty strings, 'root', etc.)
        final permissionsList = permissions
            .map((p) => p.toString())
            .where((p) => p.isNotEmpty && p != 'root' && p.toLowerCase() != 'root')
            .toList();
        
        print('\n💾 ===== STORING PERMISSIONS ON LOGIN =====');
        print('   User Email: $email');
        print('   Raw Permissions from Response: $permissions');
        print('   Permissions Type: ${permissions.runtimeType}');
        print('   Raw Permissions Count: ${permissions.length}');
        print('   Filtered Permissions Count: ${permissionsList.length}');
        if (permissionsList.isNotEmpty) {
          print('   Permissions: $permissionsList');
        } else {
          print('   ⚠️  WARNING: User has NO permissions assigned!');
        }
        print('==========================================\n');
        
        await prefs.setStringList(_userPermissionsKey, permissionsList);
        
        // Verify storage
        final storedPermissions = prefs.getStringList(_userPermissionsKey) ?? [];
        
        // Log permissions for debugging
        print('✅ ===== PERMISSIONS LOADED DURING LOGIN =====');
        print('   User Email: $email');
        print('   User Role: ${user['role']} (Backend: $backendRole, Frontend: $frontendRole)');
        print('   Permissions Received Count: ${permissions.length}');
        print('   Permissions Converted Count: ${permissionsList.length}');
        print('   Permissions Stored Count: ${storedPermissions.length}');
        if (permissionsList.isNotEmpty) {
          print('   Permissions List: $permissionsList');
        } else {
          print('   ⚠️  WARNING: User has NO permissions assigned!');
        }
        print('   Storage Verification: ${storedPermissions.length == permissionsList.length ? "✅ MATCH" : "❌ MISMATCH"}');
        print('==========================================\n');

        return {
          'success': true,
          'user': {
            'email': user['email'],
            'name': user['name'],
            'role': frontendRole, // Return frontend role format
            'id': user['_id'] ?? user['id'],
          },
          'token': response['token'],
        };
      }

      return {
        'success': false,
        'message': response['message'] ?? 'Login failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Logout user
  static Future<Map<String, dynamic>> logout() async {
    try {
      // Call logout API
      final response = await ApiService.post(
        ApiConstants.logout,
        {},
        includeAuth: true,
      );

      // Clear local storage regardless of API response
      await ApiService.clearToken();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userRoleKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userNameKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userPermissionsKey);
      await prefs.remove(_isNonWalletUserKey);

      // Disconnect Socket.IO if connected
      try {
        SocketService.disconnect();
      } catch (e) {
        // Ignore socket disconnection errors
      }

      return {
        'success': true,
        'message': response['message'] ?? 'Logout successful',
      };
    } catch (e) {
      // Even if API call fails, clear local storage
      await ApiService.clearToken();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userRoleKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userNameKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userPermissionsKey);
      await prefs.remove(_isNonWalletUserKey);

      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Get stored user role
  static Future<String?> getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(_userRoleKey);
      
      // Map backend roles to frontend roles
      if (role == 'SuperAdmin') return 'Super Admin';
      if (role == 'Admin') return 'Admin';
      if (role == 'Staff') return 'Staff';
      
      return role;
    } catch (e) {
      return null;
    }
  }

  /// Get stored user ID
  static Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userIdKey);
    } catch (e) {
      return null;
    }
  }

  /// Get stored user permissions
  static Future<List<String>> getUserPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final permissions = prefs.getStringList(_userPermissionsKey);
      return permissions ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Refresh current user permissions from server
  /// This should be called when role permissions are updated
  static Future<Map<String, dynamic>> refreshPermissions() async {
    try {
      final response = await ApiService.get(
        ApiConstants.refreshCurrentUserPermissions,
      );

      if (response['success'] == true && response['permissions'] != null) {
        final permissions = response['permissions'] as List<dynamic>? ?? [];
        final permissionsList = permissions.map((p) => p.toString()).toList();
        
        // Update stored permissions
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_userPermissionsKey, permissionsList);
        
        print('\n🔄 ===== PERMISSIONS REFRESHED =====');
        print('   Permissions Count: ${permissionsList.length}');
        if (permissionsList.isNotEmpty) {
          print('   Permissions Sample: ${permissionsList.take(5).join(', ')}');
        }
        print('==================================\n');

        return {
          'success': true,
          'permissions': permissionsList,
          'message': 'Permissions refreshed successfully'
        };
      }

      return {
        'success': false,
        'message': response['message'] ?? 'Failed to refresh permissions'
      };
    } catch (e) {
      print('❌ Error refreshing permissions: $e');
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', '')
      };
    }
  }

  /// Get stored user name
  static Future<String?> getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userNameKey);
    } catch (e) {
      return null;
    }
  }

  /// Get stored user email
  static Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userEmailKey);
    } catch (e) {
      return null;
    }
  }

  /// Get isNonWalletUser flag
  static Future<bool> isNonWalletUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isNonWalletUserKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await ApiService.getToken();
    return token != null && token.isNotEmpty;
  }

  /// Forgot password - send reset link
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await ApiService.post(
        ApiConstants.forgotPassword,
        {'email': email},
        includeAuth: false,
      );

      // Check if response indicates success
      if (response['success'] == true) {
        return {
          'success': true,
          'message': response['message'] ?? 'Password has been reset and sent to your email',
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Failed to reset password',
        };
      }
    } catch (e) {
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      
      // Provide user-friendly error messages
      if (errorMessage.contains('User not found') || errorMessage.contains('404')) {
        errorMessage = 'No account found with this email address. Please check and try again.';
      } else if (errorMessage.contains('Failed to connect')) {
        errorMessage = 'Unable to connect to server. Please check your internet connection.';
      } else if (errorMessage.contains('500') || errorMessage.contains('Internal Server Error')) {
        errorMessage = 'Server error occurred. Please try again later or contact support.';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  /// Reset password with token
  static Future<Map<String, dynamic>> resetPassword(
      String email, String token, String newPassword) async {
    try {
      final response = await ApiService.post(
        ApiConstants.resetPassword,
        {
          'email': email,
          'token': token,
          'newPassword': newPassword,
        },
        includeAuth: false,
      );

      // Check if response indicates success
      if (response['success'] == true) {
        return {
          'success': true,
          'message': response['message'] ?? 'Password reset successfully',
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Failed to reset password',
        };
      }
    } catch (e) {
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      
      // Provide user-friendly error messages
      if (errorMessage.contains('Invalid OTP') || errorMessage.contains('invalid')) {
        errorMessage = 'Invalid OTP. Please check and try again.';
      } else if (errorMessage.contains('expired') || errorMessage.contains('OTP has expired')) {
        errorMessage = 'OTP has expired. Please request a new OTP.';
      } else if (errorMessage.contains('User not found') || errorMessage.contains('404')) {
        errorMessage = 'User not found. Please check your email address.';
      } else if (errorMessage.contains('Failed to connect')) {
        errorMessage = 'Unable to connect to server. Please check your internet connection.';
      } else if (errorMessage.contains('500') || errorMessage.contains('Internal Server Error')) {
        errorMessage = 'Server error occurred. Please try again later or contact support.';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  /// Verify OTP for new user
  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final response = await ApiService.post(
        ApiConstants.verifyOtp,
        {
          'email': email,
          'otp': otp,
        },
        includeAuth: false,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'OTP verified successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Set password after OTP verification
  static Future<Map<String, dynamic>> setPassword(
      String email, String otp, String password) async {
    try {
      final response = await ApiService.post(
        ApiConstants.setPassword,
        {
          'email': email,
          'otp': otp,
          'password': password,
        },
        includeAuth: false,
      );

      // Check if response indicates success
      if (response['success'] == true) {
        return {
          'success': true,
          'message': response['message'] ?? 'Password set successfully',
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Failed to set password',
        };
      }
    } catch (e) {
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      
      // Provide user-friendly error messages
      if (errorMessage.contains('Invalid OTP') || errorMessage.contains('invalid')) {
        errorMessage = 'Invalid OTP. Please check and try again.';
      } else if (errorMessage.contains('expired') || errorMessage.contains('OTP has expired')) {
        errorMessage = 'OTP has expired. Please request a new OTP.';
      } else if (errorMessage.contains('User not found') || errorMessage.contains('404')) {
        errorMessage = 'User not found. Please check your email address.';
      } else if (errorMessage.contains('Failed to connect')) {
        errorMessage = 'Unable to connect to server. Please check your internet connection.';
      } else if (errorMessage.contains('500') || errorMessage.contains('Internal Server Error')) {
        errorMessage = 'Server error occurred. Please try again later or contact support.';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  /// Resend OTP
  static Future<Map<String, dynamic>> resendOtp(String email,
      {String? purpose}) async {
    try {
      final response = await ApiService.post(
        ApiConstants.sendOtp,
        {
          'email': email,
          'purpose': purpose ?? 'verification',
        },
        includeAuth: false,
      );

      return {
        'success': true,
        'message': response['message'] ?? 'OTP sent successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Create new user (Admin/SuperAdmin only)
  /// [userSpecificPermissions] is optional - can be provided during creation or assigned later
  /// [skipWallet] if true, user will be created without a wallet
  static Future<Map<String, dynamic>> createUser(
    String name,
    String email,
    String role, {
    List<String>? userSpecificPermissions,
    String? phoneNumber,
    String? countryCode,
    String? dateOfBirth,
    String? profileImage,
    String? address,
    String? state,
    String? pinCode,
    bool skipWallet = false,
  }) async {
    try {
      // Map frontend roles to backend roles
      String backendRole = role;
      if (role == 'Super Admin') backendRole = 'SuperAdmin';
      // All other roles remain as-is (dynamic roles come from Role model)

      final requestBody = <String, dynamic>{
        'name': name,
        'email': email,
        'role': backendRole,
      };

      // Include phone number if provided
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        requestBody['phoneNumber'] = phoneNumber.trim();
      }

      // Include country code if provided
      if (countryCode != null && countryCode.trim().isNotEmpty) {
        requestBody['countryCode'] = countryCode.trim();
      }

      // Include date of birth if provided (required for new users)
      if (dateOfBirth != null && dateOfBirth.trim().isNotEmpty) {
        requestBody['dateOfBirth'] = dateOfBirth.trim();
      }

      // Include profile image URL if provided
      if (profileImage != null && profileImage.trim().isNotEmpty) {
        requestBody['profileImage'] = profileImage.trim();
      }

      // Include address if provided
      if (address != null && address.trim().isNotEmpty) {
        requestBody['address'] = address.trim();
      }

      // Include state if provided
      if (state != null && state.trim().isNotEmpty) {
        requestBody['state'] = state.trim();
      }

      // Include pin code if provided
      if (pinCode != null && pinCode.trim().isNotEmpty) {
        requestBody['pinCode'] = pinCode.trim();
      }

      // Include permissions if provided
      if (userSpecificPermissions != null && userSpecificPermissions.isNotEmpty) {
        requestBody['userSpecificPermissions'] = userSpecificPermissions;
      }

      // Include skipWallet flag if true
      if (skipWallet) {
        requestBody['skipWallet'] = true;
      }

      final response = await ApiService.post(
        ApiConstants.createUser,
        requestBody,
        includeAuth: true, // Requires authentication
      );

      return {
        'success': true,
        'message': response['message'] ?? 'User created successfully',
        'user': response['user'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  /// Send invite email with username and password (Admin/SuperAdmin only)
  static Future<Map<String, dynamic>> sendInvite({
    String? userId,
    String? email,
  }) async {
    try {
      if (userId == null && email == null) {
        return {
          'success': false,
          'message': 'Please provide userId or email',
        };
      }

      final response = await ApiService.post(
        ApiConstants.sendInvite,
        {
          if (userId != null) 'userId': userId,
          if (email != null) 'email': email,
        },
        includeAuth: true, // Requires authentication
      );

      // Check if response indicates success or failure
      if (response['success'] == true) {
        return {
          'success': true,
          'message': response['message'] ?? 'Invite email sent successfully',
          'user': response['user'],
        };
      } else {
        // API returned success: false (e.g., email sending failed)
        return {
          'success': false,
          'message': response['message'] ?? 'Failed to send invite email',
          'user': response['user'],
        };
      }
    } catch (e) {
      // Network error or HTTP error (400, 500, etc.)
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      
      // Provide user-friendly error messages
      if (errorMessage.contains('Gmail authentication') || 
          errorMessage.contains('App Password') ||
          errorMessage.contains('Invalid login')) {
        errorMessage = 'Gmail authentication failed. Please configure Gmail App Password in backend .env file.';
      } else if (errorMessage.contains('email service') || 
                 errorMessage.contains('Email credentials')) {
        errorMessage = 'Email service not configured. Please check backend email settings.';
      } else if (errorMessage.contains('User not found') || 
                 errorMessage.contains('404')) {
        errorMessage = 'User not found. Please check the user email or ID.';
      } else if (errorMessage.contains('Failed to connect') || 
                 errorMessage.contains('network')) {
        errorMessage = 'Unable to connect to server. Please check your internet connection.';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }
}

